import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/data/datasources/connectivity_service.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/entities/branch.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/entities/monitoring_snapshot.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/entities/monitoring_update.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/repos/gold_price_repo.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/repos/monitoring_repo.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/usecases/monitoring_update_processor.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/presentation/manager/cubits/branch_monitoring_cubit/branch_monitoring_state.dart';

class BranchMonitoringCubit extends Cubit<BranchMonitoringState> {
  BranchMonitoringCubit({
    required this._monitoringRepository,
    required this._goldPriceRepository,
    required this._connectivity,
    required this._updateProcessor,
  }) : super(const BranchMonitoringInitial());

  final MonitoringRepository _monitoringRepository;
  final GoldPriceRepository _goldPriceRepository;
  final ConnectivityService _connectivity;
  final MonitoringUpdateProcessor _updateProcessor;

  StreamSubscription<MonitoringUpdate>? _updatesSubscription;
  StreamSubscription<dynamic>? _goldPriceSubscription;
  StreamSubscription<bool>? _connectivitySubscription;

  int _requestId = 0;
  String _selectedScopeId = 'all';

  final List<MonitoringUpdate> _pendingUpdates = [];

  MonitoringSnapshot? _currentSnapshot;
  bool _snapshotReady = false;
  bool _isResyncing = false;

  Future<void> load() async {
    emit(const BranchMonitoringLoading());

    try {
      final branches = await _monitoringRepository.getBranches();

      final requestId = ++_requestId;

      await _selectScope(
        scopeId: 'all',
        branches: branches,
        requestId: requestId,
      );

      _watchGoldPrice();
      _watchConnectivity();
    } catch (error) {
      emit(BranchMonitoringFailure(error.toString()));
    }
  }

  Future<void> selectScope(String scopeId) async {
    final currentState = state;

    if (currentState is! BranchMonitoringSuccess) return;

    if (scopeId == _selectedScopeId) return;

    final requestId = ++_requestId;

    await _selectScope(
      scopeId: scopeId,
      branches: currentState.branches,
      requestId: requestId,
    );
  }

  Future<void> _selectScope({
    required String scopeId,
    required List<Branch> branches,
    required int requestId,
  }) async {
    _selectedScopeId = scopeId;
    _snapshotReady = false;
    _isResyncing = false;
    _pendingUpdates.clear();

    await _updatesSubscription?.cancel();

    if (isClosed || requestId != _requestId) return;

    try {
      _updatesSubscription = _monitoringRepository
          .watchUpdates(scopeId)
          .listen(_handleUpdate);

      final snapshot = await _monitoringRepository.getSnapshot(scopeId);

      if (isClosed || requestId != _requestId) return;

      _currentSnapshot = snapshot;
      _snapshotReady = true;

      emit(
        BranchMonitoringSuccess(
          branches: branches,
          selectedScopeId: scopeId,
          snapshot: snapshot,
          goldPrice: state is BranchMonitoringSuccess
              ? (state as BranchMonitoringSuccess).goldPrice
              : null,
          isOnline: _connectivity.isOnline,
        ),
      );

      await _processPendingUpdates();
    } catch (error) {
      if (isClosed || requestId != _requestId) return;

      emit(BranchMonitoringFailure(error.toString()));
    }
  }

  void _handleUpdate(MonitoringUpdate update) {
    if (update.scopeId != _selectedScopeId) return;

    if (!_snapshotReady || _isResyncing) {
      _pendingUpdates.add(update);
      return;
    }

    _processUpdate(update);
  }

  void _processUpdate(MonitoringUpdate update) {
    final current = _currentSnapshot;
    if (current == null) return;

    final result = _updateProcessor.process(current: current, update: update);

    switch (result.status) {
      case UpdateProcessingStatus.applied:
        _currentSnapshot = result.snapshot;
        _emitUpdatedSnapshot();

        if (_pendingUpdates.isNotEmpty) {
          _processPendingUpdates(allowRecovery: false);
        }

      case UpdateProcessingStatus.duplicate:
        break;

      case UpdateProcessingStatus.gapDetected:
        _pendingUpdates.add(update);
        _recoverSnapshot();
    }
  }

