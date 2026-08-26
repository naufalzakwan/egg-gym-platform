import 'package:egg_gym/data/services/backend_payment_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('membership transactions sort by created at newest first', () {
    final items = [
      _item(1, DateTime.utc(2026, 7, 21), paidAt: DateTime.utc(2026, 7, 25)),
      _item(2, DateTime.utc(2026, 7, 26)),
      _item(3, DateTime.utc(2026, 7, 22), paidAt: DateTime.utc(2026, 7, 26)),
    ]..sort(compareMemberTransactionsNewestFirst);

    expect(items.map((item) => item.id), [2, 3, 1]);
  });

  test('transaction id breaks equal created at ties newest first', () {
    final createdAt = DateTime.utc(2026, 7, 26);
    final items = [_item(4, createdAt), _item(5, createdAt)]
      ..sort(compareMemberTransactionsNewestFirst);

    expect(items.map((item) => item.id), [5, 4]);
  });
}

MemberTransactionListItem _item(
  int id,
  DateTime createdAt, {
  DateTime? paidAt,
}) {
  return MemberTransactionListItem(
    id: id,
    title: 'Transaksi $id',
    amount: 100000,
    status: paidAt == null ? 'pending' : 'completed',
    paymentMethod: 'qris',
    referenceCode: 'TX-$id',
    paidAt: paidAt,
    createdAt: createdAt,
  );
}
