import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'report.dart';

String _n(double v, [int d = 0]) => v.toStringAsFixed(d);

/// Builds the monthly report as a one page PDF.
Future<Uint8List> buildReportPdf(MonthReport r, {String? name}) async {
  final doc = pw.Document();
  const purple = PdfColor.fromInt(0xFF6C3CE9);
  const grey = PdfColor.fromInt(0xFF6B6785);

  pw.Widget stat(String value, String label) => pw.Expanded(
        child: pw.Container(
          margin: const pw.EdgeInsets.only(right: 8, bottom: 8),
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: const PdfColor.fromInt(0xFFF4F1FF),
            borderRadius: pw.BorderRadius.circular(10),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(value,
                  style: pw.TextStyle(
                      fontSize: 20, fontWeight: pw.FontWeight.bold, color: purple)),
              pw.SizedBox(height: 2),
              pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: grey)),
            ],
          ),
        ),
      );

  final wc = r.weightChange;
  final weightText = wc == null
      ? 'No data'
      : '${wc > 0 ? '+' : ''}${_n(wc, 1)} kg';

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (_) => [
        pw.Text('Healthy',
            style: pw.TextStyle(
                fontSize: 12, fontWeight: pw.FontWeight.bold, color: purple)),
        pw.Text('Monthly fitness report',
            style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold)),
        pw.Text(name == null ? r.title : '${r.title}  |  $name',
            style: const pw.TextStyle(fontSize: 12, color: grey)),
        pw.SizedBox(height: 18),
        pw.Row(children: [
          stat('${r.workouts}', 'Workouts'),
          stat('${r.totalSets}', 'Sets done'),
          stat('${_n(r.volumeKg)} kg', 'Total lifted'),
        ]),
        pw.Row(children: [
          stat('${r.loggedDays} / ${r.daysInMonth}', 'Days food logged'),
          stat('${_n(r.avgKcal)} kcal', 'Average daily calories'),
          stat('${_n(r.avgProtein)} g', 'Average daily protein'),
        ]),
        pw.Row(children: [
          stat('${_n(r.proteinConsistency * 100)}%',
              'Protein target hit (${r.proteinDays} of ${r.loggedDays} days)'),
          stat(weightText, 'Weight change'),
          stat(r.weightEnd == null ? '-' : '${_n(r.weightEnd!, 1)} kg', 'Latest weight'),
        ]),
        pw.SizedBox(height: 10),
        pw.Text('Targets: ${r.kcalTarget} kcal and ${r.proteinTarget} g protein per day',
            style: const pw.TextStyle(fontSize: 10, color: grey)),
        pw.SizedBox(height: 18),
        pw.Text('Personal records',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        if (r.prs.isEmpty)
          pw.Text('No lifts logged this month.',
              style: const pw.TextStyle(color: grey))
        else
          pw.TableHelper.fromTextArray(
            headers: ['Exercise', 'Best set', 'Status'],
            data: [
              for (final p in r.prs)
                [
                  p.exercise,
                  '${_n(p.kg, p.kg == p.kg.roundToDouble() ? 0 : 1)} kg x ${p.reps}',
                  p.isNew ? 'New PR' : '',
                ],
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            cellStyle: const pw.TextStyle(fontSize: 10),
            headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFEDE6FF)),
            cellAlignment: pw.Alignment.centerLeft,
          ),
        pw.SizedBox(height: 24),
        pw.Text(
          'Calories and protein are worked out from the foods you logged. Estimates only, not medical advice.',
          style: const pw.TextStyle(fontSize: 9, color: grey),
        ),
      ],
    ),
  );
  return doc.save();
}
