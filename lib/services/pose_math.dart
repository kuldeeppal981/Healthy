import 'dart:math' as math;

/// A body point from the pose model: pixel position and how sure the model is.
class P {
  final double x;
  final double y;
  final double c; // confidence 0..1
  const P(this.x, this.y, this.c);
}

typedef Pts = Map<String, P>;

/// Angle at [b] between the lines b->a and b->c, in degrees (0..180).
double angleDeg(P a, P b, P c) {
  final v1x = a.x - b.x, v1y = a.y - b.y;
  final v2x = c.x - b.x, v2y = c.y - b.y;
  final n1 = math.sqrt(v1x * v1x + v1y * v1y);
  final n2 = math.sqrt(v2x * v2x + v2y * v2y);
  if (n1 == 0 || n2 == 0) return 180;
  var cosv = (v1x * v2x + v1y * v2y) / (n1 * n2);
  if (cosv > 1) cosv = 1;
  if (cosv < -1) cosv = -1;
  return math.acos(cosv) * 180 / math.pi;
}

/// How far the line from [low] to [high] leans from vertical, in degrees.
double leanDeg(P low, P high) {
  final dx = (high.x - low.x).abs();
  final dy = (high.y - low.y).abs();
  return math.atan2(dx, dy == 0 ? 0.0001 : dy) * 180 / math.pi;
}

double dist(P a, P b) {
  final dx = a.x - b.x, dy = a.y - b.y;
  return math.sqrt(dx * dx + dy * dy);
}

enum CamView { front, side }

/// What the user is doing: one rule set per supported exercise.
class FormRule {
  final String id; // squat | pushup | curl | lunge
  final String title;
  final double downAngle; // below this the rep is "down"
  final double upAngle; // above this the rep is finished
  final String jointLabel; // "Knee" or "Elbow"
  final String sideHint;
  final String frontHint;

  /// Which three body points make the main angle: arm (shoulder, elbow, wrist),
  /// leg (hip, knee, ankle), hip (shoulder, hip, knee) or raise (hip, shoulder, elbow).
  final String limb;

  /// True when the move starts at a small angle and grows (lateral raise): the
  /// angle is turned around (180 minus angle) so the rep counter works the same.
  final bool flip;

  /// Extra tip shown after a rep when the main angle did not reach this value.
  final double? fullAngle;
  final String? fullNote;

  /// Hold moves (plank): measured in seconds of good body line, not reps.
  final bool hold;

  /// Whether a rep that is too fast gets a "slow down" tip (off for jumping moves).
  final bool tempo;

  const FormRule(this.id, this.title, this.downAngle, this.upAngle, this.jointLabel,
      this.sideHint, this.frontHint,
      {this.limb = 'arm',
      this.flip = false,
      this.fullAngle,
      this.fullNote,
      this.hold = false,
      this.tempo = true});

  List<String> get points => switch (limb) {
        'leg' => const ['hip', 'knee', 'ankle'],
        'hip' => const ['shoulder', 'hip', 'knee'],
        'raise' => const ['hip', 'shoulder', 'elbow'],
        _ => const ['shoulder', 'elbow', 'wrist'],
      };
}

