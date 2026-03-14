import 'package:riverpod/riverpod.dart';
import 'package:kwan_time/core/providers/interfaces.dart';

// ═══════════════════════════════════════════════════════════════════════════
// STATE MODELS
// ═══════════════════════════════════════════════════════════════════════════

class BookingState {
  BookingState({
    this.bookingPage,
    this.selectedDate,
    this.selectedSlot,
    this.availableSlots = const [],
    this.isLoadingSlots = false,
    this.isSubmitting = false,
    this.errorMessage,
    this.submitSuccess,
  });
  final BookingPage? bookingPage;
  final DateTime? selectedDate;
  final AvailableSlot? selectedSlot;
  final List<AvailableSlot> availableSlots;
  final bool isLoadingSlots;
  final bool isSubmitting;
  final String? errorMessage;
  final bool? submitSuccess;

  BookingState copyWith({
    BookingPage? bookingPage,
    DateTime? selectedDate,
    AvailableSlot? selectedSlot,
    List<AvailableSlot>? availableSlots,
    bool? isLoadingSlots,
    bool? isSubmitting,
    String? errorMessage,
    bool? submitSuccess,
  }) =>
      BookingState(
        bookingPage: bookingPage ?? this.bookingPage,
        selectedDate: selectedDate ?? this.selectedDate,
        selectedSlot: selectedSlot ?? this.selectedSlot,
        availableSlots: availableSlots ?? this.availableSlots,
        isLoadingSlots: isLoadingSlots ?? this.isLoadingSlots,
        isSubmitting: isSubmitting ?? this.isSubmitting,
        errorMessage: errorMessage,
        submitSuccess: submitSuccess,
      );

  /// Reset date and slot selections for new date selection
  BookingState resetSelection() => BookingState(
        bookingPage: bookingPage,
        availableSlots: availableSlots,
        isLoadingSlots: isLoadingSlots,
        isSubmitting: isSubmitting,
      );

  /// Clear error message after displaying it
  BookingState clearError() => copyWith(errorMessage: '');
}

// ═══════════════════════════════════════════════════════════════════════════
// BOOKING PROVIDER — AsyncNotifier for state management
// ═══════════════════════════════════════════════════════════════════════════

class BookingNotifier extends AsyncNotifier<BookingState> {
  late IBookingViewModel _viewModel;

  @override
  Future<BookingState> build() async {
    // TODO: Inject IBookingViewModel from service locator
    // For now, this will be implemented by Agent 2 API client
    _viewModel = _createMockViewModel();

    try {
      final bookingPage = await _viewModel.getMyBookingPage();
      return BookingState(bookingPage: bookingPage);
    } catch (e) {
      return BookingState(
        errorMessage: 'Failed to load booking page: ${e.toString()}',
      );
    }
  }

  /// Load available slots for a specific date
  Future<void> loadAvailableSlots(DateTime date) async {
    // Update state to loading
    state = AsyncData(state.value!.copyWith(
      selectedDate: date,
      isLoadingSlots: true,
      availableSlots: [],
    ));

    try {
      final slots = await _viewModel.getAvailableSlots(date);
      state = AsyncData(state.value!.copyWith(
        availableSlots: slots,
        isLoadingSlots: false,
        selectedSlot: null,
      ));
    } catch (e) {
      state = AsyncData(state.value!.copyWith(
        isLoadingSlots: false,
        errorMessage: 'Failed to load available slots: ${e.toString()}',
      ));
    }
  }

  /// Select a time slot
  void selectSlot(AvailableSlot slot) {
    state = AsyncData(state.value!.copyWith(selectedSlot: slot));
  }

  /// Submit a booking request
  Future<bool> submitBooking({
    required String clientName,
    required String clientEmail,
    String? notes,
  }) async {
    if (state.value?.selectedDate == null || state.value?.selectedSlot == null) {
      state = AsyncData(state.value!.copyWith(
        errorMessage: 'Please select a date and time',
      ));
      return false;
    }

    final slot = state.value!.selectedSlot!;
    final date = state.value!.selectedDate!;

    // Update state to submitting
    state = AsyncData(state.value!.copyWith(isSubmitting: true));

    try {
      final bookingRequest = BookingRequest(
        date: '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        time: '${slot.startTime.hour.toString().padLeft(2, '0')}:${slot.startTime.minute.toString().padLeft(2, '0')}',
        clientName: clientName,
        clientEmail: clientEmail,
        notes: notes,
      );

      // TODO: Use booking page slug once API is ready
      await _viewModel.submitBooking('booking-slug', bookingRequest);

      state = AsyncData(state.value!.copyWith(
        isSubmitting: false,
        submitSuccess: true,
      ));
      return true;
    } catch (e) {
      state = AsyncData(state.value!.copyWith(
        isSubmitting: false,
        errorMessage: 'Booking failed: ${e.toString()}',
        submitSuccess: false,
      ));
      return false;
    }
  }

