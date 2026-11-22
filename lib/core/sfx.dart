import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'debug_log.dart';

enum Sound { chip, card, tick, reelStop, coin, win, bigWin, lose, ball }

const _files = {
  Sound.chip: 'chip',
  Sound.card: 'card',
  Sound.tick: 'tick',
  Sound.reelStop: 'reel_stop',
  Sound.coin: 'coin',
  Sound.win: 'win',
  Sound.bigWin: 'big_win',
  Sound.lose: 'lose',
  Sound.ball: 'ball',
};

/// Spielt kurze Effekte. Fehlt ein Audiogerät, bleibt das Spiel einfach still.
class Sfx extends ChangeNotifier {
  Sfx(this._prefs, {this.silent = false})
      : _enabled = _prefs.getBool(_key) ?? true;

  static const _key = 'sfx.enabled';
  final SharedPreferences _prefs;
  final bool silent;
  bool _enabled;
  final List<AudioPlayer> _pool = [];
  int _next = 0;

  bool get enabled => _enabled;

  void toggle() {
    _enabled = !_enabled;
    _prefs.setBool(_key, _enabled);
    notifyListeners();
  }

  Future<void> play(Sound sound) async {
    debugLog.detail('ablauf', '${debugLog.screen}: ${sound.name}');
    if (!_enabled || silent) return;
    try {
      if (_pool.isEmpty) {
        for (var i = 0; i < 4; i++) {
          _pool.add(AudioPlayer());
        }
      }
      final player = _pool[_next];
      _next = (_next + 1) % _pool.length;
      await player.stop();
      await player.play(AssetSource('sfx/${_files[sound]}.wav'));
    } catch (e) {
      debugPrint('Sound nicht abspielbar: $e');
    }
  }

  @override
  void dispose() {
    for (final p in _pool) {
      p.dispose();
    }
    super.dispose();
  }
}