const formRules = <FormRule>[
  FormRule('squat', 'Squat', 110, 160, 'Knee',
      'Side view: shows depth and how far your chest leans forward. Put the phone at hip height, 2 to 3 m away, whole body in frame.',
      'Front view: shows knees caving in and weight shifting. Phone at hip height, 2 to 3 m away.',
      limb: 'leg'),
  FormRule('lunge', 'Lunge', 110, 160, 'Front knee',
      'Side view: shows depth and torso lean. Whole body in frame.',
      'Front view: shows knee tracking. Whole body in frame.',
      limb: 'leg'),
  FormRule('pushup', 'Push-up', 95, 155, 'Elbow',
      'Side view only: shows depth and whether your hips sag or pike. Phone on the floor, 2 m away.',
      'Side view works best for push-ups.'),
  FormRule('curl', 'Biceps curl', 55, 140, 'Elbow',
      'Side view: shows if the elbow swings forward. Whole upper body in frame.',
      'Front view: shows full range and left/right difference.'),
  FormRule('arm_press', 'Pressing move', 100, 150, 'Elbow',
      'Side view: counts reps from your elbow angle. Show your whole arm and torso.',
      'Front view: shows left/right difference. Show both arms.',
      fullAngle: 95, fullNote: 'Lower a little further for full range, if it feels comfortable.'),
  FormRule('arm_pull', 'Pulling move', 95, 150, 'Elbow',
      'Side view: counts reps from your elbow angle. Show your whole arm and torso.',
      'Rear or front view: shows left/right difference. Show both arms.',
      fullAngle: 90, fullNote: 'Pull a little further for full range, if it feels comfortable.'),
  FormRule('leg', 'Leg move', 110, 160, 'Knee',
      'Side view: counts reps from your knee angle. Show your whole leg.',
      'Front view: shows left/right difference. Show both legs.',
      limb: 'leg', fullAngle: 100, fullNote: 'Bend a little further for full range, if it feels comfortable.'),
  FormRule('hinge', 'Hip hinge', 130, 160, 'Hip',
      'Side view: counts reps from your hip angle. Show shoulder, hip and knee, whole body in frame.',
      'Side view works best for hip hinges.',
      limb: 'hip'),
  FormRule('raise', 'Raise', 105, 150, 'Shoulder',
      'Side or front view: counts reps from how high your arm lifts. Show your whole arm.',
      'Front view: shows left/right difference. Show both arms.',
      limb: 'raise', flip: true, fullAngle: 100, fullNote: 'Lift to about shoulder height.'),
  FormRule('jack', 'Jumping jacks', 105, 150, 'Shoulder',
      'Front view: counts a rep each time your arms go up. Show your whole body.',
      'Front view: counts a rep each time your arms go up. Show your whole body.',
      limb: 'raise', flip: true, tempo: false),
  FormRule('climber', 'Mountain climbers', 120, 160, 'Hip',
      'Side view: counts each knee drive. Show your whole body.',
      'Side view works best.',
      limb: 'hip', tempo: false),
  FormRule('crunch', 'Crunch', 105, 130, 'Hip',
      'Side view, lying down: counts reps from your hip/torso angle. Show shoulder, hip and knee.',
      'Side view works best.',
      limb: 'hip', tempo: false),
  FormRule('legraise', 'Leg raise', 120, 160, 'Hip',
      'Side view, lying down: counts reps from your hip angle. Show shoulder, hip and knee.',
      'Side view works best.',
      limb: 'hip'),
  FormRule('plank', 'Plank hold', 0, 0, 'Body line',
      'Side view on the floor: checks that shoulder, hip and ankle make a straight line. Show your whole body.',
      'Side view works best for planks.',
      limb: 'hip', hold: true),
];

/// Maps a library exercise name to a live rule, or null if not supported.
FormRule? ruleFor(String exercise) {
  final n = exercise.toLowerCase();
  String? id;
  if (n.contains('plank') && !n.contains('chaturanga')) {
    id = 'plank';
  } else if (n.contains('mountain climber')) {
    id = 'climber';
  } else if (n.contains('jumping jack')) {
    id = 'jack';
  } else if (n.contains('crunch')) {
    id = 'crunch';
  } else if (n.contains('leg raise')) {
    id = 'legraise';
  } else if (n.contains('cable fly') || n.contains('rear delt')) {
    id = 'raise';
  } else if (n.contains('garland') || n.contains('malasana') || n.contains('child')) {
    id = null;
  } else if (n.contains('leg press') || n.contains('step-up') || n.contains('leg curl') ||
      n.contains('leg extension')) {
    id = 'leg';
  } else if (n.contains('squat')) {
    id = 'squat';
  } else if (n.contains('lunge')) {
    id = 'lunge';
  } else if (n.contains('push-up') || n.contains('pushup')) {
    id = 'pushup';
  } else if (n.contains('curl')) {
    id = 'curl';
  } else if (n.contains('deadlift') || n.contains('hip thrust') || n.contains('glute bridge')) {
    id = 'hinge';
  } else if (n.contains('lateral raise') || n.contains('front raise')) {
    id = 'raise';
  } else if (n.contains('pulldown') || n.contains('pull-up') || n.contains('row') ||
      n.contains('face pull')) {
    id = 'arm_pull';
  } else if (n.contains('press') || n.contains('dips') || n.contains('triceps')) {
    id = 'arm_press';
  }
  if (id == null) return null;
  for (final r in formRules) {
    if (r.id == id) return r;
  }
  return null;
}

