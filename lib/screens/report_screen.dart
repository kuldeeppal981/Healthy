import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../services/report.dart';
import '../services/report_pdf.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/share_card.dart';
import '../widgets/ui_kit.dart';
import '../services/units.dart';

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
            Text(label, style: TextStyle(color: AppColors.muted, fontSize: 12)),
          ],
        ),
      );

  static const _mn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  /// Last 4 months as tabs, newest on the right.
  Widget _monthTabs() {
    final n = DateTime.now();
    final months = [for (var i = 3; i >= 0; i--) DateTime(n.year, n.month - i)];
    return Row(
      children: [
        for (final m in months)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: ChoiceChip(
                showCheckmark: false,
                label: SizedBox(
                    width: double.infinity,
                    child: Text(_mn[m.month - 1], textAlign: TextAlign.center)),
                selected: m.year == _month.year && m.month == _month.month,
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: (m.year == _month.year && m.month == _month.month)
                        ? AppColors.onAccent
                        : AppColors.ink),
                onSelected: (_) => setState(() => _month = m),
              ),
            ),
          ),
      ],
    );
  }

  /// One bar per day of the month: calories eaten, with the goal as a line.
  Widget _kcalChart(AppState s, MonthReport r) {
    final days = <double>[
      for (var d = 1; d <= r.daysInMonth; d++)
        s.entriesOn(DateTime(_month.year, _month.month, d)).fold(0.0, (a, e) => a + e.kcal)
    ];
    final target = s.kcalTarget.toDouble();
    final top = [target * 1.25, ...days].reduce((a, b) => a > b ? a : b);
    const h = 110.0;
    final anyLogged = days.any((v) => v > 0);
    return AppCard(
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Calories each day', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 10),
          SizedBox(
            height: h,
            child: Stack(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final v in days)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 0.7),
                          child: Container(
                            height: top <= 0 ? 0 : (v / top * h).clamp(0.0, h),
                            decoration: BoxDecoration(
                              color: v > target ? AppColors.warnInk : AppColors.primaryLight,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: top <= 0 ? 0 : (target / top * h).clamp(0.0, h),
                  child: Container(height: 1.5, color: AppColors.muted.withOpacity(0.6)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('1', style: TextStyle(fontSize: 11, color: AppColors.muted)),
              Text('${r.daysInMonth}', style: TextStyle(fontSize: 11, color: AppColors.muted)),
            ],
          ),
          Text(
              anyLogged
                  ? 'Line is your goal (${s.kcalTarget} kcal). Darker bars are days over the goal.'
                  : 'No food logged this month.',
              style: TextStyle(fontSize: 12, color: AppColors.muted)),
        ],
      ),
    );
  }

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
          const SizedBox(height: 4),
          _monthTabs(),
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
                wc == null ? '-' : Units.instance.weightChange(wc),
                'Weight change',
              ),
              _tile('${r.loggedDays} / ${r.daysInMonth}', 'Days food logged'),
              _tile('${r.volumeKg.round()} kg', 'Total lifted'),
            ],
          ),
          const SizedBox(height: 16),
          _kcalChart(s, r),
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