  /// Generate shareable booking link
  Future<String> generateShareLink() async {
    try {
      return await _viewModel.generateShareLink();
    } catch (e) {
      state = AsyncData(state.value!.copyWith(
        errorMessage: 'Failed to generate share link: ${e.toString()}',
      ));
      rethrow;
    }
  }

  /// Clear error message
  void clearError() {
    if (state.value != null) {
      state = AsyncData(state.value!.clearError());
    }
  }

  /// Reset booking flow (after successful submission)
  void resetBooking() {
    if (state.value != null) {
      state = AsyncData(state.value!.copyWith(
        selectedDate: null,
        selectedSlot: null,
        availableSlots: [],
        submitSuccess: false,
        errorMessage: '',
      ));
    }
  }

  // ───────────────────────────────────────────────────────────────────────
  // Mock ViewModel for development (will be replaced by Agent 2 API client)
  // ───────────────────────────────────────────────────────────────────────
  IBookingViewModel _createMockViewModel() => _MockBookingViewModel();
}

// ═══════════════════════════════════════════════════════════════════════════
// PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════

/// Main booking provider for state management
final bookingProvider = AsyncNotifierProvider<BookingNotifier, BookingState>(
  BookingNotifier.new,
);

/// Selected date stream
final selectedDateProvider = StateProvider<DateTime?>((_) => null);

/// Selected time slot stream
final selectedSlotProvider = StateProvider<AvailableSlot?>((_) => null);

// ═══════════════════════════════════════════════════════════════════════════
// MOCK IMPLEMENTATION (for development, replaced by Agent 2)
// ═══════════════════════════════════════════════════════════════════════════

class _MockBookingViewModel implements IBookingViewModel {
  @override
  Future<BookingPage> getMyBookingPage() async {
    // Mock implementation
    return BookingPage(
      slug: 'john-smith',
      title: 'Book a 30-min consultation',
      durationMinutes: 30,
      bufferMinutes: 15,
      isActive: true,
      maxAdvanceDays: 90,
      shareUrl: 'https://kwan.time/u/john-smith/book',
    );
  }

  @override
  Future<List<AvailableSlot>> getAvailableSlots(DateTime date) async {
    // Mock implementation - return some sample slots
    await Future.delayed(const Duration(milliseconds: 500));

    return [
      AvailableSlot(
        startTime: date.add(const Duration(hours: 9)),
        endTime: date.add(const Duration(hours: 9, minutes: 30)),
        displayText: '9:00 AM · 30min',
      ),
      AvailableSlot(
        startTime: date.add(const Duration(hours: 10)),
        endTime: date.add(const Duration(hours: 10, minutes: 30)),
        displayText: '10:00 AM · 30min',
      ),
      AvailableSlot(
        startTime: date.add(const Duration(hours: 11)),
        endTime: date.add(const Duration(hours: 11, minutes: 30)),
        displayText: '11:00 AM · 30min',
      ),
      AvailableSlot(
        startTime: date.add(const Duration(hours: 14)),
        endTime: date.add(const Duration(hours: 14, minutes: 30)),
        displayText: '2:00 PM · 30min',
      ),
      AvailableSlot(
        startTime: date.add(const Duration(hours: 15)),
        endTime: date.add(const Duration(hours: 15, minutes: 30)),
        displayText: '3:00 PM · 30min',
      ),
      AvailableSlot(
        startTime: date.add(const Duration(hours: 16)),
        endTime: date.add(const Duration(hours: 16, minutes: 30)),
        displayText: '4:00 PM · 30min',
      ),
    ];
  }

  @override
  Future<String> generateShareLink() async => 'https://kwan.time/u/john-smith/book';

  @override
  Future<void> submitBooking(String slug, BookingRequest request) async {
    // Mock implementation
    await Future.delayed(const Duration(seconds: 1));
  }

  @override
  Stream<Event> incomingBookings() {
    // Mock implementation
    return const Stream.empty();
  }

  @override
  Future<void> setBookingPageActive(bool active) async {
    // Mock implementation
  }

  @override
  Future<void> updateBookingPageSettings({
    String? title,
    int? durationMinutes,
    int? bufferMinutes,
    int? maxAdvanceDays,
  }) async {
    // Mock implementation
  }
}
