import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/conflict_result.dart';
import '../models/sync_event.dart';

class ConflictDialog extends StatelessWidget {
  const ConflictDialog({
    super.key,
    required this.result,
  });

  final ConflictResult result;

  static Future<bool> show(BuildContext context, ConflictResult result) async {
    final bool? createAnyway = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) => ConflictDialog(result: result),
    );
    return createAnyway ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final DateFormat timeFormatter = DateFormat('h:mm a');
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: const BoxDecoration(
        color: Color(0xFF0D1B3E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFF9A825),
                size: 28,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Schedule Conflict Detected',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'This event overlaps with ${result.conflictingEvents.length} existing event(s)',
            style: TextStyle(
              color: Colors.white.withOpacity(0.74),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: result.conflictingEvents.map((SyncEvent event) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 4,
                          height: 64,
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.horizontal(
                              left: Radius.circular(12),
                            ),
                            gradient: LinearGradient(
                              colors: <Color>[
                                _colorFromHex(event.colorHex).withOpacity(0.95),
                                _colorFromHex(event.colorHex).withOpacity(0.6),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  event.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${timeFormatter.format(event.startTime)} - ${timeFormatter.format(event.endTime)}',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.72),
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          if (result.suggestion != null &&
              result.suggestion!.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              'Suggested time: ${result.suggestion}',
              style: const TextStyle(
                color: Color(0xFF26A69A),
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.white.withOpacity(0.25)),
                    foregroundColor: const Color(0xFF90A4AE),
                    minimumSize: const Size(0, 46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE65100),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Create Anyway'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _colorFromHex(String? rawHex) {
    final String sanitized =
        (rawHex ?? '').replaceAll('#', '').replaceAll('0x', '').trim();
    if (sanitized.isEmpty) {
      return const Color(0xFF42A5F5);
    }

    final String normalized =
        sanitized.length == 6 ? 'FF$sanitized' : sanitized;
    return Color(
      int.tryParse(normalized, radix: 16) ?? 0xFF42A5F5,
    );
  }
}