class FrameInfo {
  final double? angle; // main joint angle now
  final String? uncertain; // set when the camera cannot see enough
  final String cue; // short live tip
  final Set<String> flagged; // joint names to colour red
  const FrameInfo(this.angle, this.uncertain, this.cue, this.flagged);
}

class RepResult {
  final int number;
  final double minAngle;
  final double maxAngle;
  final List<String> notes;
  final double seconds;
  const RepResult(this.number, this.minAngle, this.maxAngle, this.notes, {this.seconds = 0});
  bool get clean => notes.isEmpty;
}

/// Counts reps from the main joint angle and checks form at the bottom of
/// each rep. Only judges what the camera can see well; otherwise it says so.
class RepTracker {
  final FormRule rule;
  CamView view;
  RepTracker(this.rule, this.view);

  final List<RepResult> results = [];
  bool _wasTop = false;
  bool _down = false;
  double _min = 999;
  double _max = 0;
  Map<String, double> _bottom = {};
  DateTime _repStart = DateTime.now();
  DateTime? _lastT;
  double holdTotal = 0;
  double holdGood = 0;
  FrameInfo last = const FrameInfo(null, 'Step into the frame', '', {});

  int get reps => results.length;

  void reset() {
    results.clear();
    _wasTop = false;
    _down = false;
    _min = 999;
    _max = 0;
    _bottom = {};
    _lastT = null;
    holdTotal = 0;
    holdGood = 0;
  }

  /// Form score 0 to 100: share of the set that looked clean. Null when too little data.
  int? get score {
    if (rule.hold) {
      if (holdTotal < 3) return null;
      return (100 * holdGood / holdTotal).round();
    }
    if (results.isEmpty) return null;
    var sum = 0.0;
    for (final r in results) {
      sum += (100 - 22 * r.notes.length).clamp(30, 100).toDouble();
    }
    return (sum / results.length).round();
  }

  /// The tip that came up most often, for "fix this next set".
  String? get topIssue {
    final count = <String, int>{};
    final full = <String, String>{};
    for (final r in results) {
      for (final n in r.notes) {
        final k = n.length > 14 ? n.substring(0, 14) : n;
        count[k] = (count[k] ?? 0) + 1;
        full[k] = n;
      }
    }
    if (count.isEmpty) return null;
    final best = count.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return full[best.key];
  }

  FrameInfo _updateHold(Pts p) {
    const needs = ['shoulder', 'hip', 'ankle'];
    final s = _side(p, needs);
    final pts = [for (final n in needs) p['${s}_$n']];
    if (pts.any((x) => !_ok(x))) {
      _lastT = null;
      last = const FrameInfo(null,
          'Cannot see your whole body clearly. Use a side view, check light and that you are fully in frame. Feedback is uncertain until then.',
          '', {});
      return last;
    }
    final sh = p['${s}_shoulder']!, hip = p['${s}_hip']!, ank = p['${s}_ankle']!;
    final body = angleDeg(sh, hip, ank);
    final now = DateTime.now();
    final prev = _lastT;
    if (prev != null) {
      final dt = now.difference(prev).inMilliseconds / 1000.0;
      if (dt < 1) {
        holdTotal += dt;
        if (body >= 165) holdGood += dt;
      }
    }
    _lastT = now;
    var cue = 'Good, hold steady';
    final flagged = <String>{};
    if (body < 165) {
      final dx = ank.x - sh.x;
      final t = dx.abs() < 1 ? 0.5 : (hip.x - sh.x) / dx;
      final lineY = sh.y + t * (ank.y - sh.y);
      if (hip.y > lineY) {
        cue = 'Hips are sagging. Lift your hips and tighten your core';
      } else {
        cue = 'Hips too high. Lower them in line with your shoulders';
      }
      flagged.addAll(['${s}_hip', '${s}_shoulder', '${s}_ankle']);
    }
    last = FrameInfo(body, null, cue, flagged);
    return last;
  }

