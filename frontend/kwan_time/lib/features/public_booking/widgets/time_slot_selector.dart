import 'package:flutter/material.dart';
import 'package:kwan_time/core/providers/interfaces.dart';
import 'package:kwan_time/core/theme/kwan_theme.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// TIME SLOT SELECTOR WIDGET — Shows available appointment times
/// ═══════════════════════════════════════════════════════════════════════════

class TimeSlotselectorWidget extends StatefulWidget {
  const TimeSlotselectorWidget({
    required this.slots,
    required this.onSlotSelected,
    super.key,
  });
  final List<AvailableSlot> slots;
  final Function(AvailableSlot) onSlotSelected;

  @override
  State<TimeSlotselectorWidget> createState() => _TimeSlotselectorWidgetState();
}

class _TimeSlotselectorWidgetState extends State<TimeSlotselectorWidget> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  AvailableSlot? _selectedSlot;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _selectSlot(AvailableSlot slot) {
    setState(() => _selectedSlot = slot);
    _animationController.forward(from: 0);
    widget.onSlotSelected(slot);
  }

  @override
  Widget build(BuildContext context) {
    // Group slots by morning/afternoon/evening
    final morningSlots = widget.slots.where((s) => s.startTime.hour < 12).toList();
    final afternoonSlots = widget.slots.where((s) => s.startTime.hour >= 12 && s.startTime.hour < 17).toList();
    final eveningSlots = widget.slots.where((s) => s.startTime.hour >= 17).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (morningSlots.isNotEmpty) ...[
          _buildTimeGroup(context, 'Morning', morningSlots),
          const SizedBox(height: 20),
        ],
        if (afternoonSlots.isNotEmpty) ...[
          _buildTimeGroup(context, 'Afternoon', afternoonSlots),
          const SizedBox(height: 20),
        ],
        if (eveningSlots.isNotEmpty) ...[
          _buildTimeGroup(context, 'Evening', eveningSlots),
        ],
      ],
    );
  }

  Widget _buildTimeGroup(
    BuildContext context,
    String label,
    List<AvailableSlot> slots,
  ) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group label
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: KwanTheme.glassText,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
          ),
          const SizedBox(height: 12),
          // Slots grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.2,
            ),
            itemCount: slots.length,
            itemBuilder: (context, index) {
              final slot = slots[index];
              final isSelected = _selectedSlot?.startTime == slot.startTime;

              return _buildSlotButton(context, slot, isSelected);
            },
          ),
        ],
      );

  Widget _buildSlotButton(
    BuildContext context,
    AvailableSlot slot,
    bool isSelected,
  ) =>
      GestureDetector(
        onTap: () => _selectSlot(slot),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? KwanTheme.neonBlue : KwanTheme.glassStroke,
              width: isSelected ? 2 : 1,
            ),
            color: isSelected ? KwanTheme.neonBlue.withOpacity(0.15) : KwanTheme.darkGlass.withOpacity(0.3),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: KwanTheme.neonBlue.withOpacity(0.3),
                      blurRadius: 12,
                      spreadRadius: 0,
                    ),
                  ]
                : [],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _selectSlot(slot),
              borderRadius: BorderRadius.circular(12),
              splashColor: KwanTheme.neonBlue.withOpacity(0.2),
              highlightColor: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Time
                    Text(
                      _formatTime(slot.startTime),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    // Duration
                    Text(
                      '${slot.endTime.difference(slot.startTime).inMinutes}min',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: KwanTheme.glassText,
                            fontSize: 10,
                          ),
                    ),
                    // Checkmark for selected
                    if (isSelected) ...[
                      const SizedBox(height: 4),
                      const Icon(
                        Icons.check_circle,
                        size: 14,
                        color: KwanTheme.neonGreen,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
