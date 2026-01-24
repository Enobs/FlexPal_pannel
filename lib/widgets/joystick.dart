import 'package:flutter/material.dart';

/// A virtual joystick widget for touch and visual feedback
class Joystick extends StatefulWidget {
  final double size;
  final String label;
  final Color color;
  final void Function(double x, double y) onPositionChanged;
  final void Function() onReleased;

  const Joystick({
    Key? key,
    this.size = 150,
    required this.label,
    this.color = const Color(0xFF3498DB),
    required this.onPositionChanged,
    required this.onReleased,
  }) : super(key: key);

  @override
  State<Joystick> createState() => JoystickState();
}

class JoystickState extends State<Joystick> {
  double _thumbX = 0;
  double _thumbY = 0;
  bool _isDragging = false;

  /// Set joystick position programmatically (for keyboard control)
  void setPosition(double x, double y) {
    setState(() {
      _thumbX = x.clamp(-1.0, 1.0);
      _thumbY = y.clamp(-1.0, 1.0);
    });
  }

  /// Reset joystick to center
  void reset() {
    setState(() {
      _thumbX = 0;
      _thumbY = 0;
      _isDragging = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final baseRadius = widget.size / 2;
    final thumbRadius = widget.size / 6;
    final maxDistance = baseRadius - thumbRadius;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            color: widget.color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onPanStart: (details) {
            setState(() {
              _isDragging = true;
            });
            _updatePosition(details.localPosition, baseRadius, maxDistance);
          },
          onPanUpdate: (details) {
            _updatePosition(details.localPosition, baseRadius, maxDistance);
          },
          onPanEnd: (_) {
            setState(() {
              _thumbX = 0;
              _thumbY = 0;
              _isDragging = false;
            });
            widget.onReleased();
          },
          onPanCancel: () {
            setState(() {
              _thumbX = 0;
              _thumbY = 0;
              _isDragging = false;
            });
            widget.onReleased();
          },
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF2A2A2A),
              border: Border.all(
                color: _isDragging
                    ? widget.color
                    : widget.color.withValues(alpha: 0.5),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: _isDragging ? 0.3 : 0.1),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Stack(
              children: [
                // Direction indicators
                _buildDirectionIndicator(Alignment.topCenter, 'U'),
                _buildDirectionIndicator(Alignment.bottomCenter, 'D'),
                _buildDirectionIndicator(Alignment.centerLeft, 'L'),
                _buildDirectionIndicator(Alignment.centerRight, 'R'),
                // Crosshair lines
                Center(
                  child: Container(
                    width: widget.size * 0.6,
                    height: 1,
                    color: widget.color.withValues(alpha: 0.2),
                  ),
                ),
                Center(
                  child: Container(
                    width: 1,
                    height: widget.size * 0.6,
                    color: widget.color.withValues(alpha: 0.2),
                  ),
                ),
                // Thumb
                Center(
                  child: Transform.translate(
                    offset: Offset(
                      _thumbX * maxDistance,
                      _thumbY * maxDistance,
                    ),
                    child: Container(
                      width: thumbRadius * 2,
                      height: thumbRadius * 2,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isDragging
                            ? widget.color
                            : widget.color.withValues(alpha: 0.7),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.5),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'X: ${(_thumbX * 100).toStringAsFixed(0)}  Y: ${(-_thumbY * 100).toStringAsFixed(0)}',
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildDirectionIndicator(Alignment alignment, String label) {
    final isActive = _isDirectionActive(alignment);
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          label,
          style: TextStyle(
            color: isActive
                ? widget.color
                : widget.color.withValues(alpha: 0.3),
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  bool _isDirectionActive(Alignment alignment) {
    const threshold = 0.3;
    if (alignment == Alignment.topCenter) return _thumbY < -threshold;
    if (alignment == Alignment.bottomCenter) return _thumbY > threshold;
    if (alignment == Alignment.centerLeft) return _thumbX < -threshold;
    if (alignment == Alignment.centerRight) return _thumbX > threshold;
    return false;
  }

  void _updatePosition(Offset localPosition, double baseRadius, double maxDistance) {
    // Calculate offset from center
    final dx = localPosition.dx - baseRadius;
    final dy = localPosition.dy - baseRadius;

    // Calculate distance and angle
    final distance = (dx * dx + dy * dy).clamp(0, maxDistance * maxDistance);
    final actualDistance = distance <= maxDistance * maxDistance
        ? (dx * dx + dy * dy > 0 ? (dx * dx + dy * dy) : 0.0)
        : maxDistance * maxDistance;

    // Normalize to -1 to 1 range
    double normalizedX, normalizedY;
    if (actualDistance > 0) {
      final scale = actualDistance > maxDistance * maxDistance
          ? maxDistance / (dx * dx + dy * dy).clamp(0.001, double.infinity)
          : 1.0;
      normalizedX = (dx / maxDistance).clamp(-1.0, 1.0);
      normalizedY = (dy / maxDistance).clamp(-1.0, 1.0);
    } else {
      normalizedX = 0;
      normalizedY = 0;
    }

    setState(() {
      _thumbX = normalizedX;
      _thumbY = normalizedY;
    });

    widget.onPositionChanged(_thumbX, _thumbY);
  }
}
