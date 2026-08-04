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
}
