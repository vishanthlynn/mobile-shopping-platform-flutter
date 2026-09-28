import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_market/data/catalog_seed.dart';
import 'package:lumen_market/data/crypto_util.dart';
import 'package:lumen_market/data/repositories.dart';
import 'package:lumen_market/data/stores.dart';
import 'package:lumen_market/domain/catalog.dart';
import 'package:lumen_market/domain/payments.dart';

void main() {
  test('money formats thousands', () {
    expect(money(1234.5), '\$1,234.50');
    expect(money(8), '\$8.00');
  });

  test('catalog filters, sorts, and pages', () {
    expect(seedProducts.length, greaterThanOrEqualTo(24));
    final apparel = applyCatalogQuery(
      seedProducts,
      const CatalogQuery(category: 'Apparel', sort: SortOption.priceLow),
    );
    expect(apparel.every((product) => product.category == 'Apparel'), isTrue);
    expect(apparel.first.price, lessThanOrEqualTo(apparel.last.price));

    final search = applyCatalogQuery(
      seedProducts,
      const CatalogQuery(text: 'honey'),
    );
    expect(search.single.name, 'Wildflower Honey');

    final page = slicePage(seedProducts, 0, 8);
    expect(page.items, hasLength(8));
    expect(page.hasMore, isTrue);
    final last = slicePage(seedProducts, 20, 8);
    expect(last.items, isEmpty);
    expect(last.hasMore, isFalse);
  });

  test('merge prefers remote products', () {
    final remote = seedProducts.first.copyWithPrice(11);
    final merged = mergeCatalog(seedProducts, [remote]);
    expect(merged.firstWhere((product) => product.id == remote.id).price, 11);
    expect(merged, hasLength(seedProducts.length));
  });

  test('cart math respects quantity and free shipping', () {
    final product = seedProducts.first;
    final lines = upsertLine(const [], product, 2);
    expect(lines.single.quantity, 2);
    expect(setQuantity(lines, product.id, 0), isEmpty);
    final pricing = priceLines(lines);
    expect(pricing.subtotal, product.price * 2);
    expect(pricing.shipping, product.price * 2 >= 75 ? 0 : 6.5);
  });

  test('stripe and paypal test payments', () {
    const service = PaymentService();
    final year = ((DateTime.now().year + 1) % 100).toString().padLeft(2, '0');
    final ok = service.charge(
      PaymentRequest.stripe(
        cardNumber: '4242 4242 4242 4242',
        expiry: '12/$year',
        cvc: '123',
        amount: 40,
      ),
    );
    expect(ok.ok, isTrue);
    expect(ok.reference, startsWith('pi_test_'));

    final declined = service.charge(
      PaymentRequest.stripe(
        cardNumber: PaymentService.stripeDeclinePan,
        expiry: '12/$year',
        cvc: '123',
        amount: 40,
      ),
    );
    expect(declined.ok, isFalse);

    final paypal = service.charge(
      const PaymentRequest.paypal(
        paypalEmail: 'buyer@lumen.test',
        paypalPassword: 'sandbox',
        amount: 18,
      ),
    );
    expect(paypal.ok, isTrue);

    final badPaypal = service.charge(
      const PaymentRequest.paypal(
        paypalEmail: 'buyer@lumen.test',
        paypalPassword: 'nope',
        amount: 18,
      ),
    );
    expect(badPaypal.ok, isFalse);
  });

  test('demo account signs in and rejects a bad password', () async {
    final store = MemoryUserStore();
    ensureDemoUser(store);
    final auth = AuthRepository(store);
    final ok = await auth.signIn(demoEmail, demoPassword);
    expect(ok.ok, isTrue);
    expect(auth.current()?.email, demoEmail);

    final bad = await auth.signIn(demoEmail, 'wrong-password');
    expect(bad.ok, isFalse);

    final created = await auth.register('New Person', 'new.person@lumen.market', 'secret1');
    expect(created.ok, isTrue);
    expect(hashPassword('secret1'), isNot(contains('secret1')));
  });
}
