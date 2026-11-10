import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../services/pose_math.dart';
import '../services/voice_coach.dart';
import '../theme.dart';
import '../widgets/ui_kit.dart';

/// Live form analysis (beta): camera + on-device pose model. Draws a skeleton,
/// measures joint angles, counts reps, estimates range of motion and gives
/// exercise-specific tips. Works only on what the camera can see; when the
/// view is poor it says the result is uncertain. General guidance, not medical advice.
class LiveFormScreen extends StatefulWidget {
  final FormRule rule;
  const LiveFormScreen({super.key, required this.rule});

  @override
  State<LiveFormScreen> createState() => _LiveFormScreenState();
}

class _LiveFormScreenState extends State<LiveFormScreen> {
  CameraController? _cam;
  List<CameraDescription> _cams = [];
  int _camIndex = 0;
  final PoseDetector _detector =
      PoseDetector(options: PoseDetectorOptions(mode: PoseDetectionMode.stream));
  late RepTracker _tracker;
  CamView _view = CamView.side;
  bool _busy = false;
  int _frame = 0;
  String? _error;
  bool _started = false;

  Pts _pts = {};
  Size _imageSize = const Size(480, 640);
  bool _mirror = false;
  FrameInfo _info = const FrameInfo(null, 'Step into the frame', '', {});
  int _lastReps = 0;
  final VoiceCoach _voice = VoiceCoach();

  @override
  void initState() {
    super.initState();
    _tracker = RepTracker(widget.rule, _view);
    _voice.init().then((_) {
      if (mounted) setState(() {});
    });
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _init();
  }

