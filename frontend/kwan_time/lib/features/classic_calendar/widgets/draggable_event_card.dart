// ═══════════════════════════════════════════════════════════════════════════
// KWAN-TIME v2.0 — Draggable Event Card
// Agent 6: Classic Calendar View
//
// Event card with gooey blob morphing during drag-and-drop interactions.
// Uses Agent 8 (Physics Engine) for elastic feedback.
// ═══════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kwan_time/core/physics/physics.dart';
import 'package:kwan_time/core/theme/kwan_theme.dart';
import 'package:kwan_time/core/models/event.dart';
import '../providers/calendar_provider.dart';

/// Draggable event card with gooey morphing feedback
class DraggableEventCard extends ConsumerStatefulWidget {
  const DraggableEventCard({
    required this.event,
    super.key,
    this.onTap,
  });
  final Event event;
  final VoidCallback? onTap;

  @override
  ConsumerState<DraggableEventCard> createState() => _DraggableEventCardState();
}

class _DraggableEventCardState extends ConsumerState<DraggableEventCard> with SingleTickerProviderStateMixin {
  late final GooeyDragger _gooeyDragger;
  late final AnimationController _ticker;
  late Offset _dragStartPosition;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _gooeyDragger = GooeyDragger(
      initialPosition: Offset.zero,
      config: GooeyConfig.stretchy,
    );

    _ticker = AnimationController(
      duration: const Duration(seconds: 60),
      vsync: this,
    )..repeat();

    _ticker.addListener(() {
      _gooeyDragger.update(16.67); // ~60 FPS
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) => _isDragging ? _buildDraggedCard(context) : _buildRestCard(context);

  Widget _buildRestCard(BuildContext context) => GestureDetector(
        onTapDown: (_) {
          widget.onTap?.call();
        },
        onPanStart: (details) {
          _dragStartPosition = details.globalPosition;
          _gooeyDragger.startDrag(_dragStartPosition);
          setState(() => _isDragging = true);
        },
        child: Container(
          decoration: KwanTheme.glassCardDecoration(
            color: _getEventColor().withOpacity(0.1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.event.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: KwanTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatEventTime(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: KwanTheme.textSecondary,
                        fontSize: 10,
                      ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _buildDraggedCard(BuildContext context) => Stack(
        children: [
          // Original card position (ghost)
          Opacity(
            opacity: 0.3,
            child: _buildRestCard(context),
          ),

          // Dragging card
          Positioned(
            left: _gooeyDragger.position.dx - 24, // Offset to center (rough estimate)
            top: _gooeyDragger.position.dy - 24,
            width: 150,
            height: 60,
            child: GestureDetector(
              onPanUpdate: (details) {
                final newPosition = _gooeyDragger.dragPosition + details.delta;
                _gooeyDragger.updateDrag(newPosition);
              },
              onPanEnd: (details) {
                _gooeyDragger.releaseDrag(_gooeyDragger.dragPosition);
                _handleDragEnd();
              },
              child: Container(
                decoration: KwanTheme.glassCardDecoration(
                  color: _getEventColor().withOpacity(0.9),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.event.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatEventTime(),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.white70,
                              fontSize: 10,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Gooey blob connection during drag
          if (_gooeyDragger.isDragging && !_gooeyDragger.isSeparated)
            CustomPaint(
              painter: GooeyBlobPainter(_gooeyDragger),
              isComplex: true,
              willChange: true,
            ),
        ],
      );

  Future<void> _handleDragEnd() async {
    final notifier = ref.read(calendarProvider.notifier);

    // Calculate new time based on drag distance
    final dragDistance = _gooeyDragger.displacement.distance;
    final minutesOffset = (dragDistance / 60 * 15).toInt(); // ~1 min per px

    if (minutesOffset.abs() > 5) {
      // Only update if dragged > 5 minutes
      final newStartTime = widget.event.startTime.add(Duration(minutes: minutesOffset));
      final newEndTime = widget.event.endTime.add(Duration(minutes: minutesOffset));

      // Optimistic update
      final updated = widget.event.copyWith(
        startTime: newStartTime,
        endTime: newEndTime,
      );
      notifier.optimisticUpdateEvent(widget.event.id, updated);

      // API call (returns 202 Accepted, syncs via WebSocket)
      // TODO: Call Agent 2 API to update event
    }

    // Spring back animation
    setState(() => _isDragging = false);
  }

  Color _getEventColor() {
    switch (widget.event.type) {
      case 'online':
        return KwanTheme.colorOnline;
      case 'in_person':
        return KwanTheme.colorInPerson;
      case 'free':
        return KwanTheme.colorFree;
      case 'booked':
        return KwanTheme.colorBooked;
      default:
        return KwanTheme.colorOnline;
    }
  }

  String _formatEventTime() {
    final start = widget.event.startTime;
    final end = widget.event.endTime;
    return '${start.hour}:${start.minute.toString().padLeft(2, '0')} - '
        '${end.hour}:${end.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────
// CUSTOM PAINTER: Gooey Blob Connection
//
// Renders the elastic blob connection between original and dragged position.
// Uses bezier curves for smooth morphing.
// ─────────────────────────────────────────────────────────────────────────

class GooeyBlobPainter extends CustomPainter {
  GooeyBlobPainter(this.dragger);
  final GooeyDragger dragger;

  @override
  void paint(Canvas canvas, Size size) {
    if (dragger.isSeparated) return;

    final paint = Paint()
      ..color = dragger.position.toString().startsWith('Offset(0')
          ? KwanTheme.colorOnline.withOpacity(0.2)
          : KwanTheme.colorBooked.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    // Get blob outline
    final outline = dragger.getBlobOutline();
    if (outline.isEmpty) return;

    // Draw blob shape
    final path = Path();
    final start = outline[0];
    path.moveTo(start.anchor.dx, start.anchor.dy);

    for (var i = 0; i < outline.length; i++) {
      final current = outline[i];
      final next = outline[(i + 1) % outline.length];

      path.cubicTo(
        current.control1.dx,
        current.control1.dy,
        next.control2.dx,
        next.control2.dy,
        next.anchor.dx,
        next.anchor.dy,
      );
    }

    path.close();
    canvas.drawPath(path, paint);

    // Draw outline for visibility
    final outlinePaint = Paint()
      ..color = KwanTheme.glassBorder.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    canvas.drawPath(path, outlinePaint);
  }

  @override
  bool shouldRepaint(GooeyBlobPainter oldDelegate) => true;
}
