import '../models/system_event_model.dart';

class FestivalCalendar {
  static List<SystemEventModel> generateForYear(int year) {
    return <SystemEventModel>[
      ..._indianFestivals(year),
      ..._indianNationalHolidays(year),
      ..._globalFestivals(year),
    ];
  }

  static List<SystemEventModel> _indianFestivals(int year) => <SystemEventModel>[
        SystemEventModel(
          id: 'pongal_$year',
          title: 'Pongal',
          date: _pongalDate(year),
          category: 'indian_festival',
          emoji: '\u{1F33E}',
          regionCode: 'IN',
        ),
        SystemEventModel(
          id: 'maha_shivaratri_$year',
          title: 'Maha Shivaratri',
          date: _mahaShivaratriDate(year),
          category: 'indian_festival',
          emoji: '\u{1F531}',
          regionCode: 'IN',
        ),
        SystemEventModel(
          id: 'holi_$year',
          title: 'Holi',
          date: _holiDate(year),
          category: 'indian_festival',
          emoji: '\u{1F3A8}',
          regionCode: 'IN',
        ),
        SystemEventModel(
          id: 'eid_al_fitr_$year',
          title: 'Eid al-Fitr (Ramzan)',
          date: _eidAlFitrDate(year),
          category: 'indian_festival',
          emoji: '\u{1F319}',
          regionCode: 'IN',
        ),
        SystemEventModel(
          id: 'eid_al_adha_$year',
          title: 'Eid al-Adha (Bakrid)',
          date: _eidAlAdhaDate(year),
          category: 'indian_festival',
          emoji: '\u{1F404}',
          regionCode: 'IN',
        ),
        SystemEventModel(
          id: 'muharram_$year',
          title: 'Muharram',
          date: _muharramDate(year),
          category: 'indian_festival',
          emoji: '\u{262A}\u{FE0F}',
          regionCode: 'IN',
        ),
        SystemEventModel(
          id: 'raksha_bandhan_$year',
          title: 'Raksha Bandhan',
          date: _rakshaBandhanDate(year),
          category: 'indian_festival',
          emoji: '\u{1F9F5}',
          regionCode: 'IN',
        ),
        SystemEventModel(
          id: 'krishna_janmashtami_$year',
          title: 'Krishna Janmashtami',
          date: _janmashtamiDate(year),
          category: 'indian_festival',
          emoji: '\u{1F66D}',
          regionCode: 'IN',
        ),
        SystemEventModel(
          id: 'ganesh_chaturthi_$year',
          title: 'Vinayagar Chaturthi',
          date: _ganeshChaturthiDate(year),
          category: 'indian_festival',
          emoji: '\u{1F418}',
          regionCode: 'IN',
        ),
        SystemEventModel(
          id: 'onam_$year',
          title: 'Onam',
          date: _onamDate(year),
          category: 'indian_festival',
          emoji: '\u{1F338}',
          regionCode: 'IN',
        ),
        SystemEventModel(
          id: 'navaratri_$year',
          title: 'Navaratri',
          date: _navaratriDate(year),
          category: 'indian_festival',
          emoji: '\u{1FA94}',
          regionCode: 'IN',
        ),
        SystemEventModel(
          id: 'dussehra_$year',
          title: 'Dussehra',
          date: _navaratriDate(year).add(const Duration(days: 9)),
          category: 'indian_festival',
          emoji: '\u{1F3F9}',
          regionCode: 'IN',
        ),
        SystemEventModel(
          id: 'diwali_$year',
          title: 'Deepavali (Diwali)',
          date: _diwaliDate(year),
          category: 'indian_festival',
          emoji: '\u{2728}',
          regionCode: 'IN',
        ),
      ];

  static List<SystemEventModel> _indianNationalHolidays(int year) => <SystemEventModel>[
        SystemEventModel(
          id: 'republic_day_$year',
          title: 'Republic Day',
          date: DateTime(year, 1, 26),
          category: 'national_holiday',
          emoji: '\u{1F1EE}\u{1F1F3}',
          regionCode: 'IN',
        ),
        SystemEventModel(
          id: 'independence_day_$year',
          title: 'Independence Day',
          date: DateTime(year, 8, 15),
          category: 'national_holiday',
          emoji: '\u{1F1EE}\u{1F1F3}',
          regionCode: 'IN',
        ),
        SystemEventModel(
          id: 'gandhi_jayanti_$year',
          title: 'Gandhi Jayanti',
          date: DateTime(year, 10, 2),
          category: 'national_holiday',
          emoji: '\u{1F54A}\u{FE0F}',
          regionCode: 'IN',
        ),
      ];

