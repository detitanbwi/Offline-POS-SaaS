import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/utils/license_key_formatter.dart';

void main() {
  group('LicenseKeyInputFormatter Tests', () {
    final formatter = LicenseKeyInputFormatter();

    TextEditingValue format(String oldText, String newText) {
      return formatter.formatEditUpdate(
        TextEditingValue(text: oldText),
        TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: newText.length),
        ),
      );
    }

    test('Converts lowercase input to uppercase with hyphens (WDEV token)', () {
      final res = format('', 'wdevpak73c8a2952026');
      expect(res.text, 'WDEV-PAK-73C8-A295-2026');
    });

    test('Preserves and formats lowercase input with hyphens', () {
      final res = format('', 'wdev-pak-73c8-a295-2026');
      expect(res.text, 'WDEV-PAK-73C8-A295-2026');
    });

    test('Formats partial typing character by character', () {
      expect(format('', 'w').text, 'W');
      expect(format('W', 'Wd').text, 'WD');
      expect(format('WD', 'WDe').text, 'WDE');
      expect(format('WDE', 'WDEv').text, 'WDEV');
      expect(format('WDEV', 'WDEVp').text, 'WDEV-P');
      expect(format('WDEV-P', 'WDEV-Pa').text, 'WDEV-PA');
      expect(format('WDEV-PA', 'WDEV-PAk').text, 'WDEV-PAK');
      expect(format('WDEV-PAK', 'WDEV-PAK7').text, 'WDEV-PAK-7');
    });

    test('Formats non-WDEV generic token into 4-character chunks', () {
      final res = format('', 'pos123456789abcd');
      expect(res.text, 'POS1-2345-6789-ABCD');
    });

    test('Handles empty and invalid characters gracefully', () {
      expect(format('', '').text, '');
      expect(format('', '   ').text, '');
      expect(format('', 'wdev@#%pak!').text, 'WDEV-PAK');
    });
  });
}
