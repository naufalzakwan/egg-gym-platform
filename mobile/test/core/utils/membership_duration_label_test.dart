import 'package:egg_gym/core/utils/membership_duration_label.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats real admin duration days without package-name assumptions', () {
    expect(membershipDurationLabel(durationDays: 7), 'Minggu');
    expect(membershipDurationLabel(durationDays: 14), '2 Minggu');
    expect(membershipDurationLabel(durationDays: 30), 'Bulan');
    expect(membershipDurationLabel(durationDays: 60), '2 Bulan');
    expect(membershipDurationLabel(durationDays: 365), 'Tahun');
    expect(membershipDurationLabel(durationDays: 10), '10 Hari');
  });
}
