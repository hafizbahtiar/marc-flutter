import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/shared/utils/member_id.dart';

void main() {
  group('maskMemberId', () {
    test('susun semula taip tanpa pemisah ke format rasmi', () {
      expect(maskMemberId('marc011020260001'), 'MARC-0110/2026-0001');
    });

    test('kekal format rasmi, cuma huruf besar', () {
      expect(maskMemberId('marc-0110/2026-0001'), 'MARC-0110/2026-0001');
    });

    test('kod SA dan T nombor', () {
      expect(maskMemberId('marc01102026sa'), 'MARC-0110/2026-SA');
      expect(maskMemberId('MARC-0200/2026-T1'), 'MARC-0200/2026-T1');
    });

    test('format lama tak diubah', () {
      expect(maskMemberId('MARC2026/08/0001'), 'MARC2026/08/0001');
    });

    test('staff_id yang ada sengkang kekal', () {
      expect(maskMemberId('MARC-EMP-001/2026-0001'), 'MARC-EMP-001/2026-0001');
    });
  });

  group('validateMemberId', () {
    test('lulus format rasmi dan format lama', () {
      expect(validateMemberId('MARC-0110/2026-0001'), isNull);
      expect(validateMemberId('MARC-0110/2026-SA'), isNull);
      expect(validateMemberId('MARC2026/08/0001'), isNull);
    });

    test('tolak kosong dan format rosak', () {
      expect(validateMemberId(''), isNotNull);
      expect(validateMemberId('0110'), isNotNull);
    });
  });

  test('unmaskMemberId buang ruang dan pemisah', () {
    expect(unmaskMemberId('  marc-0110/2026-0001  '), 'MARC011020260001');
  });

  group('MemberId', () {
    test('mask auto masukkan / dan - macam license file no', () {
      expect(MemberId.maskValue('011020260001').text, '0110/2026-0001');
      expect(MemberId.maskValue('0110/2026-0001').text, '0110/2026-0001');
      expect(MemberId.maskValue('01102026sa').text, '0110/2026-SA');
    });

    test('huruf dalam tahun dan aksara luar ditolak', () {
      expect(MemberId.maskValue('0110A').text, '0110');
      expect(MemberId.maskValue('0110/2026-0001!').text, '0110/2026-0001');
    });

    test('removePrefix dan formatForSubmit', () {
      expect(MemberId.removePrefix('MARC-0110/2026-0001'), '0110/2026-0001');
      expect(MemberId.formatForSubmit('0110/2026-0001'), 'MARC-0110/2026-0001');
    });

    test('validateBody terima body lengkap, tolak tak lengkap', () {
      expect(MemberId.validateBody('0110/2026-0001'), isNull);
      expect(MemberId.validateBody('0110/2026-SA'), isNull);
      expect(MemberId.validateBody('0110/2026'), isNotNull);
    });
  });

  group('memberIdEditorSeed', () {
    test('kosong dan format baru — body tanpa prefix', () {
      expect(memberIdEditorSeed(null).initialValue, '');
      expect(memberIdEditorSeed(null).message, isNull);
      expect(
        memberIdEditorSeed('MARC-0110/2026-0001').initialValue,
        '0110/2026-0001',
      );
      expect(memberIdEditorSeed('MARC-0110/2026-0001').message, isNull);
    });

    test('format lama mula semula dan papar nombor lama', () {
      final seed = memberIdEditorSeed('MARC2026/08/0001');
      expect(seed.initialValue, '');
      expect(seed.message, contains('MARC2026/08/0001'));
    });
  });

  group('MemberIdInputFormatter', () {
    const formatter = MemberIdInputFormatter();

    test('taip padat auto topeng', () {
      final v = formatter.formatEditUpdate(
        const TextEditingValue(),
        const TextEditingValue(text: '011020260001'),
      );
      expect(v.text, '0110/2026-0001');
    });

    test('backspace padam data, topeng susun semula', () {
      final v = formatter.formatEditUpdate(
        const TextEditingValue(text: '0110/2026-0001'),
        const TextEditingValue(text: '0110/2026-000'),
      );
      expect(v.text, '0110/2026-000');
    });
  });
}
