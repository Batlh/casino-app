import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'painted_tables.dart';

/// Lädt die gemalten Spielfeldbilder bei Bedarf, ein Bild pro Tisch.
class PaintedAssets extends ChangeNotifier {
  PaintedAssets._();
  static final instance = PaintedAssets._();

  /// Physik-Linien über dem Bild einblenden (zum Abgleich mit dem Konzept).
  static bool showPhysics = false;

  final _images = <String, ui.Image>{};
  final _loading = <String, Future<void>>{};
  final _errors = <String>{};

  static String? idOf(String art) =>
      art.startsWith('painted:') ? art.substring(8) : null;

  bool isReady(String id) => _images.containsKey(id);
  bool hasError(String id) => _errors.contains(id);
  ui.Image? image(String id) => _images[id];

  Future<void> load(String id) => _loading[id] ??= _load(id);

  Future<void> _load(String id) async {
    final path = paintedBackgrounds[id];
    if (path == null) {
      _errors.add(id);
      notifyListeners();
      return;
    }
    try {
      final data = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      _images[id] = (await codec.getNextFrame()).image;
    } catch (_) {
      _errors.add(id);
      _loading.remove(id);
    }
    notifyListeners();
  }
}