  static List<SystemEventModel> _globalFestivals(int year) => <SystemEventModel>[
        SystemEventModel(
          id: 'new_year_$year',
          title: "New Year's Day",
          date: DateTime(year, 1, 1),
          category: 'global_festival',
          emoji: '\u{1F386}',
          regionCode: 'GLOBAL',
        ),
        SystemEventModel(
          id: 'chinese_new_year_$year',
          title: 'Chinese New Year',
          date: _chineseNewYearDate(year),
          category: 'global_festival',
          emoji: '\u{1F9E7}',
          regionCode: 'GLOBAL',
        ),
        SystemEventModel(
          id: 'easter_$year',
          title: 'Easter Sunday',
          date: _easterDate(year),
          category: 'global_festival',
          emoji: '\u{1F423}',
          regionCode: 'GLOBAL',
        ),
        SystemEventModel(
          id: 'halloween_$year',
          title: 'Halloween',
          date: DateTime(year, 10, 31),
          category: 'global_festival',
          emoji: '\u{1F383}',
          regionCode: 'GLOBAL',
        ),
        SystemEventModel(
          id: 'thanksgiving_$year',
          title: 'Thanksgiving (US)',
          date: _thanksgivingDate(year),
          category: 'global_festival',
          emoji: '\u{1F983}',
          regionCode: 'US',
        ),
        SystemEventModel(
          id: 'christmas_$year',
          title: 'Christmas',
          date: DateTime(year, 12, 25),
          category: 'global_festival',
          emoji: '\u{1F384}',
          regionCode: 'GLOBAL',
        ),
      ];

