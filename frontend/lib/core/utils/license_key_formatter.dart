import 'package:flutter/services.dart';

class LicenseKeyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final String upper = newValue.text.toUpperCase();
    final String clean = upper.replaceAll(RegExp(r'[^A-Z0-9]'), '');

    if (clean.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    // Limit maximum length to 25 alphanumeric characters
    final String limitedClean = clean.length > 25 ? clean.substring(0, 25) : clean;

    // Count how many valid alphanumeric characters were before the cursor in newValue
    int cleanCursorCount = 0;
    final int selEnd = newValue.selection.end.clamp(0, newValue.text.length);
    for (int i = 0; i < selEnd; i++) {
      if (RegExp(r'[A-Z0-9]').hasMatch(newValue.text[i].toUpperCase())) {
        cleanCursorCount++;
      }
    }
    if (cleanCursorCount > limitedClean.length) {
      cleanCursorCount = limitedClean.length;
    }

    final StringBuffer formatted = StringBuffer();
    // Segment lengths: standard WDEV tokens use 4-3-4-4-4, others use 4-4-4-4-4
    final List<int> segmentLengths = limitedClean.startsWith('WDEV')
        ? [4, 3, 4, 4, 4]
        : [4, 4, 4, 4, 4];

    int charIndex = 0;
    for (int i = 0; i < segmentLengths.length && charIndex < limitedClean.length; i++) {
      if (i > 0 && charIndex < limitedClean.length) {
        formatted.write('-');
      }
      final int len = segmentLengths[i];
      final int remaining = limitedClean.length - charIndex;
      final int take = remaining < len ? remaining : len;
      formatted.write(limitedClean.substring(charIndex, charIndex + take));
      charIndex += take;
    }

    final String formattedText = formatted.toString();

    // Map the cursor position back into the formatted text
    int newCursorOffset = 0;
    int countedClean = 0;
    for (int i = 0; i < formattedText.length; i++) {
      if (formattedText[i] != '-') {
        countedClean++;
      }
      if (countedClean == cleanCursorCount) {
        newCursorOffset = i + 1;
        break;
      }
    }

    if (cleanCursorCount == 0) newCursorOffset = 0;
    if (newCursorOffset > formattedText.length) newCursorOffset = formattedText.length;

    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: newCursorOffset),
    );
  }
}
