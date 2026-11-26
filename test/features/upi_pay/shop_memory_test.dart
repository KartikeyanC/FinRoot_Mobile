import 'package:finroot_mobile/features/upi_pay/data/shop_memory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('remembers per workspace, ignoring the UPI id\'s case', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final m = ShopMemory(prefs);

    await m.remember('t1', 'Shop@OKAXIS', 'Shopping');
    await m.remember('t2', 'shop@okaxis', 'Business');

    expect(m.categoryFor('t1', 'shop@okaxis'), 'Shopping');
    expect(m.categoryFor('t2', 'SHOP@okaxis'), 'Business');
    expect(m.categoryFor('t1', 'other@ybl'), isNull);

    // Survives a restart: a fresh instance reads the same prefs.
    expect(ShopMemory(prefs).categoryFor('t1', 'shop@okaxis'), 'Shopping');
  });

  test('a new category replaces the old one', () async {
    final m = ShopMemory();
    await m.remember('t1', 'tea@paytm', 'Food & Dining');
    await m.remember('t1', 'tea@paytm', 'Entertainment');
    expect(m.categoryFor('t1', 'tea@paytm'), 'Entertainment');
  });

  test('keeps the newest ${ShopMemory.keep} shops', () async {
    final m = ShopMemory();
    for (var i = 0; i <= ShopMemory.keep; i++) {
      await m.remember('t1', 's$i@ybl', 'Other');
    }
    expect(m.categoryFor('t1', 's0@ybl'), isNull);
    expect(m.categoryFor('t1', 's1@ybl'), 'Other');
    expect(m.categoryFor('t1', 's${ShopMemory.keep}@ybl'), 'Other');
  });
}
