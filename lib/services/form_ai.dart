import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

class FormIssue {
  final String area;
  final String problem;
  final String fix;
  final String severity; // low | medium | high
  const FormIssue(this.area, this.problem, this.fix, this.severity);
}

class FormResult {
  final bool visible;
  final String summary;
  final List<String> good;
  final List<FormIssue> issues;

  /// Joint name -> (x, y) as fractions 0..1 of the photo.
  final Map<String, List<double>> landmarks;
  final Set<String> problemJoints;

  const FormResult({
    required this.visible,
    required this.summary,
    required this.good,
    required this.issues,
    required this.landmarks,
    required this.problemJoints,
  });
}

class FormAiException implements Exception {
  final String message;
  FormAiException(this.message);
  @override
  String toString() => message;
}

/// Sends one photo of an exercise to the `coach` edge function (mode "form").
/// Counts as one daily AI request. The AI key stays on the server.
class FormAi {
  static Future<FormResult> check(String exercise, List<int> jpegBytes) async {
    Map<String, dynamic> data;
    try {
      final res = await Supabase.instance.client.functions.invoke('coach', body: {
        'mode': 'form',
        'exercise': exercise,
        'image': base64Encode(jpegBytes),
        'mime': 'image/jpeg',
      });
      data = Map<String, dynamic>.from(res.data as Map);
    } on FunctionException catch (e) {
      final d = e.details;
      throw FormAiException(d is Map && d['message'] != null
          ? d['message'].toString()
          : 'Could not check the photo. Try again.');
    } catch (_) {
      throw FormAiException('No internet or sign-in problem. Try again.');
    }
    final f = data['form'];
    if (f is! Map) throw FormAiException('Could not check the photo. Try again.');

    final lm = <String, List<double>>{};
    final rawLm = f['landmarks'];
    if (rawLm is Map) {
      rawLm.forEach((k, v) {
        if (v is List && v.length == 2 && v[0] is num && v[1] is num) {
          lm[k.toString()] = [(v[0] as num).toDouble(), (v[1] as num).toDouble()];
        }
      });
    }
    final issues = <FormIssue>[];
    final rawIssues = f['issues'];
    if (rawIssues is List) {
      for (final i in rawIssues) {
        if (i is Map) {
          issues.add(FormIssue(
            (i['area'] ?? '').toString(),
            (i['problem'] ?? '').toString(),
            (i['fix'] ?? '').toString(),
            (i['severity'] ?? 'low').toString(),
          ));
        }
      }
    }
    final good = <String>[];
    final rawGood = f['good'];
    if (rawGood is List) {
      for (final g in rawGood) {
        good.add(g.toString());
      }
    }
    final pj = <String>{};
    final rawPj = f['problem_joints'];
    if (rawPj is List) {
      for (final j in rawPj) {
        pj.add(j.toString());
      }
    }
    return FormResult(
      visible: f['visible'] != false,
      summary: (f['summary'] ?? '').toString(),
      good: good,
      issues: issues,
      landmarks: lm,
      problemJoints: pj,
    );
  }
}
