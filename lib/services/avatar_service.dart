import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The profile photo. It is picked from the gallery and kept on this phone
/// only (it is not uploaded anywhere).
class AvatarService extends ChangeNotifier {
  AvatarService._();
  static final instance = AvatarService._();

  File? file;
  int _version = 0;

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final path = p.getString('avatarPath');
      if (path != null && File(path).existsSync()) file = File(path);
    } catch (_) {}
  }

  /// Opens the gallery. Returns false when nothing was chosen or it failed.
  Future<bool> pick() async {
    try {
      final x = await ImagePicker()
          .pickImage(source: ImageSource.gallery, maxWidth: 700, maxHeight: 700, imageQuality: 85);
      if (x == null) return false;
      final dir = await getApplicationDocumentsDirectory();
      _version++;
      final dest = File('${dir.path}/avatar_$_version.jpg');
      await File(x.path).copy(dest.path);
      final old = file;
      file = dest;
      final p = await SharedPreferences.getInstance();
      await p.setString('avatarPath', dest.path);
      try {
        await old?.delete();
      } catch (_) {}
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> remove() async {
    final old = file;
    file = null;
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove('avatarPath');
      await old?.delete();
    } catch (_) {}
    notifyListeners();
  }
}

/// Round profile picture, or a person icon when none is set.
class AvatarCircle extends StatelessWidget {
  final double size;

  const AvatarCircle({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AvatarService.instance,
      builder: (context, _) {
        final f = AvatarService.instance.file;
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            image: f == null ? null : DecorationImage(image: FileImage(f), fit: BoxFit.cover),
          ),
          child: f == null
              ? Icon(Icons.person, size: size * 0.55, color: const Color(0xFF5B2BD8))
              : null,
        );
      },
    );
  }
}