  Future<void> _init() async {
    try {
      _cams = await availableCameras();
      if (_cams.isEmpty) {
        setState(() => _error = 'No camera found on this phone.');
        return;
      }
      final back = _cams.indexWhere((c) => c.lensDirection == CameraLensDirection.back);
      _camIndex = back >= 0 ? back : 0;
      await _open();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not open the camera. Allow camera permission and try again.');
      }
    }
  }

  Future<void> _open() async {
    final old = _cam;
    if (old != null) {
      try {
        await old.stopImageStream();
      } catch (_) {}
      await old.dispose();
    }
    final desc = _cams[_camIndex];
    final c = CameraController(
      desc,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );
    await c.initialize();
    if (!mounted) {
      await c.dispose();
      return;
    }
    _mirror = desc.lensDirection == CameraLensDirection.front;
    setState(() => _cam = c);
    await c.startImageStream(_onFrame);
  }

  InputImage? _toInput(CameraImage img) {
    final cam = _cams[_camIndex];
    final rotation = InputImageRotationValue.fromRawValue(cam.sensorOrientation);
    final format = InputImageFormatValue.fromRawValue(img.format.raw);
    if (rotation == null || format != InputImageFormat.nv21 || img.planes.length != 1) {
      return null;
    }
    final plane = img.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(img.width.toDouble(), img.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  Future<void> _onFrame(CameraImage img) async {
    if (_busy || !_started) return;
    _frame++;
    if (_frame % 2 != 0) return;
    _busy = true;
    try {
      final input = _toInput(img);
      if (input == null) return;
      final poses = await _detector.processImage(input);
      if (!mounted) return;
      if (poses.isEmpty) {
        setState(() {
          _pts = {};
          _info = const FrameInfo(
              null, 'I cannot see a person. Step back so your whole body is in the picture.', '', {});
        });
        return;
      }
      final lm = poses.first.landmarks;
      P? g(PoseLandmarkType t) {
        final l = lm[t];
        return l == null ? null : P(l.x, l.y, l.likelihood);
      }

      final map = <String, P>{};
      void put(String k, PoseLandmarkType t) {
        final p = g(t);
        if (p != null) map[k] = p;
      }

      put('nose', PoseLandmarkType.nose);
      put('l_shoulder', PoseLandmarkType.leftShoulder);
      put('r_shoulder', PoseLandmarkType.rightShoulder);
      put('l_elbow', PoseLandmarkType.leftElbow);
      put('r_elbow', PoseLandmarkType.rightElbow);
      put('l_wrist', PoseLandmarkType.leftWrist);
      put('r_wrist', PoseLandmarkType.rightWrist);
      put('l_hip', PoseLandmarkType.leftHip);
      put('r_hip', PoseLandmarkType.rightHip);
      put('l_knee', PoseLandmarkType.leftKnee);
      put('r_knee', PoseLandmarkType.rightKnee);
      put('l_ankle', PoseLandmarkType.leftAnkle);
      put('r_ankle', PoseLandmarkType.rightAnkle);

      // Upright image size: the camera frame is landscape, the phone is portrait.
      final size = Size(img.height.toDouble(), img.width.toDouble());
      final info = _tracker.update(map);
      final reps = _tracker.reps;
      setState(() {
        _pts = map;
        _imageSize = size;
        _info = info;
        if (reps != _lastReps) {
          _lastReps = reps;
          Haptic.done();
          if (reps > 0) _voice.rep(reps, _tracker.results.last.notes);
        } else {
          _voice.live(info.cue, info.angle == null);
        }
      });
    } catch (_) {
      // Skip a bad frame.
    } finally {
      _busy = false;
    }
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    final c = _cam;
    if (c != null) {
      c.stopImageStream().catchError((_) {}).whenComplete(() => c.dispose());
    }
    _voice.stop();
    _detector.close();
    super.dispose();
  }

  void _setView(CamView v) {
    setState(() {
      _view = v;
      _tracker = RepTracker(widget.rule, v);
      _lastReps = 0;
    });
  }

  void _summary() {
    final r = _tracker.results;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            children: [
              Text('${r.length} reps of ${widget.rule.title}',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink)),
              const SizedBox(height: 6),
              if (r.isEmpty)
                Text('No full reps counted. Make sure your whole body is visible and move through the full range.',
                    style: TextStyle(color: AppColors.muted)),
              for (final x in r)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(x.clean ? Icons.check_circle : Icons.info_outline,
                          size: 18, color: x.clean ? AppColors.safe : const Color(0xFFF59E0B)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                'Rep ${x.number}: ${widget.rule.jointLabel} ${x.minAngle.round()}° to ${x.maxAngle.round()}°',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700, color: AppColors.ink)),
                            for (final n in x.notes)
                              Text(n, style: TextStyle(color: AppColors.muted, fontSize: 12)),
                            if (x.clean)
                              Text('Looks good from this camera view.',
                                  style: TextStyle(color: AppColors.muted, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                  'These are estimates from one camera view. Depth and angles can be off if the phone is tilted or part of your body is hidden. General guidance, not medical advice. Stop if something hurts.',
                  style: TextStyle(color: AppColors.muted, fontSize: 11, height: 1.4)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _cam;
    final hint = _view == CamView.side ? widget.rule.sideHint : widget.rule.frontHint;
    return Scaffold(
      appBar: AppBar(
        title: Text('Live form: ${widget.rule.title}'),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await _voice.setMode(_voice.next());
              if (mounted) setState(() {});
            },
            icon: Icon(_voice.mode == 'off' ? Icons.volume_off_outlined : Icons.volume_up_outlined),
            label: Text(_voice.label),
          ),
          if (_cams.length > 1)
            IconButton(
              tooltip: 'Switch camera',
              icon: const Icon(Icons.cameraswitch_outlined),
              onPressed: () async {
                _camIndex = (_camIndex + 1) % _cams.length;
                try {
                  await _open();
                } catch (_) {}
              },
            ),
        ],
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, textAlign: TextAlign.center),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<CamView>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: CamView.side, label: Text('Side view')),
                      ButtonSegment(value: CamView.front, label: Text('Front / rear view')),
                    ],
                    selected: {_view},
                    onSelectionChanged: (v) => _setView(v.first),
                  ),
                ),
                const SizedBox(height: 8),
                Text(hint, style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.35)),
                const SizedBox(height: 10),
                if (c != null && c.value.isInitialized)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: AspectRatio(
                      aspectRatio: 1 / c.value.aspectRatio,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CameraPreview(c),
                          CustomPaint(
                            painter: _PosePainter(_pts, _imageSize, _mirror, _info.flagged),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 300, child: Center(child: CircularProgressIndicator())),
                const SizedBox(height: 12),
                if (_info.uncertain != null)
                  AppCard(
                    color: AppColors.warnBg,
                    borderColor: AppColors.warnBg,
                    radius: 14,
                    child: Text('Uncertain: ${_info.uncertain}',
                        style: TextStyle(color: AppColors.warnInk, fontSize: 13, height: 1.35)),
                  )
                else
                  AppCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${_tracker.reps}',
                                  style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
                              Text('reps', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  _info.angle == null ? '--' : '${_info.angle!.round()}°',
                                  style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
                              Text(widget.rule.jointLabel,
                                  style: TextStyle(color: AppColors.muted, fontSize: 12)),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(_info.cue,
                              style: TextStyle(
                                  color: AppColors.primary, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: () => setState(() {
                          _started = !_started;
                          if (_started) {
                            _tracker.reset();
                            _lastReps = 0;
                          }
                        }),
                        child: Text(_started ? 'Stop analysing' : 'Start analysing'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: _tracker.reps == 0 ? null : _summary,
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
                      child: const Text('Summary'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                    'Runs on your phone. Nothing is recorded or uploaded. Beta: angles are estimates and depend on the camera view.',
                    style: TextStyle(color: AppColors.muted, fontSize: 11)),
              ],
            ),
    );
  }
}

class _PosePainter extends CustomPainter {
  final Pts pts;
  final Size image;
  final bool mirror;
  final Set<String> flagged;
  _PosePainter(this.pts, this.image, this.mirror, this.flagged);

  static const _bones = [
    ['l_shoulder', 'r_shoulder'],
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

  Offset _map(P p, Size s) {
    var x = p.x * s.width / image.width;
    final y = p.y * s.height / image.height;
    if (mirror) x = s.width - x;
    return Offset(x, y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    for (final b in _bones) {
      final a = pts[b[0]], c = pts[b[1]];
      if (a == null || c == null || a.c < 0.5 || c.c < 0.5) continue;
      final bad = flagged.contains(b[0]) && flagged.contains(b[1]);
      line.color = bad ? const Color(0xFFEF4444) : const Color(0xFF22C55E);
      canvas.drawLine(_map(a, size), _map(c, size), line);
    }
    pts.forEach((k, p) {
      if (p.c < 0.5 || k == 'nose') return;
      final bad = flagged.contains(k);
      canvas.drawCircle(_map(p, size), bad ? 8 : 5, Paint()..color = Colors.white);
      canvas.drawCircle(_map(p, size), bad ? 6 : 3.5,
          Paint()..color = bad ? const Color(0xFFEF4444) : const Color(0xFF22C55E));
    });
  }

  @override
  bool shouldRepaint(covariant _PosePainter old) => true;
}
