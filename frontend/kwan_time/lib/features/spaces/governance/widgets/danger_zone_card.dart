// ============================================================================
// lib/features/spaces/governance/widgets/danger_zone_card.dart
// ============================================================================

import 'package:flutter/material.dart';

class DangerZoneCard extends StatelessWidget {
  const DangerZoneCard({
    super.key,
    required this.onDeleteSpace,
    required this.onTransferOwnership,
  });

  final VoidCallback onDeleteSpace;
  final VoidCallback onTransferOwnership;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.red.shade300),
        borderRadius: BorderRadius.circular(14),
        color: Colors.red.shade50.withOpacity(0.08),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Danger zone',
            style: TextStyle(
              color: Colors.red.shade300,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _confirmDelete(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.delete_forever),
              label: const Text('Delete space'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onTransferOwnership,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.orange.shade300),
                foregroundColor: Colors.orange.shade200,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.swap_horiz),
              label: const Text('Transfer ownership'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final bool confirm = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Delete space?'),
              content: const Text(
                'Deleting a space will permanently remove all events and cannot be undone',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(
                    'Delete',
                    style: TextStyle(color: Colors.red.shade600),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;
    if (confirm) {
      onDeleteSpace();
    }
  }
}
