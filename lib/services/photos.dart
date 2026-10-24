import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../core/recipe_json.dart';

/// Bake photos in `<docs>/photos/`, by file name (PRD §5: stored in the app
/// documents dir). Picked with the system camera or gallery, resized there.
class PhotoStore {
  PhotoStore(this.docs);

  final Directory docs;

  Directory get _dir => Directory('${docs.path}/photos');

  File file(String name) => File('${_dir.path}/$name');

  /// The new photo's file name; null when the user backs out. A new name
  /// every time, so a replaced photo never shows the old one from the
  /// image cache.
  Future<String?> pick(ImageSource source) async {
    final photo = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (photo == null) return null;
    await _dir.create(recursive: true);
    final id = clockId(DateTime.now(), (id) => file('$id.jpg').existsSync());
    final name = '$id.jpg';
    await File(photo.path).copy(file(name).path);
    return name;
  }

  Future<void> delete(String name) async {
    final f = file(name);
    if (f.existsSync()) await f.delete();
  }
}

/// Overridden in main.dart with the app documents dir, and in tests.
final photoStoreProvider = Provider<PhotoStore>(
  (ref) => throw UnimplementedError('Override photoStoreProvider'),
);
