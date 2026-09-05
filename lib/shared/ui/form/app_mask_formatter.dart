import 'dart:math';

import 'package:flutter/services.dart';

/// Topeng input — algorithm [mask_text_input_formatter] (siqwin),
/// tanpa package.
///
/// Slot lalai: `#` digit, `*` huruf/digit. Aksara lain (termasuk `A`)
/// ialah literal — tambah `A` sendiri dalam [filter] jika perlu slot
/// huruf, supaya `MARC-####` tak pecah.
///
/// [eager]: literal masuk terus lepas slot; lazy (lalai) tunggu aksara
/// data seterusnya.
class AppMaskTextInputFormatter extends TextInputFormatter {
  AppMaskTextInputFormatter({
    required String mask,
    Map<String, RegExp>? filter,
    String? initialText,
    this.eager = false,
  }) : _mask = mask,
       filter = filter ?? defaultFilter {
    _updateFilter(this.filter);
    _calcMaskLength();
    if (initialText != null) {
      formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(
          text: initialText,
          selection: TextSelection.collapsed(offset: initialText.length),
        ),
      );
    }
  }

  static final defaultFilter = <String, RegExp>{
    '#': RegExp(r'[0-9]'),
    '*': RegExp(r'[A-Za-z0-9]'),
  };

  String _mask;
  final bool eager;
  Map<String, RegExp> filter;
  List<String> _maskChars = [];
  int _maskLength = 0;
  final _TextMatcher _resultTextArray = _TextMatcher();
  String _resultTextMasked = '';

  String getMask() => _mask;

  String getMaskedText() => _resultTextMasked;

  String getUnmaskedText() => _resultTextArray.toString();

  bool isFill() => _resultTextArray.length == _maskLength;

  void clear() {
    _resultTextMasked = '';
    _resultTextArray.clear();
  }

  String maskText(String text) {
    return AppMaskTextInputFormatter(
      mask: _mask,
      filter: filter,
      eager: eager,
      initialText: text,
    ).getMaskedText();
  }

  String unmaskText(String text) {
    return AppMaskTextInputFormatter(
      mask: _mask,
      filter: filter,
      eager: eager,
      initialText: text,
    ).getUnmaskedText();
  }

  TextEditingValue updateMask({
    String? mask,
    Map<String, RegExp>? filter,
    bool? eager,
    TextEditingValue? newValue,
  }) {
    if (mask != null) _mask = mask;
    if (filter != null) {
      this.filter = filter;
      _updateFilter(filter);
    }
    _calcMaskLength();
    final unmasked = getUnmaskedText();
    final target =
        newValue ??
        TextEditingValue(
          text: unmasked,
          selection: TextSelection.collapsed(offset: unmasked.length),
        );
    clear();
    return formatEditUpdate(TextEditingValue.empty, target);
  }

  bool _isSlot(String ch) => _maskChars.contains(ch);

  void _calcMaskLength() {
    _maskLength = 0;
    for (var i = 0; i < _mask.length; i++) {
      if (_isSlot(_mask[i])) _maskLength++;
    }
  }

  void _updateFilter(Map<String, RegExp> next) {
    filter = next;
    _maskChars = next.keys.toList(growable: false);
  }

  void _hydrateFrom(String oldText) {
    if (oldText.isEmpty) {
      _resultTextArray.clear();
      _resultTextMasked = '';
      return;
    }
    if (_resultTextMasked == oldText && _resultTextArray.length > 0) return;
    _resultTextArray.clear();
    var slot = 0;
    while (slot < _mask.length && !_isSlot(_mask[slot])) {
      slot++;
    }
    for (var i = 0; i < oldText.length; i++) {
      if (slot >= _mask.length) break;
      final ch = oldText[i];
      final re = filter[_mask[slot]];
      if (re != null && re.hasMatch(ch)) {
        _resultTextArray.insert(_resultTextArray.length, ch);
        slot++;
        while (slot < _mask.length && !_isSlot(_mask[slot])) {
          slot++;
        }
      }
    }
    _resultTextMasked = oldText;
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final mask = _mask;
    if (mask.isEmpty) {
      _resultTextMasked = newValue.text;
      _resultTextArray
        ..clear()
        ..insert(0, newValue.text);
      return newValue;
    }

    if (oldValue.text.isEmpty) {
      _resultTextArray.clear();
    } else {
      _hydrateFrom(oldValue.text);
    }

    final beforeText = oldValue.text;
    final afterText = newValue.text;
    final beforeSelection = oldValue.selection;
    final afterSelection = newValue.selection;

    var beforeSelectionStart = afterSelection.isValid
        ? (beforeSelection.isValid ? beforeSelection.start : 0)
        : 0;

    for (
      var i = 0;
      i < beforeSelectionStart && i < beforeText.length && i < afterText.length;
      i++
    ) {
      if (beforeText[i] != afterText[i]) {
        beforeSelectionStart = i;
        break;
      }
    }

    final beforeSelectionLength = afterSelection.isValid
        ? (beforeSelection.isValid
              ? beforeSelection.end - beforeSelectionStart
              : 0)
        : oldValue.text.length;

    final lengthDifference =
        afterText.length - (beforeText.length - beforeSelectionLength);
    final lengthRemoved = lengthDifference < 0 ? lengthDifference.abs() : 0;
    final lengthAdded = lengthDifference > 0 ? lengthDifference : 0;

    final afterChangeStart = max(0, beforeSelectionStart - lengthRemoved);
    final afterChangeEnd = max(0, afterChangeStart + lengthAdded);
    final beforeReplaceStart = max(0, beforeSelectionStart - lengthRemoved);
    final beforeReplaceLength = beforeSelectionLength + lengthRemoved;

    final beforeResultTextLength = _resultTextArray.length;
    var currentResultTextLength = _resultTextArray.length;
    var currentResultSelectionStart = 0;
    var currentResultSelectionLength = 0;

    for (
      var i = 0;
      i < min(beforeReplaceStart + beforeReplaceLength, mask.length);
      i++
    ) {
      if (_isSlot(mask[i]) && currentResultTextLength > 0) {
        currentResultTextLength -= 1;
        if (i < beforeReplaceStart) {
          currentResultSelectionStart += 1;
        }
        if (i >= beforeReplaceStart) {
          currentResultSelectionLength += 1;
        }
      }
    }

    final replacementText = afterText.substring(
      afterChangeStart,
      min(afterChangeEnd, afterText.length),
    );
    var targetCursorPosition = currentResultSelectionStart;
    if (replacementText.isEmpty) {
      _resultTextArray.removeRange(
        currentResultSelectionStart,
        currentResultSelectionStart + currentResultSelectionLength,
      );
    } else {
      if (currentResultSelectionLength > 0) {
        _resultTextArray.removeRange(
          currentResultSelectionStart,
          currentResultSelectionStart + currentResultSelectionLength,
        );
      }
      _resultTextArray.insert(currentResultSelectionStart, replacementText);
      targetCursorPosition += replacementText.length;
    }

    if (beforeResultTextLength == 0 && _resultTextArray.length > 1) {
      var prefixLength = 0;
      for (var i = 0; i < mask.length; i++) {
        if (_isSlot(mask[i])) {
          prefixLength = i;
          break;
        }
      }
      if (prefixLength > 0) {
        final resultPrefix = _resultTextArray.symbols
            .take(prefixLength)
            .toList();
        final effective = min(_resultTextArray.length, resultPrefix.length);
        for (var j = 0; j < effective; j++) {
          if (mask[j] != resultPrefix[j]) {
            _resultTextArray.removeRange(0, j);
            break;
          }
          if (j == effective - 1) {
            _resultTextArray.removeRange(0, effective);
            break;
          }
        }
      }
    }

    var curTextPos = 0;
    var maskPos = 0;
    _resultTextMasked = '';
    var cursorPos = -1;
    var nonMaskedCount = 0;
    var maskInside = 0;

    while (maskPos < mask.length) {
      final curMaskChar = mask[maskPos];
      final isMaskChar = _isSlot(curMaskChar);
      var curTextInRange = curTextPos < _resultTextArray.length;

      String? curTextChar;
      if (isMaskChar && curTextInRange) {
        if (maskInside > 0) {
          _resultTextArray.removeRange(curTextPos - maskInside, curTextPos);
          curTextPos -= maskInside;
        }
        maskInside = 0;
        while (curTextChar == null && curTextInRange) {
          final potential = _resultTextArray[curTextPos];
          if (filter[curMaskChar]?.hasMatch(potential) ?? false) {
            curTextChar = potential;
          } else {
            _resultTextArray.removeAt(curTextPos);
            curTextInRange = curTextPos < _resultTextArray.length;
            if (curTextPos <= targetCursorPosition) {
              targetCursorPosition -= 1;
            }
          }
        }
      } else if (!isMaskChar && !curTextInRange && eager) {
        curTextInRange = true;
      }

      if (isMaskChar && curTextInRange && curTextChar != null) {
        _resultTextMasked += curTextChar;
        if (curTextPos == targetCursorPosition && cursorPos == -1) {
          cursorPos = maskPos - nonMaskedCount;
        }
        nonMaskedCount = 0;
        curTextPos += 1;
      } else {
        if (!curTextInRange) {
          if (maskInside > 0) {
            curTextPos -= maskInside;
            maskInside = 0;
            nonMaskedCount = 0;
            continue;
          }
          break;
        }
        _resultTextMasked += mask[maskPos];
        if (!isMaskChar &&
            curTextPos < _resultTextArray.length &&
            curMaskChar == _resultTextArray[curTextPos]) {
          if (!( !eager && lengthAdded <= 1)) {
            maskInside++;
            curTextPos++;
          }
        } else if (maskInside > 0) {
          curTextPos -= maskInside;
          maskInside = 0;
        }

        if (curTextPos == targetCursorPosition &&
            cursorPos == -1 &&
            !curTextInRange) {
          cursorPos = maskPos;
        }

        if (!eager ||
            lengthRemoved > 0 ||
            currentResultSelectionLength > 0 ||
            beforeReplaceLength > 0) {
          nonMaskedCount++;
        }
      }

      maskPos++;
    }

    if (nonMaskedCount > 0 &&
        nonMaskedCount <= _resultTextMasked.length) {
      _resultTextMasked = _resultTextMasked.substring(
        0,
        _resultTextMasked.length - nonMaskedCount,
      );
      cursorPos -= nonMaskedCount;
    }

    if (_resultTextArray.length > _maskLength) {
      _resultTextArray.removeRange(_maskLength, _resultTextArray.length);
    }

    final finalCursor = cursorPos < 0
        ? _resultTextMasked.length
        : cursorPos.clamp(0, _resultTextMasked.length);

    return TextEditingValue(
      text: _resultTextMasked,
      selection: TextSelection(
        baseOffset: finalCursor,
        extentOffset: finalCursor,
        affinity: newValue.selection.affinity,
        isDirectional: newValue.selection.isDirectional,
      ),
    );
  }
}

class _TextMatcher {
  final List<String> symbols = [];

  int get length => symbols.fold(0, (prev, match) => prev + match.length);

  void removeRange(int start, int end) {
    final s = start.clamp(0, symbols.length);
    final e = end.clamp(s, symbols.length);
    symbols.removeRange(s, e);
  }

  void insert(int start, String substring) {
    final at = start.clamp(0, symbols.length);
    for (var i = 0; i < substring.length; i++) {
      symbols.insert(at + i, substring[i]);
    }
  }

  void removeAt(int index) {
    if (index >= 0 && index < symbols.length) symbols.removeAt(index);
  }

  String operator [](int index) => symbols[index];

  void clear() => symbols.clear();

  @override
  String toString() => symbols.join();
}
