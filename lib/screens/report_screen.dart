import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../services/report.dart';
import '../services/report_pdf.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/share_card.dart';
import '../widgets/ui_kit.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  bool _busy = false;

  bool get _isCurrent {
    final n = DateTime.now();
    return _month.year == n.year && _month.month == n.month;
  }

  void _shift(int d) =>
      setState(() => _month = DateTime(_month.year, _month.month + d));

  Future<void> _pdf(MonthReport r) async {
    setState(() => _busy = true);
    try {
      final bytes = await buildReportPdf(r);
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'Healthy-report-${_month.year}-${_month.month.toString().padLeft(2, '0')}.pdf',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not make the PDF. Try again.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _tile(String value, String label, {Color? color}) => AppCard(
        radius: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: color ?? AppColors.primary)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final r = MonthReport.build(s, _month);
    final wc = r.weightChange;
    return Scaffold(
      appBar: AppBar(title: const Text('Monthly report')),
      body: AppBackground(
       child: ListView(
        padding: Space.pagePadding,
        children: [
          Row(
            children: [
              IconButton(onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left)),
              Expanded(
                child: Text(r.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              ),
              IconButton(
                onPressed: _isCurrent ? null : () => _shift(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.7,
            children: [
              _tile('${r.workouts}', 'Total workouts'),
              _tile('${r.avgKcal.round()} kcal', 'Average daily calories'),
              _tile('${(r.proteinConsistency * 100).round()}%',
                  'Protein target hit (${r.proteinDays} of ${r.loggedDays} days)'),
              _tile(
                wc == null ? '-' : '${wc > 0 ? '+' : ''}${wc.toStringAsFixed(1)} kg',
                'Weight change',
              ),
              _tile('${r.loggedDays} / ${r.daysInMonth}', 'Days food logged'),
              _tile('${r.volumeKg.round()} kg', 'Total lifted'),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Personal records',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (r.prs.isEmpty)
            AppCard(
              child: Row(
                children: [
                  Icon(Icons.fitness_center, color: AppColors.primary),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No lifts logged this month. Log kg in your workouts to track records.',
                      style: TextStyle(color: AppColors.muted, height: 1.4),
                    ),
                  ),
                ],
              ),
            )
          else
            for (final p in r.prs)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  radius: 14,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Icon(p.isNew ? Icons.emoji_events : Icons.fitness_center,
                          color: p.isNew ? AppColors.ring : AppColors.muted),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(p.exercise,
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      Text(
                        '${p.kg == p.kg.roundToDouble() ? p.kg.round() : p.kg} kg x ${p.reps}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (p.isNew)
                        const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Text('New PR',
                              style: TextStyle(
                                  color: AppColors.ring,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12)),
                        ),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: 16),
          GradientButton(
            onPressed: _busy ? null : () => _pdf(r),
            icon: Icons.picture_as_pdf_outlined,
            label: _busy ? 'Making PDF...' : 'Download PDF report',
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => showShareCard(context),
            icon: const Icon(Icons.share_outlined),
            label: const Text('Share progress card'),
          ),
        ],
       ),
      ),
    );
  }
}
