abstract class ConnectivityService {
  bool get isOnline;

  Stream<bool> get changes;
}
