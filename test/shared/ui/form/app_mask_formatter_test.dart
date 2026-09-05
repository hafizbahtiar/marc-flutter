import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/shared/ui/form/app_mask_formatter.dart';

void main() {
  group('AppMaskTextInputFormatter', () {
    TextEditingValue run(
      String old,
      String next, {
      String mask = '##/##',
      bool eager = false,
      int? oldCursor,
      int? nextCursor,
    }) {
      return AppMaskTextInputFormatter(
        mask: mask,
        eager: eager,
      ).formatEditUpdate(
        TextEditingValue(
          text: old,
          selection: TextSelection.collapsed(offset: oldCursor ?? old.length),
        ),
        TextEditingValue(
          text: next,
          selection: TextSelection.collapsed(offset: nextCursor ?? next.length),
        ),
      );
    }

    test('taip digit, literal lazy lepas slot penuh', () {
      expect(run('', '1').text, '1');
      expect(run('1', '12').text, '12');
      expect(run('12', '123').text, '12/3');
      expect(run('12/3', '12/34').text, '12/34');
    });

    test('eager masukkan literal lepas slot', () {
      expect(run('', '1', eager: true).text, '1');
      expect(run('1', '12', eager: true).text, '12/');
      expect(run('12/', '12/3', eager: true).text, '12/3');
    });

    test('awalan literal muncul bila mula taip', () {
      expect(run('', '0', mask: 'MARC-####').text, 'MARC-0');
      expect(run('MARC-0', 'MARC-01', mask: 'MARC-####').text, 'MARC-01');
    });

    test('aksara luar topeng ditolak', () {
      expect(run('12', '12a').text, '12');
      expect(run('12', '12/', mask: '####').text, '12');
    });

    test('backspace padam digit, cursor ikut', () {
      final v = run('12/34', '12/3');
      expect(v.text, '12/3');
      expect(v.selection.baseOffset, 4);
    });

    test('backspace pada literal tak buang data - topeng masuk semula', () {
      final v = run('12/34', '1234', oldCursor: 3, nextCursor: 2);
      expect(v.text, '12/34');
    });

    test('backspace tengah medan kekal kedudukan cursor', () {
      final v = run('12/34', '1/34', oldCursor: 2, nextCursor: 1);
      expect(v.text, '13/4');
      expect(v.selection.baseOffset, 1);
    });

    test('paste padat dan overflow ikut topeng telefon', () {
      final f = AppMaskTextInputFormatter(mask: '+# (###) ###-##-##');
      final pasted = f.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
          text: '01234567890123456',
          selection: TextSelection.collapsed(offset: 18),
        ),
      );
      expect(pasted.text, '+0 (123) 456-78-90');
      expect(f.getUnmaskedText(), '01234567890');
      expect(f.isFill(), isTrue);

      final overflow = f.formatEditUpdate(
        pasted,
        const TextEditingValue(
          text: '+0 (123) 456-78-901',
          selection: TextSelection.collapsed(offset: 19),
        ),
      );
      expect(overflow.text, '+0 (123) 456-78-90');
    });

    test('buang tengah, digit tinggal susun semula', () {
      final f = AppMaskTextInputFormatter(mask: '+# (###) ###-##-##');
      var value = f.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
          text: '01234567890',
          selection: TextSelection.collapsed(offset: 11),
        ),
      );
      value = TextEditingValue(
        text: value.text,
        selection: const TextSelection(baseOffset: 5, extentOffset: 7),
      );
      value = f.formatEditUpdate(
        value,
        const TextEditingValue(
          text: '+0 (1) 456-78-90',
          selection: TextSelection.collapsed(offset: 5),
        ),
      );
      expect(value.text, '+0 (145) 678-90');
      expect(f.getUnmaskedText(), '014567890');
    });

    test('upperCase tukar huruf kecil jadi besar', () {
      final f = AppMaskTextInputFormatter(mask: '****/####', upperCase: true);
      final v = f.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: 'ab1c2026'),
      );
      expect(v.text, 'AB1C/2026');
      expect(f.getUnmaskedText(), 'AB1C2026');
    });

    test('upperCase menepati filter huruf besar sahaja', () {
      final f = AppMaskTextInputFormatter(
        mask: '***',
        filter: {'*': RegExp(r'[A-Z]')},
        upperCase: true,
      );
      final v = f.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: 'abc'),
      );
      expect(v.text, 'ABC');
    });

    test('tanpa upperCase huruf kekal seperti ditaip', () {
      final f = AppMaskTextInputFormatter(mask: '****');
      final v = f.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: 'ab1c'),
      );
      expect(v.text, 'ab1c');
    });

    test('updateMask kekal data tak bertopeng', () {
      final f = AppMaskTextInputFormatter(mask: '####-####');
      f.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '12345678'),
      );
      final next = f.updateMask(mask: '##/##-##/##');
      expect(next.text, '12/34-56/78');
      expect(f.getUnmaskedText(), '12345678');
    });
  });
}
