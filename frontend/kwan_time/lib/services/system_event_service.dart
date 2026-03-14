import '../data/festival_calendar.dart';
import '../models/system_event_model.dart';

class SystemEventService {
  SystemEventService._();

  static final SystemEventService _instance = SystemEventService._();

  factory SystemEventService() => _instance;

  List<SystemEventModel> _events = <SystemEventModel>[];

  List<SystemEventModel> get events => List<SystemEventModel>.unmodifiable(_events);

  Future<void> initialize(int year) async {
    final generated = <SystemEventModel>[
      ...FestivalCalendar.generateForYear(year),
      ...FestivalCalendar.generateForYear(year + 1),
    ];

    final deduped = <String, SystemEventModel>{};
    for (final event in generated) {
      deduped[event.id] = event;
    }

    _events = deduped.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  List<SystemEventModel> eventsForMonth(int year, int month) {
    final filtered = _events.where((event) => event.date.year == year && event.date.month == month).toList();
    filtered.sort((a, b) => a.date.compareTo(b.date));
    return filtered;
  }
}
