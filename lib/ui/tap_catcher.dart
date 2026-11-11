import 'package:flutter/widgets.dart';

/// Zuverlässiges Antippen am Handy: liest die Finger direkt statt über die Gestenerkennung.
/// So geht kein Tippen verloren, wenn sich der Finger etwas bewegt oder ein Zoom-Bereich
/// (InteractiveViewer) die Geste für sich beansprucht. Gezählt wird beim Loslassen, wenn
/// der Finger nicht weiter als [slop] gewandert ist und kein zweiter Finger dazukam.
class TapCatcher extends StatefulWidget {
  const TapCatcher({super.key, required this.onTap, required this.child, this.slop = 24});

  final void Function(Offset localPosition)? onTap;
  final Widget child;
  final double slop;

  @override
  State<TapCatcher> createState() => _TapCatcherState();
}

class _TapCatcherState extends State<TapCatcher> {
  int? _pointer;
  Offset _down = Offset.zero;
  Offset _downGlobal = Offset.zero;
  bool _cancelled = false;
  int _active = 0;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) {
        _active++;
        if (_active > 1) {
          _cancelled = true;
          return;
        }
        _pointer = e.pointer;
        _down = e.localPosition;
        _downGlobal = e.position;
        _cancelled = false;
      },
      onPointerMove: (e) {
        if (e.pointer == _pointer && (e.position - _downGlobal).distance > widget.slop) _cancelled = true;
      },
      onPointerUp: (e) {
        _active = (_active - 1).clamp(0, 99);
        if (e.pointer != _pointer) return;
        _pointer = null;
        if (!_cancelled && (e.position - _downGlobal).distance <= widget.slop) widget.onTap?.call(_down);
      },
      onPointerCancel: (e) {
        _active = (_active - 1).clamp(0, 99);
        if (e.pointer == _pointer) _pointer = null;
      },
      child: widget.child,
    );
  }
}
