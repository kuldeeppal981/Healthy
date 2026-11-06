import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/exercise_library.dart';
import '../services/form_ai.dart';
import '../services/pose_math.dart';
import 'live_form_screen.dart';
import '../theme.dart';
import '../widgets/ai_wait.dart';
import '../widgets/ui_kit.dart';

/// Take a photo while doing an exercise and get simple form tips, with a
/// skeleton drawn on the photo and the problem joints marked in red.
/// General guidance from one photo, not medical advice.
class FormCheckScreen extends StatefulWidget {
  final String exercise;
  const FormCheckScreen({super.key, required this.exercise});

  @override
  State<FormCheckScreen> createState() => _FormCheckScreenState();
}

class _FormCheckScreenState extends State<FormCheckScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _busy = false;
  int? _size;
  String? _error;
  File? _file;
  double _aspect = 3 / 4;
  FormResult? _result;

  Future<void> _go(ImageSource source) async {
    setState(() => _error = null);
    try {
      final f = await _picker.pickImage(source: source, maxWidth: 1400, imageQuality: 80);
      if (f == null) return;
      setState(() {
        _busy = true;
        _result = null;
        _file = File(f.path);
      });
      final bytes = await f.readAsBytes();
      setState(() => _size = bytes.length);
      final img = await decodeImageFromList(bytes);
      final ui.Image decoded = img;
      _aspect = decoded.width / decoded.height;
      final r = await FormAi.check(widget.exercise, bytes);
      if (!mounted) return;
      setState(() => _result = r);
      Haptic.done();
    } on FormAiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not open the camera or photo. Allow permission and try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Color _sev(String s) => switch (s) {
        'high' => AppColors.danger,
        'medium' => const Color(0xFFF59E0B),
        _ => AppColors.primary,
      };

  @override
  Widget build(BuildContext context) {
    final info = findExercise(widget.exercise);
    final r = _result;
    return Scaffold(
      appBar: AppBar(title: Text('Form check: ${widget.exercise}')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('For a good result',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                  '1. Ask a friend or prop your phone at hip height, a few steps away.\n'
                  '2. Show your whole body from the side.\n'
                  '3. Take the photo in the hardest position of the move.',
                  style: TextStyle(color: AppColors.muted, height: 1.4),
                ),
                if (info != null && info.mistakes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Common mistake: ${info.mistakes.first}',
                      style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.4)),
                ],
              ],
            ),
          ),
          if (ruleFor(widget.exercise) != null) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => LiveFormScreen(rule: ruleFor(widget.exercise)!),
              )),
              icon: const Icon(Icons.videocam_outlined),
              label: const Text('Live camera analysis (beta)'),
            ),
            const SizedBox(height: 4),
            Text(
                'Skeleton, joint angles, rep count and range of motion, on your phone. Or use a single photo below.',
                style: TextStyle(color: AppColors.muted, fontSize: 12)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : () => _go(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Take photo'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _go(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Gallery'),
                ),
              ),
            ],
          ),
          if (_busy) ...[
            const SizedBox(height: 20),
            AiWaitCard(doing: 'Checking your form', sizeBytes: _size),
          ],
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(_error!, style: TextStyle(color: AppColors.danger)),
          ],
          if (_file != null) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: AspectRatio(
                aspectRatio: _aspect,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(_file!, fit: BoxFit.cover),
                    if (r != null && r.visible)
                      CustomPaint(painter: _SkeletonPainter(r)),
                  ],
                ),
              ),
            ),
          ],
          if (r != null) ...[
            const SizedBox(height: 14),
            if (!r.visible)
              AppCard(
                child: Text(
                  r.summary.isEmpty
                      ? 'I could not see your whole body. Step back and try again.'
                      : r.summary,
                  style: const TextStyle(height: 1.4),
                ),
              )
            else ...[
              AppCard(
                child: Text(r.summary, style: const TextStyle(fontSize: 15, height: 1.4)),
              ),
              if (r.good.isNotEmpty) ...[
                const SizedBox(height: 10),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Looks good',
                          style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.safe)),
                      const SizedBox(height: 6),
                      for (final g in r.good)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.check_circle, size: 16, color: AppColors.safe),
                              const SizedBox(width: 8),
                              Expanded(child: Text(g)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              for (final i in r.issues) ...[
                const SizedBox(height: 10),
                AppCard(
                  borderColor: _sev(i.severity),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(i.area,
                          style: TextStyle(fontWeight: FontWeight.w800, color: _sev(i.severity))),
                      const SizedBox(height: 4),
                      Text(i.problem, style: const TextStyle(height: 1.35)),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.lightbulb_outline, size: 16, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Expanded(
                              child: Text(i.fix,
                                  style: TextStyle(
                                      color: AppColors.primary, fontWeight: FontWeight.w600))),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
            const SizedBox(height: 14),
            Text(
              'This is general guidance from one photo, not medical advice. The AI can be wrong. If something hurts, stop and ask a trainer or doctor. Uses 1 of your daily AI requests.',
              style: TextStyle(color: AppColors.muted, fontSize: 11, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

/// Draws the body lines the AI found and marks problem joints in red.
class _SkeletonPainter extends CustomPainter {
  final FormResult r;
  _SkeletonPainter(this.r);

  static const _bones = [
    ['head', 'neck'],
    ['neck', 'l_shoulder'],
    ['neck', 'r_shoulder'],
    ['l_shoulder', 'l_elbow'],
    ['l_elbow', 'l_wrist'],
    ['r_shoulder', 'r_elbow'],
    ['r_elbow', 'r_wrist'],
    ['l_shoulder', 'l_hip'],
    ['r_shoulder', 'r_hip'],
    ['l_hip', 'r_hip'],
    ['l_hip', 'l_knee'],
    ['l_knee', 'l_ankle'],
    ['r_hip', 'r_knee'],
    ['r_knee', 'r_ankle'],
  ];

  Offset? _pt(String k, Size size) {
    final v = r.landmarks[k];
    if (v == null) return null;
    return Offset(v[0] * size.width, v[1] * size.height);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = const Color(0xFF22C55E)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (final b in _bones) {
      final a = _pt(b[0], size);
      final c = _pt(b[1], size);
      if (a == null || c == null) continue;
      final bad = r.problemJoints.contains(b[0]) && r.problemJoints.contains(b[1]);
      line.color = bad ? const Color(0xFFEF4444) : const Color(0xFF22C55E);
      canvas.drawLine(a, c, line);
    }
    for (final e in r.landmarks.keys) {
      final p = _pt(e, size);
      if (p == null) continue;
      final bad = r.problemJoints.contains(e);
      canvas.drawCircle(p, bad ? 9 : 5, Paint()..color = Colors.white);
      canvas.drawCircle(
          p, bad ? 7 : 3.5, Paint()..color = bad ? const Color(0xFFEF4444) : const Color(0xFF22C55E));
    }
    // A dashed vertical guide through the ankles/hips to see leaning.
    final base = _pt('l_ankle', size) ?? _pt('r_ankle', size);
    if (base != null) {
      final dash = Paint()
        ..color = Colors.white70
        ..strokeWidth = 1.5;
      for (var y = 0.0; y < base.dy; y += 12) {
        canvas.drawLine(Offset(base.dx, y), Offset(base.dx, y + 6), dash);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SkeletonPainter old) => old.r != r;
}
