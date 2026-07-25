import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fix_radar/core/services/language_service.dart';
import 'package:fix_radar/core/localization/locale_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  test('loads all supported locale JSON assets and resolves keys', () async {
    final service = LanguageService();
    await service.init();

    expect(service.supportedLocales.length, AppLocales.supported.length,
        reason: 'Every locale in AppLocales.supported should have loaded its JSON file');

    await service.setLanguage('es');
    expect(service.translate('app_title'), 'Fix_Radar');
    expect(service.translate('cat_electricidad'), 'Electricidad');

    await service.setLanguage('en');
    expect(service.translate('cat_electricidad'), 'Electricity');

    // Missing key falls back to the key itself, never empty/null.
    expect(service.translate('__does_not_exist__'), '__does_not_exist__');
  });

  test('setLanguage rejects unknown codes and keeps current language', () async {
    final service = LanguageService();
    await service.init();
    await service.setLanguage('en');
    await service.setLanguage('xx');
    expect(service.currentLanguage, 'en');
  });
}
