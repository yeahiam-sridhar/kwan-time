import 'dart:io';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/models/event.dart';

class ExportService {
  ExportService._();

  static final ExportService instance = ExportService._();

  Future<void> exportMonthToExcel({
    required List<Event> events,
    required DateTime month,
    String memberName = 'KWAN·TIME',
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['Monthly Events'];

    const headers = <String>[
      'Date',
      'Day',
      'Month',
      'Year',
      'Event Title',
      'Start Time',
      'End Time',
      'Location',
      'Category',
      'Notes',
    ];

    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
      );
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#1A237E'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      );
    }

    final filtered = events
        .where(
          (event) =>
              event.startTime.year == month.year &&
              event.startTime.month == month.month,
        )
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    for (var i = 0; i < filtered.length; i++) {
      final event = filtered[i];
      final row = i + 1;
      final values = <String>[
        DateFormat('dd/MM/yyyy').format(event.startTime),
        DateFormat('EEEE').format(event.startTime),
        DateFormat('MMMM').format(event.startTime),
        event.startTime.year.toString(),
        event.title,
        DateFormat('HH:mm').format(event.startTime),
        DateFormat('HH:mm').format(event.endTime),
        event.location ?? '',
        event.eventType == 'online' ? 'Online' : 'In-Person',
        event.notes ?? '',
      ];

      for (var c = 0; c < values.length; c++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row))
            .value = TextCellValue(values[c]);
      }
    }

    sheet.setColumnWidth(0, 14);
    sheet.setColumnWidth(4, 28);
    sheet.setColumnWidth(7, 20);

    final bytes = excel.save();
    if (bytes == null) {
      throw StateError('Excel generation failed.');
    }

    final dir = await getApplicationDocumentsDirectory();
    final fileName = 'KWAN_${DateFormat('yyyy_MM').format(month)}.xlsx';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);

    await Share.shareXFiles(
      <XFile>[
        XFile(
          file.path,
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        ),
      ],
      subject: '$memberName — ${DateFormat('MMMM yyyy').format(month)}',
      text: 'Monthly schedule export from $memberName',
    );
  }
}
