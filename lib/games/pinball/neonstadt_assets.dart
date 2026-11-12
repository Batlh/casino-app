import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Gemeinsamer, offline geladener Bildsatz für Spiel und Tischauswahl.
/// Dekodierung findet nur einmal statt, niemals innerhalb von paint().
class NeonstadtAssets extends ChangeNotifier {
  NeonstadtAssets._();
  static final instance = NeonstadtAssets._();
  static const folder = 'assets/pinball/neonstadt/';
  static const files = <String, int>{
    'playfield': 1200,
    'bumper': 512,
    'flipper': 512,
    'sling': 512,
    'chrome': 512,
    'hologram': 512,
    'header': 1024,
    'ramp_bed': 1024,
    'ramp_wall': 1024,
    'support': 512,
    'target_panel': 1024,
    'target_panel_red': 1024,
  };

  final _images = <String, ui.Image>{};
  Map<String, dynamic> _metadata = {};

  /// Pixelregion bezogen auf die tatsächlich dekodierte Bildgröße.
  ui.Rect source(String name) {
    final info = _metadata[name] as Map<String, dynamic>;
    final size = (info['size'] as List).cast<num>();
    final crop = (info['crop'] as List).cast<num>();
    final image = _images[name]!;
    return ui.Rect.fromLTRB(
      crop[0] / size[0] * image.width,
      crop[1] / size[1] * image.height,
      crop[2] / size[0] * image.width,
      crop[3] / size[1] * image.height,
    );
  }

  ui.Offset anchor(String name, String anchorName) {
    final info = _metadata[name] as Map<String, dynamic>;
    final values = ((info['anchors'] as Map)[anchorName] as List).cast<num>();
    return ui.Offset(values[0].toDouble(), values[1].toDouble());
  }

  Future<void>? _loading;
  String? _error;
  bool get isReady => _images.length == files.length;
  bool get hasError => _error != null;
  ui.Image image(String name) => _images[name]!;

  Future<void> load() => _loading ??= _load();

  Future<void> retry() {
    if (!hasError) return load();
    _loading = null;
    _error = null;
    notifyListeners();
    return load();
  }

  Future<void> _load() async {
    final decoded = <String, ui.Image>{};
    try {
      final manifest = jsonDecode(
        await rootBundle.loadString('${folder}manifest.json'),
      ) as Map<String, dynamic>;
      final metadata = manifest['assets'] as Map<String, dynamic>;
      for (final entry in files.entries) {
        final info = metadata[entry.key] as Map<String, dynamic>;
        final data = await rootBundle.load('$folder${info['file']}');
        final codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          targetWidth: entry.value,
          allowUpscaling: false,
        );
        try {
          decoded[entry.key] = (await codec.getNextFrame()).image;
        } finally {
          codec.dispose();
        }
      }
      _metadata = metadata;
      _images.addAll(decoded);
      _error = null;
    } catch (error) {
      for (final image in decoded.values) {
        image.dispose();
      }
      _error = error.toString();
      debugPrint('Neonstadt: Bildsatz konnte nicht geladen werden: $error');
    }
    notifyListeners();
  }
}
