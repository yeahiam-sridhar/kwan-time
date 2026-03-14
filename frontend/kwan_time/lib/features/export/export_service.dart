import 'dart:io';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../core/models/event.dart';

class ExportService {
  ExportService._();

  static final ExportService instance = ExportService._();

  static const String _accentHex = '#1565C0';
  static const String _headerBgHex = '#0D1B3E';
  static const String _headerFgHex = '#FFFFFF';
  static const String _zebraOdd = '#F5F7FF';
  static const String _zebraEven = '#FFFFFF';
  static const String _onlineHex = '#1976D2';
  static const String _inPersonHex = '#2E7D32';
  static const String _reminderHex = '#E65100';

  Future<void> exportExcel(List<Event> events, DateTime month) async {
    final scoped = _eventsForMonth(events, month);
    final excel = Excel.createExcel();
    _buildOverviewSheet(excel, scoped, month);
    _buildDetailSheet(excel, scoped);
    excel.delete('Sheet1');

    final bytes = excel.save();
    if (bytes == null) {
      throw StateError('Unable to generate Excel export');
    }

    final dir = await getApplicationDocumentsDirectory();
    final file = File(
      '${dir.path}/KWAN_Report_${DateFormat('MMM_yyyy').format(month)}.xlsx',
    );
    await file.writeAsBytes(bytes, flush: true);

    await Share.shareXFiles(
      <XFile>[
        XFile(
          file.path,
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        ),
      ],
      subject: 'KWAN-TIME - ${DateFormat('MMMM yyyy').format(month)} Report',
      text: _generateSummaryText(scoped, month),
    );
  }

