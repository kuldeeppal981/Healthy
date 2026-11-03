import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/label_ai.dart';
import '../theme.dart';
import '../widgets/scan_frame.dart';
import '../widgets/ui_kit.dart';
import 'scan_result_screen.dart';
import 'scan_screen.dart';

/// Take or choose a photo of the ingredient list / nutrition table. The AI
/// reads it, then the normal result screen shows allergy warnings and health
/// notes and lets the user add the food to the diary.
class LabelPhotoScreen extends StatefulWidget {
  const LabelPhotoScreen({super.key});

  @override
  State<LabelPhotoScreen> createState() => _LabelPhotoScreenState();
}

class _LabelPhotoScreenState extends State<LabelPhotoScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _busy = false;
  String? _error;

  Future<void> _go(ImageSource source) async {
    setState(() {
      _error = null;
    });
    try {
      final f = await _picker.pickImage(
        source: source,
        maxWidth: 1400,
        imageQuality: 80,
      );
      if (f == null) return;
      setState(() => _busy = true);
      final bytes = await f.readAsBytes();
      final item = await LabelAi.read(f.path, bytes);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ScanResultScreen(barcode: '', item: item),
        ),
      );
    } on LabelAiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not open the camera or photo. Allow permission and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan food')),
      body: AppBackground(
       child: Padding(
        padding: const EdgeInsets.all(20),
        child: _busy
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Reading the label...'),
                    SizedBox(height: 4),
                    Text('This can take up to 30 seconds.',
                        style: TextStyle(color: AppColors.muted, fontSize: 12)),
                  ],
                ),
              )
            : ListView(
                children: [
                  const ScanFrame(),
                  const SizedBox(height: 20),
                  const Text(
                    'Take a clear photo of the ingredient list and the nutrition table.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You will see allergy warnings and health notes, and can add it to your diary. Both parts in one photo works best. Uses 1 of your daily AI requests.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    AppCard(
                      color: AppColors.dangerBg,
                      borderColor: AppColors.dangerBg,
                      child: Text(_error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)),
                    ),
                  ],
                  const SizedBox(height: 24),
                  GradientButton(
                    onPressed: () => _go(ImageSource.camera),
                    icon: Icons.photo_camera_outlined,
                    label: 'Take photo',
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _go(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Choose from gallery'),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute<void>(builder: (_) => const BarcodeScanScreen()),
                    ),
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scan barcode instead'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'AI can misread words. Always check the real label if you have a serious allergy.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ],
              ),
       ),
      ),
    );
  }
}
