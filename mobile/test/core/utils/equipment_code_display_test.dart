import 'package:egg_gym/core/utils/equipment_code_display.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('empty and placeholder equipment codes are hidden', () {
    expect(realEquipmentCode(null), isNull);
    expect(realEquipmentCode(''), isNull);
    expect(realEquipmentCode('  '), isNull);
    expect(realEquipmentCode('-'), isNull);
    expect(realEquipmentCode('Tanpa kode'), isNull);
    expect(realEquipmentCode('No Code'), isNull);
  });

  test('real backend equipment code remains visible', () {
    expect(realEquipmentCode(' EQ-001 '), 'EQ-001');
  });
}
