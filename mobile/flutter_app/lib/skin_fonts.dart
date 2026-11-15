import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

void registerSkinFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final family in [
      'Inter',
      'Lora',
      'Nunito',
      'SpaceMono',
      'NotoSansArabic',
      'NotoNaskhArabic',
    ]) {
      yield LicenseEntryWithLineBreaks([
        family,
      ], await rootBundle.loadString('assets/fonts/licenses/$family.txt'));
    }
  });
}