  static DateTime _pongalDate(int year) {
    final isLeap = (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
    return DateTime(year, 1, isLeap ? 15 : 14);
  }

  static DateTime _easterDate(int year) {
    final a = year % 19;
    final b = year ~/ 100;
    final c = year % 100;
    final d = b ~/ 4;
    final e = b % 4;
    final f = (b + 8) ~/ 25;
    final g = (b - f + 1) ~/ 3;
    final h = (19 * a + b - d - g + 15) % 30;
    final i = c ~/ 4;
    final k = c % 4;
    final l = (32 + (2 * e) + (2 * i) - h - k) % 7;
    final m = (a + (11 * h) + (22 * l)) ~/ 451;
    final month = (h + l - (7 * m) + 114) ~/ 31;
    final day = ((h + l - (7 * m) + 114) % 31) + 1;
    return DateTime(year, month, day);
  }

  static DateTime _thanksgivingDate(int year) {
    final nov1 = DateTime(year, 11, 1);
    final daysToThursday = (DateTime.thursday - nov1.weekday + 7) % 7;
    final firstThursday = nov1.add(Duration(days: daysToThursday));
    return firstThursday.add(const Duration(days: 21));
  }

  static DateTime _holiDate(int year) {
    const known = <int, List<int>>{
      2024: <int>[3, 25],
      2025: <int>[3, 14],
      2026: <int>[3, 3],
      2027: <int>[3, 22],
      2028: <int>[3, 11],
      2029: <int>[3, 1],
      2030: <int>[3, 19],
    };
    if (known.containsKey(year)) {
      return DateTime(year, known[year]![0], known[year]![1]);
    }
    return DateTime(year, 3, 10);
  }

  static DateTime _diwaliDate(int year) {
    const known = <int, List<int>>{
      2024: <int>[11, 1],
      2025: <int>[10, 20],
      2026: <int>[11, 8],
      2027: <int>[10, 29],
      2028: <int>[10, 17],
      2029: <int>[11, 5],
      2030: <int>[10, 26],
    };
    if (known.containsKey(year)) {
      return DateTime(year, known[year]![0], known[year]![1]);
    }
    return DateTime(year, 10, 24);
  }

  static DateTime _ganeshChaturthiDate(int year) {
    const known = <int, List<int>>{
      2024: <int>[9, 7],
      2025: <int>[8, 27],
      2026: <int>[9, 15],
      2027: <int>[9, 4],
      2028: <int>[8, 23],
      2029: <int>[9, 11],
      2030: <int>[9, 1],
    };
    if (known.containsKey(year)) {
      return DateTime(year, known[year]![0], known[year]![1]);
    }
    return DateTime(year, 9, 1);
  }

  static DateTime _navaratriDate(int year) {
    const known = <int, List<int>>{
      2024: <int>[10, 3],
      2025: <int>[9, 22],
      2026: <int>[10, 11],
      2027: <int>[10, 1],
      2028: <int>[9, 19],
      2029: <int>[10, 8],
      2030: <int>[9, 27],
    };
    if (known.containsKey(year)) {
      return DateTime(year, known[year]![0], known[year]![1]);
    }
    return DateTime(year, 10, 2);
  }

  static DateTime _eidAlFitrDate(int year) {
    const known = <int, List<int>>{
      2024: <int>[4, 10],
      2025: <int>[3, 30],
      2026: <int>[3, 20],
      2027: <int>[3, 9],
      2028: <int>[2, 26],
      2029: <int>[2, 14],
      2030: <int>[2, 4],
    };
    if (known.containsKey(year)) {
      return DateTime(year, known[year]![0], known[year]![1]);
    }
    final base = DateTime(2025, 3, 30);
    return base.add(Duration(days: -11 * (year - 2025)));
  }

  static DateTime _eidAlAdhaDate(int year) {
    const known = <int, List<int>>{
      2024: <int>[6, 17],
      2025: <int>[6, 6],
      2026: <int>[5, 27],
      2027: <int>[5, 16],
      2028: <int>[5, 5],
      2029: <int>[4, 24],
      2030: <int>[4, 13],
    };
    if (known.containsKey(year)) {
      return DateTime(year, known[year]![0], known[year]![1]);
    }
    return _eidAlFitrDate(year).add(const Duration(days: 70));
  }

  static DateTime _muharramDate(int year) {
    const known = <int, List<int>>{
      2024: <int>[7, 7],
      2025: <int>[6, 26],
      2026: <int>[6, 16],
      2027: <int>[6, 5],
      2028: <int>[5, 25],
      2029: <int>[5, 14],
      2030: <int>[5, 3],
    };
    if (known.containsKey(year)) {
      return DateTime(year, known[year]![0], known[year]![1]);
    }
    return DateTime(year, 6, 15);
  }

  static DateTime _chineseNewYearDate(int year) {
    const known = <int, List<int>>{
      2024: <int>[2, 10],
      2025: <int>[1, 29],
      2026: <int>[2, 17],
      2027: <int>[2, 6],
      2028: <int>[1, 26],
      2029: <int>[2, 13],
      2030: <int>[2, 3],
    };
    if (known.containsKey(year)) {
      return DateTime(year, known[year]![0], known[year]![1]);
    }
    return DateTime(year, 2, 5);
  }

  static DateTime _mahaShivaratriDate(int year) {
    const known = <int, List<int>>{
      2024: <int>[3, 8],
      2025: <int>[2, 26],
      2026: <int>[2, 15],
      2027: <int>[3, 6],
      2028: <int>[2, 23],
      2029: <int>[2, 11],
      2030: <int>[3, 1],
    };
    if (known.containsKey(year)) {
      return DateTime(year, known[year]![0], known[year]![1]);
    }
    return DateTime(year, 2, 20);
  }

  static DateTime _rakshaBandhanDate(int year) {
    const known = <int, List<int>>{
      2024: <int>[8, 19],
      2025: <int>[8, 9],
      2026: <int>[8, 28],
      2027: <int>[8, 17],
      2028: <int>[8, 5],
      2029: <int>[8, 24],
      2030: <int>[8, 14],
    };
    if (known.containsKey(year)) {
      return DateTime(year, known[year]![0], known[year]![1]);
    }
    return DateTime(year, 8, 15);
  }

  static DateTime _janmashtamiDate(int year) {
    const known = <int, List<int>>{
      2024: <int>[8, 26],
      2025: <int>[8, 16],
      2026: <int>[9, 4],
      2027: <int>[8, 25],
      2028: <int>[8, 12],
      2029: <int>[8, 31],
      2030: <int>[8, 21],
    };
    if (known.containsKey(year)) {
      return DateTime(year, known[year]![0], known[year]![1]);
    }
    return DateTime(year, 8, 22);
  }

  static DateTime _onamDate(int year) {
    const known = <int, List<int>>{
      2024: <int>[9, 15],
      2025: <int>[9, 5],
      2026: <int>[8, 25],
      2027: <int>[9, 13],
      2028: <int>[9, 1],
      2029: <int>[8, 21],
      2030: <int>[9, 10],
    };
    if (known.containsKey(year)) {
      return DateTime(year, known[year]![0], known[year]![1]);
    }
    return DateTime(year, 9, 8);
  }
}
