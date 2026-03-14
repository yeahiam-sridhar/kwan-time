import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kwan_time/core/theme/kwan_theme.dart';
import 'package:kwan_time/features/public_booking/providers/booking_provider.dart';
import 'package:kwan_time/features/public_booking/widgets/date_selector.dart';
import 'package:kwan_time/features/public_booking/widgets/time_slot_selector.dart';
import 'package:kwan_time/features/public_booking/widgets/booking_form.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// BOOKING VIEW — Public-facing booking page
/// ═══════════════════════════════════════════════════════════════════════════
/// Shows available dates and times for client to book a meeting.
/// Uses glassmorphism design, smooth animations, and optimistic UX.
class BookingView extends ConsumerStatefulWidget {
  const BookingView({super.key, this.slug});
  final String? slug;

  @override
  ConsumerState<BookingView> createState() => _BookingViewState();
}

class _BookingViewState extends ConsumerState<BookingView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late PageController _pageController;

  int _currentStep = 0; // 0: Date, 1: Time, 2: Form, 3: Confirmation

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _pageController = PageController();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookingAsync = ref.watch(bookingProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(bookingProvider);
      },
      child: Scaffold(
        backgroundColor: KwanTheme.darkBg,
        appBar: _buildAppBar(context),
        body: bookingAsync.when(
          data: (state) => _buildContent(context, state),
          loading: _buildLoading,
          error: (error, stack) => _buildError(context, error),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) => AppBar(
        backgroundColor: KwanTheme.darkBg,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    KwanTheme.neonBlue.withOpacity(0.3),
                    KwanTheme.accentPurple.withOpacity(0.3),
                  ],
                ),
                border: Border.all(
                  color: KwanTheme.neonBlue.withOpacity(0.5),
                ),
              ),
              child: Center(
                child: Text(
                  '📅',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Book a Meeting',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                  ),
                  Text(
                    'Step ${_currentStep + 1} of 3',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: KwanTheme.glassText,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _buildContent(BuildContext context, dynamic state) => Column(
        children: [
          // Progress indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (_currentStep + 1) / 3,
                minHeight: 4,
                backgroundColor: KwanTheme.darkGlass.withOpacity(0.5),
                valueColor: AlwaysStoppedAnimation<Color>(
                  KwanTheme.neonBlue.withOpacity(0.8),
                ),
              ),
            ),
          ),
          // Step content
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _currentStep = index);
              },
              children: [
                // Step 1: Date Selection
                _buildStep1DateSelection(context, state),
                // Step 2: Time Selection
                _buildStep2TimeSelection(context, state),
                // Step 3: Client Info Form
                _buildStep3ClientForm(context, state),
                // Step 4: Confirmation
                _buildStep4Confirmation(context, state),
              ],
            ),
          ),
          // Navigation buttons
          _buildNavigationBar(context),
        ],
      );

  Widget _buildStep1DateSelection(BuildContext context, dynamic state) => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select a Date',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose an available date in the next ${state.bookingPage?.maxAdvanceDays ?? 90} days',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: KwanTheme.glassText,
                  ),
            ),
            const SizedBox(height: 24),
            DateSelectorWidget(
              maxAdvanceDays: state.bookingPage?.maxAdvanceDays ?? 90,
              onDateSelected: (date) {
                ref.read(bookingProvider.notifier).loadAvailableSlots(date);
              },
            ),
          ],
        ),
      );

  Widget _buildStep2TimeSelection(BuildContext context, dynamic state) => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select a Time',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '${state.bookingPage?.durationMinutes ?? 30}-minute meeting',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: KwanTheme.glassText,
                  ),
            ),
            const SizedBox(height: 24),
            if (state.isLoadingSlots)
              _buildSlotLoadingState(context)
            else if (state.availableSlots.isEmpty)
              _buildNoSlotsState(context)
            else
              TimeSlotselectorWidget(
                slots: state.availableSlots,
                onSlotSelected: (slot) {
                  ref.read(bookingProvider.notifier).selectSlot(slot);
                },
              ),
          ],
        ),
      );

  Widget _buildStep3ClientForm(BuildContext context, dynamic state) => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Information',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Help us contact you about your booking',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: KwanTheme.glassText,
                  ),
            ),
            const SizedBox(height: 24),
            BookingFormWidget(
              isSubmitting: state.isSubmitting,
              onSubmit: (name, email, notes) {
                ref.read(bookingProvider.notifier).submitBooking(
                      clientName: name,
                      clientEmail: email,
                      notes: notes,
                    );
              },
            ),
          ],
        ),
      );

  Widget _buildStep4Confirmation(BuildContext context, dynamic state) {
    final selectedDate = state.selectedDate;
    final selectedSlot = state.selectedSlot;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          // Success icon with animation
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 800),
            curve: Curves.elasticOut,
            builder: (context, value, child) => Transform.scale(
              scale: value,
              child: child,
            ),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    KwanTheme.neonGreen.withOpacity(0.3),
                    KwanTheme.neonGreen.withOpacity(0.1),
                  ],
                ),
                border: Border.all(
                  color: KwanTheme.neonGreen.withOpacity(0.8),
                  width: 2,
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.check_circle,
                  color: KwanTheme.neonGreen,
                  size: 50,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Booking Confirmed!',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Text(
            'Your meeting has been scheduled',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: KwanTheme.glassText,
                ),
          ),
          const SizedBox(height: 32),
          // Booking details card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: KwanTheme.glassStroke,
              ),
              color: KwanTheme.darkGlass.withOpacity(0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _confirmationRow(
                  context,
                  'Date',
                  selectedDate != null ? '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}' : '-',
                ),
                const SizedBox(height: 12),
                _confirmationRow(
                  context,
                  'Time',
                  selectedSlot?.displayText ?? '-',
                ),
                const SizedBox(height: 12),
                _confirmationRow(
                  context,
                  'Duration',
                  '${state.bookingPage?.durationMinutes ?? 30} minutes',
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          Text(
            'A confirmation email has been sent to your inbox',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: KwanTheme.glassText,
                ),
          ),
        ],
      ),
    );
  }

  Widget _confirmationRow(
    BuildContext context,
    String label,
    String value,
  ) =>
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: KwanTheme.glassText,
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      );

  Widget _buildNavigationBar(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(
              color: KwanTheme.glassStroke,
            ),
          ),
        ),
        child: Row(
          children: [
            // Previous button
            if (_currentStep > 0)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _previousStep,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: KwanTheme.neonBlue,
                    side: BorderSide(
                      color: KwanTheme.neonBlue.withOpacity(0.5),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              )
            else
              const SizedBox(),
            if (_currentStep > 0) const SizedBox(width: 12),
            // Next button
            Expanded(
              child: FilledButton.icon(
                onPressed: _currentStep < 3 ? _nextStep : null,
                icon: Icon(_currentStep == 3 ? Icons.check : Icons.arrow_forward),
                label: Text(_currentStep == 3 ? 'Done' : 'Next'),
                style: FilledButton.styleFrom(
                  backgroundColor: KwanTheme.neonBlue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: KwanTheme.glassStroke,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _buildSlotLoadingState(BuildContext context) => Column(
        children: [
          for (int i = 0; i < 3; i++) ...[
            Container(
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: KwanTheme.darkGlass.withOpacity(0.3),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      );

  Widget _buildNoSlotsState(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy,
              size: 64,
              color: KwanTheme.neonOrange.withOpacity(0.6),
            ),
            const SizedBox(height: 16),
            Text(
              'No Available Slots',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please select a different date',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: KwanTheme.glassText,
                  ),
            ),
          ],
        ),
      );

  Widget _buildLoading() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  KwanTheme.neonBlue.withOpacity(0.8),
                ),
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading booking page...',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: KwanTheme.glassText,
                  ),
            ),
          ],
        ),
      );

  Widget _buildError(BuildContext context, Object error) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: KwanTheme.neonOrange.withOpacity(0.8),
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: KwanTheme.glassText,
                  ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                ref.invalidate(bookingProvider);
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
}
