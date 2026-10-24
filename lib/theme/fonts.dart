import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Bundled font files (Inter 400/500/600/700, Bricolage Grotesque 700) and
/// their OFL licences. Add a file here when the theme uses a new weight.
const kFontDir = 'assets/google_fonts';

const _licences = {
  'Inter': '$kFontDir/OFL-Inter.txt',
  'Bricolage Grotesque': '$kFontDir/OFL-BricolageGrotesque.txt',
};

bool _licencesAdded = false;

/// Fonts come from the bundle only; the app has no network permission (FR8).
void configureFonts() {
  GoogleFonts.config.allowRuntimeFetching = false;
  if (_licencesAdded) return;
  _licencesAdded = true;
  LicenseRegistry.addLicense(() async* {
    for (final MapEntry(key: family, value: path) in _licences.entries) {
      yield LicenseEntryWithLineBreaks([
        family,
      ], await rootBundle.loadString(path));
    }
  });
}
