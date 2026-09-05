import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/shared/ui/form/app_masks.dart';
import 'package:marc/shared/ui/form/mask_field.dart';

void main() {
  group('MaskConfig', () {
    test('sama nilai dianggap sama (rebuild tak bina formatter baharu)', () {
      const a = MaskConfig(mask: '##/##');
      const b = MaskConfig(mask: '##/##');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('filter berbeza dianggap berbeza', () {
      final a = MaskConfig(mask: '***', filter: {'*': RegExp(r'[A-Z]')});
      final b = MaskConfig(mask: '***', filter: {'*': RegExp(r'[0-9]')});
      expect(a, isNot(b));
    });

    test('filter sama walau Map lain dianggap sama', () {
      final a = MaskConfig(mask: '***', filter: {'*': RegExp(r'[A-Z]')});
      final b = MaskConfig(mask: '***', filter: {'*': RegExp(r'[A-Z]')});
      expect(a, b);
    });
  });

  group('MaskFieldBinding', () {
    test('tiada config = tiada formatter, formatters ikut input asal', () {
      final binding = MaskFieldBinding()..update(config: null);
      expect(binding.formatter, isNull);
      expect(binding.formatters(null), isEmpty);
      addTearDown(binding.dispose);
    });

    test('topeng nilai awal', () {
      final binding = MaskFieldBinding()
        ..update(config: const MaskConfig(mask: '##/##'));
      expect(binding.maskInitial('1234'), '12/34');
      addTearDown(binding.dispose);
    });

    test('tukar filter bina formatter baharu', () {
      final binding = MaskFieldBinding()
        ..update(
          config: MaskConfig(mask: '***', filter: {'*': RegExp(r'[0-9]')}),
        );
      final first = binding.formatter;
      binding.update(
        config: MaskConfig(mask: '***', filter: {'*': RegExp(r'[A-Z]')}),
      );
      expect(binding.formatter, isNot(same(first)));
      expect(binding.maskInitial('ABC'), 'ABC');
    });

    test('config sama kekalkan formatter yang sama', () {
      final binding = MaskFieldBinding()
        ..update(config: const MaskConfig(mask: '##/##'));
      final first = binding.formatter;
      binding.update(config: const MaskConfig(mask: '##/##'));
      expect(binding.formatter, same(first));
      addTearDown(binding.dispose);
    });

    test('controller sedia ada ditopeng semasa dilampir', () {
      final controller = TextEditingController(text: '1234');
      final binding = MaskFieldBinding()
        ..update(
          config: const MaskConfig(mask: '##/##'),
          controller: controller,
        );
      expect(controller.text, '12/34');
      addTearDown(binding.dispose);
      addTearDown(controller.dispose);
    });

    test('controller ditetapkan dari luar tetap ditopeng', () {
      final controller = TextEditingController();
      final binding = MaskFieldBinding()
        ..update(
          config: const MaskConfig(mask: '##/##'),
          controller: controller,
        );
      controller.text = '5678';
      expect(controller.text, '56/78');
      addTearDown(binding.dispose);
      addTearDown(controller.dispose);
    });

    test('dispose lepas listener - controller bebas selepas itu', () {
      final controller = TextEditingController();
      MaskFieldBinding()
        ..update(
          config: const MaskConfig(mask: '##/##'),
          controller: controller,
        )
        ..dispose();
      controller.text = '5678';
      expect(controller.text, '5678');
      addTearDown(controller.dispose);
    });

    test('unmaskedText dan isFill ikut teks semasa', () {
      final controller = TextEditingController();
      final binding = MaskFieldBinding()
        ..update(
          config: const MaskConfig(mask: '##/##'),
          controller: controller,
        );
      controller.text = '12';
      expect(binding.unmaskedText, '12');
      expect(binding.isFill, isFalse);
      controller.text = '1234';
      expect(binding.unmaskedText, '1234');
      expect(binding.isFill, isTrue);
      addTearDown(binding.dispose);
      addTearDown(controller.dispose);
    });

    test('unmask dan isFillText boleh diuji tanpa controller', () {
      final binding = MaskFieldBinding()
        ..update(config: const MaskConfig(mask: '##/##'));
      expect(binding.unmask('12/34'), '1234');
      expect(binding.isFillText('12/34'), isTrue);
      expect(binding.isFillText('12/3'), isFalse);
      addTearDown(binding.dispose);
    });

    test('tanpa mask, unmask pulangkan teks asal dan isFillText benar', () {
      final binding = MaskFieldBinding()..update(config: null);
      expect(binding.unmask('abc'), 'abc');
      expect(binding.isFillText('abc'), isTrue);
      addTearDown(binding.dispose);
    });
  });

  group('AppMasks', () {
    test('memberId padan format nombor ahli sedia ada', () {
      final binding = MaskFieldBinding()..update(config: AppMasks.memberId);
      expect(binding.maskInitial('011020260001'), '0110/2026-0001');
      addTearDown(binding.dispose);
    });

    test('memberId auto huruf besar', () {
      final binding = MaskFieldBinding()..update(config: AppMasks.memberId);
      expect(binding.maskInitial('ab1c2026sa'), 'AB1C/2026-SA');
      addTearDown(binding.dispose);
    });

    test('icMY topeng 12 digit', () {
      final binding = MaskFieldBinding()..update(config: AppMasks.icMY);
      expect(binding.maskInitial('901231145678'), '901231-14-5678');
      addTearDown(binding.dispose);
    });

    test('date topeng hari/bulan/tahun', () {
      final binding = MaskFieldBinding()..update(config: AppMasks.date);
      expect(binding.maskInitial('05092026'), '05/09/2026');
      addTearDown(binding.dispose);
    });
  });
}
