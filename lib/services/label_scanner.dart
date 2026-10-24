import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../core/label_scan.dart';

/// A photo of a nutrition panel and the lines read off it, boxes in the
/// photo's pixels ([size]).
class LabelScan {
  const LabelScan(this.imagePath, this.size, this.lines);
  final String imagePath;
  final ui.Size size;
  final List<OcrLine> lines;
}

/// Photo from the system camera or the gallery, read on device by ML Kit's
/// bundled Latin model: nothing leaves the phone (PRD §4.8).
// ponytail: system camera via image_picker, not a live viewfinder with
// auto-capture; add the camera plugin + streamed OCR if framing gets fiddly
// ponytail: a photo taken while Android killed the activity is lost (no
// retrieveLostData()); recover it at launch and reopen the scan sheet if
// low-memory phones drop scans
class LabelScanner {
  /// Null when the user backs out of the camera or gallery.
  Future<LabelScan?> scan(ImageSource source) async {
    final photo = await ImagePicker().pickImage(source: source);
    if (photo == null) return null;
    final recognizer = TextRecognizer();
    try {
      final text = await recognizer.processImage(
        InputImage.fromFilePath(photo.path),
      );
      return LabelScan(photo.path, await _size(photo.path), [
        for (final b in text.blocks)
          for (final l in b.lines)
            OcrLine(
              l.text,
              l.boundingBox.left,
              l.boundingBox.top,
              l.boundingBox.right,
              l.boundingBox.bottom,
            ),
      ]);
    } finally {
      await recognizer.close();
    }
  }

  /// From the file header, upright (EXIF orientation applied, as ML Kit
  /// does), without decoding the pixels.
  static Future<ui.Size> _size(String path) async {
    final buffer = await ui.ImmutableBuffer.fromFilePath(path);
    final d = await ui.ImageDescriptor.encoded(buffer);
    final size = ui.Size(d.width.toDouble(), d.height.toDouble());
    d.dispose();
    buffer.dispose();
    return size;
  }
}

/// Faked in tests.
final labelScannerProvider = Provider<LabelScanner>((ref) => LabelScanner());
