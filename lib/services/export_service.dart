import 'dart:io';

import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../data/trip.dart';

/// Builds and shares CSV/PDF exports of a trip list. Both formats are
/// generated on-device and handed to the OS share sheet -- nothing is
/// uploaded anywhere.
class ExportService {
  static final DateFormat _dateFmt = DateFormat.yMd();
  static final DateFormat _timeFmt = DateFormat.jm();

  static String _locationLabel(String? address, double lat, double lng) {
    if (address != null && address.isNotEmpty) return address;
    return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
  }

  static Future<void> shareCsv(List<Trip> trips) async {
    final rows = <List<dynamic>>[
      [
        'Date',
        'Start time',
        'End time',
        'Start location',
        'End location',
        'Distance (km)',
        'Category',
        'Type',
        'Notes',
      ],
      for (final trip in trips)
        [
          _dateFmt.format(trip.startTime),
          _timeFmt.format(trip.startTime),
          trip.endTime == null ? '' : _timeFmt.format(trip.endTime!),
          _locationLabel(trip.startAddress, trip.startLat, trip.startLng),
          _locationLabel(trip.endAddress, trip.endLat, trip.endLng),
          trip.distanceKm.toStringAsFixed(2),
          trip.category.label,
          trip.autoDetected ? 'Auto' : 'Manual',
          trip.notes ?? '',
        ],
    ];

    final content = csv.encode(rows);
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/mileage_trips_${DateTime.now().millisecondsSinceEpoch}.csv',
    );
    await file.writeAsString(content);

    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], subject: 'Mileage log export'),
    );
  }

  static Future<void> sharePdf(List<Trip> trips) async {
    final businessKm = trips
        .where((t) => t.category == TripCategory.business)
        .fold<double>(0, (sum, t) => sum + t.distanceKm);
    final personalKm = trips
        .where((t) => t.category == TripCategory.personal)
        .fold<double>(0, (sum, t) => sum + t.distanceKm);

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Mileage log',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              'Generated ${_dateFmt.format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 12),
          ],
        ),
        build: (context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _summaryTile('Business', businessKm),
              _summaryTile('Personal', personalKm),
              _summaryTile('Trips', trips.length.toDouble(), isCount: true),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 9,
            ),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignment: pw.Alignment.centerLeft,
            headers: ['Date', 'Start', 'End', 'From', 'To', 'Km', 'Category'],
            data: [
              for (final trip in trips)
                [
                  _dateFmt.format(trip.startTime),
                  _timeFmt.format(trip.startTime),
                  trip.endTime == null ? '' : _timeFmt.format(trip.endTime!),
                  _locationLabel(
                    trip.startAddress,
                    trip.startLat,
                    trip.startLng,
                  ),
                  _locationLabel(trip.endAddress, trip.endLat, trip.endLng),
                  trip.distanceKm.toStringAsFixed(1),
                  trip.category.label,
                ],
            ],
          ),
        ],
      ),
    );

    final bytes = await doc.save();
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'mileage_log_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  static pw.Widget _summaryTile(
    String label,
    double value, {
    bool isCount = false,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label.toUpperCase(),
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
        pw.Text(
          isCount ? value.toInt().toString() : '${value.toStringAsFixed(1)} km',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
      ],
    );
  }

  /// A report styled for handing to an accountant or attaching to a tax
  /// return: period-covered line, a business-only trip table with a
  /// "purpose/notes" column, a disclaimer about what the report is (and
  /// isn't), and a prepared-by/date signature line. [trips] should already
  /// be filtered to business trips -- this method doesn't filter by
  /// category itself, so it can also be reused for an all-categories
  /// audit trail if ever needed.
  static Future<void> shareBusinessTaxReportPdf(
    List<Trip> trips, {
    required String periodLabel,
  }) async {
    final totalKm = trips.fold<double>(0, (sum, t) => sum + t.distanceKm);

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) {
          if (context.pageNumber > 1) return pw.SizedBox();
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Business Mileage Report',
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Period: $periodLabel',
                style: const pw.TextStyle(fontSize: 11),
              ),
              pw.Text(
                'Generated ${_dateFmt.format(DateTime.now())}',
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey700,
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Divider(),
            ],
          );
        },
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Generated by Mileage Tracker from on-device GPS trip records.',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
            pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ],
        ),
        build: (context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _summaryTile('Total business distance', totalKm),
              _summaryTile(
                'Business trips',
                trips.length.toDouble(),
                isCount: true,
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 9,
            ),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignment: pw.Alignment.centerLeft,
            headers: [
              'Date',
              'Start',
              'End',
              'From',
              'To',
              'Km',
              'Purpose / notes',
            ],
            data: [
              for (final trip in trips)
                [
                  _dateFmt.format(trip.startTime),
                  _timeFmt.format(trip.startTime),
                  trip.endTime == null ? '' : _timeFmt.format(trip.endTime!),
                  _locationLabel(
                    trip.startAddress,
                    trip.startLat,
                    trip.startLng,
                  ),
                  _locationLabel(trip.endAddress, trip.endLat, trip.endLng),
                  trip.distanceKm.toStringAsFixed(1),
                  trip.notes ?? '',
                ],
            ],
          ),
          pw.SizedBox(height: 32),
          pw.Text(
            'This report is a self-reported record of business trips, generated from GPS data logged on the '
            "taxpayer's device. It has not been reviewed by a tax professional or verified against any other "
            'record. Retain it together with any other documentation your tax authority requires to substantiate '
            'business use of a vehicle.',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 32),
          pw.Row(
            children: [
              pw.Expanded(child: _signatureLine('Prepared by')),
              pw.SizedBox(width: 32),
              pw.Expanded(child: _signatureLine('Date')),
            ],
          ),
        ],
      ),
    );

    final bytes = await doc.save();
    await Printing.sharePdf(
      bytes: bytes,
      filename:
          'business_mileage_tax_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  static pw.Widget _signatureLine(String label) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          height: 24,
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400)),
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
      ],
    );
  }
}
