import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pizzalator/theme/fonts.dart';
import 'package:pizzalator/theme/pizza_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Every family/weight the theme asks for. File names follow the google_fonts
  // API convention (<Family>-<Weight>.ttf) or the package will not find them.
  const expected = [
    'Inter-Regular',
    'Inter-Medium',
    'Inter-SemiBold',
    'Inter-Bold',
    'BricolageGrotesque-Bold',
  ];

  test('every weight the theme uses is bundled as a TrueType asset', () async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assets = manifest.listAssets();
    for (final name in expected) {
      final path = '$kFontDir/$name.ttf';
      expect(assets, contains(path));
      final bytes = (await rootBundle.load(path)).buffer.asUint8List();
      // TrueType magic 0x00010000.
      expect(bytes.sublist(0, 4), [0, 1, 0, 0], reason: path);
    }
  });

  test('configureFonts turns runtime fetching off', () {
    GoogleFonts.config.allowRuntimeFetching = true;
    configureFonts();
    expect(GoogleFonts.config.allowRuntimeFetching, isFalse);
  });

  test('configureFonts registers both OFL licences once', () async {
    configureFonts();
    configureFonts();
    final entries = await LicenseRegistry.licenses.toList();
    for (final family in ['Inter', 'Bricolage Grotesque']) {
      final mine = entries.where((e) => e.packages.contains(family)).toList();
      expect(mine, hasLength(1), reason: family);
      final text = mine.single.paragraphs.map((p) => p.text).join(' ');
      expect(text, contains('SIL OPEN FONT LICENSE'));
    }
  });

  test('google_fonts resolves every theme style from the bundle', () async {
    configureFonts();
    final t = PizzaText(PizzaColors.dark);
    // Touching each style queues its font load; a missing file or wrong name
    // makes pendingFonts fail because runtime fetching is off.
    final styles = [t.body, t.caption, t.bodyStrong, t.number, t.h1];
    expect(styles.map((s) => s.fontWeight).toSet(), hasLength(4));
    await GoogleFonts.pendingFonts().timeout(const Duration(seconds: 10));
  });
}
