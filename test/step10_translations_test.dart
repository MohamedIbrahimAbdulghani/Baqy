import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every key of the Arabic ARB file exists in the English one and the other way round', () {
    final arFile = File('lib/l10n/app_ar.arb');
    final enFile = File('lib/l10n/app_en.arb');

    expect(arFile.existsSync(), isTrue);
    expect(enFile.existsSync(), isTrue);

    final Map<String, dynamic> arMap = json.decode(arFile.readAsStringSync());
    final Map<String, dynamic> enMap = json.decode(enFile.readAsStringSync());

    final arKeys = arMap.keys.where((k) => !k.startsWith('@')).toSet();
    final enKeys = enMap.keys.where((k) => !k.startsWith('@')).toSet();

    final missingInEn = arKeys.difference(enKeys);
    final missingInAr = enKeys.difference(arKeys);

    expect(
      missingInEn,
      isEmpty,
      reason: 'Keys present in Arabic but missing in English: $missingInEn',
    );
    expect(
      missingInAr,
      isEmpty,
      reason: 'Keys present in English but missing in Arabic: $missingInAr',
    );
  });

  test('google-services.json is ignored by git', () {
    final result = Process.runSync('git', ['check-ignore', 'android/app/google-services.json']);
    expect(result.exitCode, equals(0));
    expect(result.stdout.toString().trim(), contains('google-services.json'));
  });
}
