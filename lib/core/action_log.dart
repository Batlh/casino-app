/// Merkt sich alle Spielzüge, damit eine Partie später genau nachgespielt werden kann.
/// Verschachtelte Aufrufe (ein Zug ruft intern einen anderen auf) zählen nur einmal.
mixin ActionLog {
  final List<List<Object?>> actionLog = [];
  bool _inAction = false;

  void record(List<Object?> action, void Function() run) {
    if (_inAction) {
      run();
      return;
    }
    _inAction = true;
    try {
      run();
    } finally {
      _inAction = false;
    }
    actionLog.add(action);
  }
}