  static const _minConf = 0.5;

  bool _ok(P? p) => p != null && p.c >= _minConf;

  // Picks the side (left or right) the camera sees better.
  String _side(Pts p, List<String> names) {
    double score(String s) =>
        names.fold(0.0, (a, n) => a + (p['${s}_$n']?.c ?? 0));
    return score('l') >= score('r') ? 'l' : 'r';
  }

  FrameInfo update(Pts p) {
    if (rule.hold) return _updateHold(p);
    final lower = rule.limb == 'leg';
    final needs = rule.id == 'pushup' ? ['shoulder', 'elbow', 'wrist', 'hip'] : rule.points;
    final s = _side(p, needs);
    final pts = [for (final n in needs) p['${s}_$n']];
    if (pts.any((x) => !_ok(x))) {
      final what = lower
          ? 'your legs'
          : (rule.id == 'pushup' || rule.limb == 'hip' ? 'your whole body' : 'your arm');
      last = FrameInfo(null,
          'Cannot see $what clearly. Check the camera angle, light and that your whole body is in frame. Feedback is uncertain until then.',
          '', {});
      return last;
    }

    final names = rule.points;
    final a = p['${s}_${names[0]}']!;
    final b = p['${s}_${names[1]}']!;
    final c = p['${s}_${names[2]}']!;
    final joint = '${s}_${names[1]}';
    final raw = angleDeg(a, b, c);
    // Moves that start small and grow are turned around so one counter fits all.
    final angle = rule.flip ? 180 - raw : raw;

    // --- rep state machine ---
    if (!_down) {
      if (angle >= rule.upAngle) {
        _wasTop = true;
        _max = angle > _max ? angle : _max;
      }
      if (_wasTop && angle < rule.downAngle) {
        _down = true;
        _repStart = DateTime.now();
        _min = angle;
        _bottom = _metrics(p, s);
      }
    } else {
      if (angle < _min) {
        _min = angle;
        _bottom = _metrics(p, s);
      }
      if (angle >= rule.upAngle) {
        final secs = DateTime.now().difference(_repStart).inMilliseconds / 1000.0;
        final notes = _judge(_min, _bottom, secs);
        results.add(RepResult(results.length + 1, rule.flip ? 180 - _min : _min,
            rule.flip ? 180 - angle : angle, notes, seconds: secs));
        _down = false;
        _min = 999;
        _max = angle;
      }
    }

    final flagged = <String>{};
    var cue = _down ? 'Good, now push back up' : 'Ready';
    if (_down) {
      final m = _bottom;
      if (rule.id == 'squat' && (m['lean'] ?? 0) > 60 && view == CamView.side) {
        cue = 'Chest up, you are leaning forward';
        flagged.addAll(['${s}_hip', '${s}_shoulder']);
      }
      if (rule.id == 'pushup' && (m['body'] ?? 180) < 150 && view == CamView.side) {
        cue = 'Keep a straight line from shoulders to ankles';
        flagged.add('${s}_hip');
      }
    }
    last = FrameInfo(raw, null, cue, flagged..add(_down ? joint : ''));
    return last;
  }

