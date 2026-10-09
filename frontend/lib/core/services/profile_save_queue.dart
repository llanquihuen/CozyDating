/// Runs profile saves one after another, so the answer to an older save never lands after (and
/// overwrites) a newer one. Each save reports whether the server took it.
class ProfileSaveQueue {
  Future<void> _tail = Future.value();

  Future<bool> run(Future<bool> Function() save) {
    final result = _tail.then((_) => save()).catchError((Object _) => false);
    _tail = result.then((_) {});
    return result;
  }
}