  Future<void> exportPdf(List<Event> events, DateTime month) async {
    final scoped = _eventsForMonth(events, month);
    final doc = pw.Document();
    final dateFmt = DateFormat('dd MMM yyyy');
    final timeFmt = DateFormat('HH:mm');

    doc.addPage(
      pw.MultiPage(
        pageTheme: const pw.PageTheme(
          margin: pw.EdgeInsets.fromLTRB(32, 36, 32, 36),
        ),
        build: (pw.Context context) => <pw.Widget>[
          pw.Text(
            'KWAN-TIME Executive Report',
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex(_headerBgHex),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            DateFormat('MMMM yyyy').format(month),
            style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#EEF2FF'),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Text(
              _generateSummaryText(scoped, month),
              style: const pw.TextStyle(fontSize: 10),
            ),
          ),
          pw.SizedBox(height: 14),
          pw.Table.fromTextArray(
            headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
            ),
            headerDecoration: pw.BoxDecoration(
              color: PdfColor.fromHex(_headerBgHex),
            ),
            cellAlignment: pw.Alignment.centerLeft,
            cellStyle: const pw.TextStyle(fontSize: 9),
            headers: const <String>[
              'Date',
              'Day',
              'Title',
              'Category',
              'Start',
              'End',
              'Location',
              'Status',
            ],
            data: scoped
                .map(
                  (event) => <String>[
                    dateFmt.format(event.startTime),
                    DateFormat('EEE').format(event.startTime),
                    event.title,
                    event.eventType == 'online' ? 'Online' : 'In-Person',
                    timeFmt.format(event.startTime),
                    timeFmt.format(event.endTime),
                    event.location?.trim().isEmpty == false
                        ? event.location!
                        : '--',
                    event.status == 'completed' ? 'Done' : 'Active',
                  ],
                )
                .toList(),
          ),
        ],
      ),
    );

    final bytes = await doc.save();
    final dir = await getApplicationDocumentsDirectory();
    final file = File(
      '${dir.path}/KWAN_Report_${DateFormat('MMM_yyyy').format(month)}.pdf',
    );
    await file.writeAsBytes(bytes, flush: true);

    await Share.shareXFiles(
      <XFile>[XFile(file.path, mimeType: 'application/pdf')],
      subject: 'KWAN-TIME - ${DateFormat('MMMM yyyy').format(month)} Report',
      text: _generateSummaryText(scoped, month),
    );
  }

  Future<void> exportCsv(List<Event> events, DateTime month) async {
    final scoped = _eventsForMonth(events, month);
    final buffer = StringBuffer();
    buffer.writeln(
      'Date,Day,Title,Category,Start,End,Duration(min),Location,Status,Notes',
    );

    for (final event in scoped) {
      final duration = event.endTime.difference(event.startTime).inMinutes;
      buffer.writeln(
        <Object?>[
          DateFormat('dd/MM/yyyy').format(event.startTime),
          DateFormat('EEE').format(event.startTime),
          _csv(event.title),
          event.eventType == 'online' ? 'Online' : 'In-Person',
          DateFormat('HH:mm').format(event.startTime),
          DateFormat('HH:mm').format(event.endTime),
          duration,
          _csv(event.location ?? ''),
          event.status,
          _csv(event.notes ?? ''),
        ].join(','),
      );
    }

    final dir = await getApplicationDocumentsDirectory();
    final file = File(
      '${dir.path}/KWAN_${DateFormat('MMM_yyyy').format(month)}.csv',
    );
    await file.writeAsString(buffer.toString(), flush: true);

    await Share.shareXFiles(
      <XFile>[XFile(file.path, mimeType: 'text/csv')],
      subject: 'KWAN-TIME - ${DateFormat('MMMM yyyy').format(month)} CSV',
      text: _generateSummaryText(scoped, month),
    );
  }

  List<Event> _eventsForMonth(List<Event> events, DateTime month) {
    final scoped = events
        .where(
          (event) =>
              event.startTime.year == month.year &&
              event.startTime.month == month.month,
        )
        .toList(growable: false)
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    return scoped;
  }

  void _buildOverviewSheet(Excel excel, List<Event> events, DateTime month) {
    final sheet = excel['Monthly Overview'];
    var row = 0;

    _writeCell(
      sheet,
      row,
      0,
      'Event Performance - ${DateFormat('MMMM yyyy').format(month)}',
      bold: true,
      fontSize: 18,
      bgHex: _headerBgHex,
      fgHex: _headerFgHex,
    );
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row),
    );
    row += 2;

    final total = events.length;
    final online = events.where((event) => event.eventType == 'online').length;
    final inPerson =
        events.where((event) => event.eventType == 'in_person').length;
    final peakDay = _getPeakDay(events);
    final busiestRange = _getBusiestRange(events);

    final stats = <List<String>>[
      <String>['Total Events', '$total', _accentHex],
      <String>['Online', '$online', _onlineHex],
      <String>['In-Person', '$inPerson', _inPersonHex],
      <String>['Peak Day', peakDay, _reminderHex],
      <String>['Busiest Range', busiestRange, _accentHex],
    ];

    for (final stat in stats) {
      _writeCell(
        sheet,
        row,
        0,
        stat[0],
        bold: true,
        bgHex: stat[2],
        fgHex: _headerFgHex,
      );
      _writeCell(
        sheet,
        row,
        1,
        stat[1],
        bgHex: _zebraOdd,
      );
      row++;
    }

    row++;
    _writeCell(
      sheet,
      row,
      0,
      _generateSummaryText(events, month),
      bgHex: '#EEF2FF',
      fgHex: '#1A237E',
    );
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row),
    );

    sheet.setColumnWidth(0, 24);
    sheet.setColumnWidth(1, 24);
    sheet.setColumnWidth(2, 18);
    sheet.setColumnWidth(3, 20);
  }

  void _buildDetailSheet(Excel excel, List<Event> events) {
    final sheet = excel['Detailed Events'];
    var row = 0;

    const headers = <String>[
      'Date',
      'Day',
      'Title',
      'Category',
      'Start',
      'End',
      'Duration',
      'Location',
      'Priority',
      'Notes',
    ];

    for (var column = 0; column < headers.length; column++) {
      _writeCell(
        sheet,
        row,
        column,
        headers[column],
        bold: true,
        bgHex: _headerBgHex,
        fgHex: _headerFgHex,
      );
    }
    row++;

    for (var i = 0; i < events.length; i++) {
      final event = events[i];
      final rowBg = i.isOdd ? _zebraOdd : _zebraEven;
      final categoryColor =
          event.eventType == 'online' ? _onlineHex : _inPersonHex;
      final durationMinutes = event.endTime.difference(event.startTime).inMinutes;
      final values = <String>[
        DateFormat('dd MMM yyyy').format(event.startTime),
        DateFormat('EEE').format(event.startTime),
        event.title,
        event.eventType == 'online' ? 'Online' : 'In-Person',
        DateFormat('HH:mm').format(event.startTime),
        DateFormat('HH:mm').format(event.endTime),
        '${durationMinutes}m',
        event.location?.trim().isEmpty == false ? event.location! : '--',
        event.status == 'completed' ? 'Done' : 'Active',
        event.notes ?? '',
      ];

      for (var column = 0; column < values.length; column++) {
        final isCategory = column == 3;
        _writeCell(
          sheet,
          row,
          column,
          values[column],
          bgHex: isCategory ? categoryColor : rowBg,
          fgHex: isCategory ? _headerFgHex : '#212121',
        );
      }
      row++;
    }

    sheet.setColumnWidth(0, 16);
    sheet.setColumnWidth(2, 32);
    sheet.setColumnWidth(3, 14);
    sheet.setColumnWidth(7, 20);
    sheet.setColumnWidth(9, 26);
  }

  void _writeCell(
    Sheet sheet,
    int row,
    int column,
    String value, {
    bool bold = false,
    double fontSize = 11,
    String bgHex = '#FFFFFF',
    String fgHex = '#212121',
  }) {
    final cell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row),
    );
    cell.value = TextCellValue(value);
    cell.cellStyle = CellStyle(
      bold: bold,
      fontSize: fontSize.round(),
      backgroundColorHex: ExcelColor.fromHexString(bgHex),
      fontColorHex: ExcelColor.fromHexString(fgHex),
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
      leftBorder: Border(borderStyle: BorderStyle.Thin),
      rightBorder: Border(borderStyle: BorderStyle.Thin),
      topBorder: Border(borderStyle: BorderStyle.Thin),
      bottomBorder: Border(borderStyle: BorderStyle.Thin),
    );
  }

  String _getPeakDay(List<Event> events) {
    if (events.isEmpty) {
      return '--';
    }
    final counts = <int, int>{};
    for (final event in events) {
      counts[event.startTime.day] = (counts[event.startTime.day] ?? 0) + 1;
    }
    final peak = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return '${peak.key}${_ordinalSuffix(peak.key)} (${peak.value} events)';
  }

  String _getBusiestRange(List<Event> events) {
    if (events.isEmpty) {
      return '--';
    }
    final morning =
        events.where((event) => event.startTime.hour >= 9 && event.startTime.hour < 12).length;
    final afternoon = events
        .where((event) => event.startTime.hour >= 12 && event.startTime.hour < 17)
        .length;
    final evening = events.where((event) => event.startTime.hour >= 17).length;

    if (morning >= afternoon && morning >= evening) {
      return '9 AM - 12 PM (Morning)';
    }
    if (afternoon >= evening) {
      return '12 PM - 5 PM (Afternoon)';
    }
    return '5 PM - 9 PM (Evening)';
  }

  String _generateSummaryText(List<Event> events, DateTime month) {
    final monthLabel = DateFormat('MMMM yyyy').format(month);
    if (events.isEmpty) {
      return '$monthLabel had no scheduled events.';
    }
    final peak = _getPeakDay(events);
    final busiestRange = _getBusiestRange(events);
    final online = events.where((event) => event.eventType == 'online').length;
    final inPerson = events.length - online;
    return '$monthLabel contained ${events.length} events with peak activity on '
        '$peak. Busiest time range: $busiestRange. '
        '$online online, $inPerson in-person.';
  }

  String _ordinalSuffix(int day) {
    final mod100 = day % 100;
    if (mod100 >= 11 && mod100 <= 13) {
      return 'th';
    }
    return switch (day % 10) {
      1 => 'st',
      2 => 'nd',
      3 => 'rd',
      _ => 'th',
    };
  }

  String _csv(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }
}
