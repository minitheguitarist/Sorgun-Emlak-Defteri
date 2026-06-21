import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class PhotoService {
  PhotoService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  Future<List<String>> pickFromGallery() async {
    final files = await _picker.pickMultiImage(
      imageQuality: 82,
      maxWidth: 1800,
    );
    return _copyAll(files);
  }

  Future<String?> takePhoto() async {
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 82,
      maxWidth: 1800,
    );
    if (file == null) {
      return null;
    }
    final copied = await _copyToAppDirectory(file);
    return copied.path;
  }

  Future<List<String>> _copyAll(List<XFile> files) async {
    final paths = <String>[];
    for (final file in files) {
      final copied = await _copyToAppDirectory(file);
      paths.add(copied.path);
    }
    return paths;
  }

  Future<File> _copyToAppDirectory(XFile file) async {
    final directory = await getApplicationDocumentsDirectory();
    final photosDir = Directory(p.join(directory.path, 'property_photos'));
    if (!photosDir.existsSync()) {
      await photosDir.create(recursive: true);
    }

    final extension =
        p.extension(file.path).isEmpty ? '.jpg' : p.extension(file.path);
    final fileName =
        '${DateTime.now().microsecondsSinceEpoch}_${p.basenameWithoutExtension(file.path)}$extension';
    return File(file.path).copy(p.join(photosDir.path, fileName));
  }
}
