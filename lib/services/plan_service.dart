import 'package:supabase_flutter/supabase_flutter.dart';

/// The user's plan, read from the server (`my_plan`). Plans are granted by the
/// server only, never by the app, so a modified app cannot unlock Pro.
class PlanInfo {
  final bool pro;
  final DateTime? expiresAt;

  const PlanInfo({required this.pro, this.expiresAt});
}

class PlanService {
  static Future<PlanInfo> load() async {
    try {
      final r = await Supabase.instance.client.rpc('my_plan');
      if (r is Map) {
        final exp = r['expires_at'];
        return PlanInfo(
          pro: r['plan'] == 'pro',
          expiresAt: exp is String ? DateTime.tryParse(exp)?.toLocal() : null,
        );
      }
    } catch (_) {}
    return const PlanInfo(pro: false);
  }
}