  Map<String, double> _metrics(Pts p, String s) {
    final m = <String, double>{};
    final sh = p['${s}_shoulder'], hip = p['${s}_hip'], knee = p['${s}_knee'], ank = p['${s}_ankle'];
    if (_ok(sh) && _ok(hip)) m['lean'] = leanDeg(hip!, sh!);
    if (rule.id == 'pushup' && _ok(sh) && _ok(hip) && _ok(ank)) {
      m['body'] = angleDeg(sh!, hip!, ank!);
    }
    if (view == CamView.front) {
      final lk = p['l_knee'], rk = p['r_knee'], la = p['l_ankle'], ra = p['r_ankle'];
      if (_ok(lk) && _ok(rk) && _ok(la) && _ok(ra)) {
        final ad = dist(la!, ra!);
        if (ad > 0) m['kneeRatio'] = dist(lk!, rk!) / ad;
      }
      final lh = p['l_hip'], rh = p['r_hip'];
      if (_ok(lh) && _ok(rh) && _ok(la) && _ok(ra)) {
        final hipX = (lh!.x + rh!.x) / 2;
        final ankX = (la!.x + ra!.x) / 2;
        final torso = (_ok(p['l_shoulder']) && _ok(lh)) ? dist(p['l_shoulder']!, lh) : 0;
        if (torso > 0) m['sway'] = (hipX - ankX).abs() / torso;
      }
      // Left/right difference of the main joint.
      final n1 = rule.points[0], n2 = rule.points[1], n3 = rule.points[2];
      final l1 = p['l_$n1'], l2 = p['l_$n2'], l3 = p['l_$n3'];
      final r1 = p['r_$n1'], r2 = p['r_$n2'], r3 = p['r_$n3'];
      if (_ok(l1) && _ok(l2) && _ok(l3) && _ok(r1) && _ok(r2) && _ok(r3)) {
        m['asym'] = (angleDeg(l1!, l2!, l3!) - angleDeg(r1!, r2!, r3!)).abs();
      }
    }
    if (rule.id == 'curl' && view == CamView.side) {
      final el = p['${s}_elbow'];
      if (_ok(el) && _ok(hip) && _ok(sh)) {
        final torso = dist(sh!, hip!);
        if (torso > 0) m['elbowDrift'] = (el!.x - hip!.x).abs() / torso;
      }
    }
    return m;
  }

  List<String> _judge(double minAngle, Map<String, double> m, double secs) {
    final notes = <String>[];
    if (rule.tempo && secs > 0 && secs < 1.2) {
      notes.add('Too fast. Slow down and control the movement.');
    }
    final lower = rule.id == 'squat' || rule.id == 'lunge';
    final full = rule.fullAngle;
    if (full != null && rule.fullNote != null) {
      // For turned-around moves the stored minimum is 180 minus the real peak.
      final reached = rule.flip ? 180 - minAngle : minAngle;
      final ok = rule.flip ? reached >= 180 - full : reached <= full;
      if (!ok) notes.add(rule.fullNote!);
    }
    if (rule.limb != 'arm' && rule.id != 'squat' && rule.id != 'lunge' || rule.id == 'arm_press' || rule.id == 'arm_pull') {
      if (view == CamView.front && (m['asym'] ?? 0) > 20) {
        notes.add('Left and right sides differ by ${(m['asym'] ?? 0).round()}°.');
      }
    } else if (lower) {
      if (minAngle > 110) {
        notes.add('Shallow depth (${minAngle.round()}°). Go a little lower if it feels comfortable.');
      }
      if (view == CamView.side && (m['lean'] ?? 0) > 60) {
        notes.add('Leaning forward a lot (${(m['lean'] ?? 0).round()}°). Keep your chest up.');
      }
      if (view == CamView.front) {
        if ((m['kneeRatio'] ?? 1) < 0.75) notes.add('Knees moved inward. Push them out over your toes.');
        if ((m['sway'] ?? 0) > 0.35) notes.add('Weight shifted to one side. Stay centered.');
        if ((m['asym'] ?? 0) > 20) notes.add('Left and right knees bend differently (${(m['asym'] ?? 0).round()}° apart).');
      }
    } else if (rule.id == 'pushup') {
      if (minAngle > 100) notes.add('Shallow (${minAngle.round()}°). Lower your chest closer to the floor.');
      if (view == CamView.side && (m['body'] ?? 180) < 150) {
        notes.add('Body not in a straight line. Tighten your core and glutes.');
      }
    } else if (rule.id == 'curl') {
      if (minAngle > 60) notes.add('Curl higher for full range (${minAngle.round()}°).');
      if (view == CamView.side && (m['elbowDrift'] ?? 0) > 0.3) {
        notes.add('Elbow moved forward. Keep it by your side.');
      }
      if (view == CamView.front && (m['asym'] ?? 0) > 20) {
        notes.add('Left and right arms differ by ${(m['asym'] ?? 0).round()}°.');
      }
    }
    return notes;
  }
}