  Future<void> _processPendingUpdates({bool allowRecovery = true}) async {
    if (_pendingUpdates.isEmpty) return;

    final updates = List<MonitoringUpdate>.from(_pendingUpdates);
    _pendingUpdates.clear();

    updates.sort((a, b) => a.sequence.compareTo(b.sequence));

    for (var i = 0; i < updates.length; i++) {
      final update = updates[i];
      if (update.scopeId != _selectedScopeId) continue;

      final current = _currentSnapshot;
      if (current == null) break;

      final result = _updateProcessor.process(current: current, update: update);

      if (result.status == UpdateProcessingStatus.gapDetected) {
        _pendingUpdates.addAll(updates.skip(i));

        if (allowRecovery) {
          await _recoverSnapshot();
        }

        return;
      }

      if (result.status == UpdateProcessingStatus.applied) {
        _currentSnapshot = result.snapshot;
        _emitUpdatedSnapshot();
      }
    }
  }

  Future<void> _recoverSnapshot() async {
    if (_isResyncing || isClosed) return;

    _isResyncing = true;

    final scopeId = _selectedScopeId;
    final requestId = _requestId;

    try {
      final snapshot = await _monitoringRepository.getSnapshot(scopeId);

      if (isClosed || requestId != _requestId || scopeId != _selectedScopeId) {
        return;
      }

      final current = _currentSnapshot;

      if (current == null || snapshot.sequence >= current.sequence) {
        _currentSnapshot = snapshot;
      }

      _snapshotReady = true;
    } catch (_) {
    } finally {
      if (requestId == _requestId) {
        _isResyncing = false;
      }
    }

    if (isClosed || requestId != _requestId || scopeId != _selectedScopeId) {
      return;
    }

    _emitUpdatedSnapshot();

    await _processPendingUpdates(allowRecovery: false);
  }

  void _emitUpdatedSnapshot() {
    final currentState = state;
    final snapshot = _currentSnapshot;

    if (currentState is! BranchMonitoringSuccess || snapshot == null) {
      return;
    }

    emit(currentState.copyWith(snapshot: snapshot));
  }

  void _watchGoldPrice() {
    _goldPriceSubscription?.cancel();

    _goldPriceSubscription = _goldPriceRepository.watchGoldPrice().listen((
      goldPrice,
    ) {
      final currentState = state;

      if (currentState is! BranchMonitoringSuccess) return;

      final currentGoldPrice = currentState.goldPrice;

      if (currentGoldPrice != null &&
          goldPrice.sequence <= currentGoldPrice.sequence) {
        return;
      }

      emit(currentState.copyWith(goldPrice: goldPrice));
    });
  }

  void _watchConnectivity() {
    _connectivitySubscription?.cancel();

    _connectivitySubscription = _connectivity.changes.listen((isOnline) {
      final currentState = state;

      if (currentState is BranchMonitoringSuccess) {
        emit(currentState.copyWith(isOnline: isOnline));
      }

      if (isOnline) {
        refresh();
      }
    });
  }

  Future<void> refresh() async {
    final currentState = state;
    if (currentState is! BranchMonitoringSuccess) return;

    emit(currentState.copyWith(isRefreshing: true));

    try {
      final snapshot = await _monitoringRepository.getSnapshot(
        _selectedScopeId,
      );

      if (isClosed || _selectedScopeId != currentState.selectedScopeId) {
        return;
      }

      if (_currentSnapshot == null ||
          snapshot.sequence >= _currentSnapshot!.sequence) {
        _currentSnapshot = snapshot;
      }

      await _processPendingUpdates(allowRecovery: false);

      _emitUpdatedSnapshot();
    } catch (_) {
    } finally {
      final latestState = state;
      if (!isClosed && latestState is BranchMonitoringSuccess) {
        emit(latestState.copyWith(isRefreshing: false));
      }
    }
  }

  @override
  Future<void> close() async {
    await _updatesSubscription?.cancel();
    await _goldPriceSubscription?.cancel();
    await _connectivitySubscription?.cancel();

    return super.close();
  }
}
