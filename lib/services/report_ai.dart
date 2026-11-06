import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

class ReportAiException implements Exception {
  final String message;
  ReportAiException(this.message);
  @override
  String toString() => message;
}

/// What the AI read from a medical report photo. Stored as a plain map so it
/// can be saved and synced with the rest of the user's data.
class ReportAi {
  /// Sends the photo to the `report` edge function (counts as 1 AI request).
  /// The photo is not stored anywhere; only the short result is kept.
  static Future<Map<String, dynamic>> read(List<int> jpegBytes) async {
    Map<String, dynamic> data;
    try {
      final res = await Supabase.instance.client.functions.invoke('report', body: {
        'image': base64Encode(jpegBytes),
        'mime': 'image/jpeg',
      });
      data = Map<String, dynamic>.from(res.data as Map);
    } on FunctionException catch (e) {
      final d = e.details;
      throw ReportAiException(d is Map && d['message'] != null
          ? d['message'].toString()
          : 'Could not read the report. Try again.');
    } catch (_) {
      throw ReportAiException('No internet or sign-in problem. Try again.');
    }
    final r = data['report'];
    if (r is! Map || r['readable'] == false) {
      throw ReportAiException(
          'I could not read a medical report in that photo. Take a closer, clearer photo of the page with the results.');
    }
    return Map<String, dynamic>.from(r);
  }
}
