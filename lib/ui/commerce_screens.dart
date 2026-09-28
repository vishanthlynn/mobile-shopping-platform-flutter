import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../data/firebase_gate.dart';
import '../data/stores.dart';
import '../domain/catalog.dart';
import '../domain/models.dart';
import '../domain/payments.dart';
import '../state/app_state.dart';
import 'theme.dart';
import 'widgets.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(cartProvider);
    final pricing = ref.watch(pricingProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Cart')),
      body: lines.isEmpty
          ? const Center(child: Text('Your bag is empty.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final line in lines) _CartTile(line: line),
                const SizedBox(height: 8),
                _TotalRow('Subtotal', money(pricing.subtotal)),
                _TotalRow('Shipping', pricing.shipping == 0 ? 'Free' : money(pricing.shipping)),
                _TotalRow('Tax', money(pricing.tax)),
                const Divider(),
                _TotalRow('Total', money(pricing.total), strong: true),
                const SizedBox(height: 8),
                const Text(
                  'Shipping is free over \$75.',
                  style: TextStyle(color: Color(0xFF6E675E)),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    final user = ref.read(authProvider).user;
                    if (user == null) {
                      context.push('/login', extra: '/checkout');
                      return;
                    }
                    context.push('/checkout');
                  },
                  child: const Text('Checkout'),
                ),
              ],
            ),
    );
  }
}

class _CartTile extends ConsumerWidget {
  const _CartTile({required this.line});

  final CartLine line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = ref.watch(productProvider(line.productId));
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            SizedBox(
              width: 72,
              height: 72,
              child: product == null
                  ? const ColoredBox(color: Color(0xFFE5DDD0))
                  : ProductArtwork(product: product, radius: 12),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(line.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(money(line.unitPrice), style: const TextStyle(color: Color(0xFF6E675E))),
                ],
              ),
            ),
            IconButton(
              onPressed: () => ref.read(cartProvider.notifier).setQty(line.productId, line.quantity - 1),
              icon: const Icon(Icons.remove),
            ),
            Text('${line.quantity}'),
            IconButton(
              onPressed: product != null && line.quantity < product.stock
                  ? () => ref.read(cartProvider.notifier).setQty(line.productId, line.quantity + 1)
                  : null,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow(this.label, this.value, {this.strong = false});

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
      fontSize: strong ? 18 : 15,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: style), Text(value, style: style)],
      ),
    );
  }
}

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _name = TextEditingController(text: demoName);
  final _line1 = TextEditingController(text: '18 Harbor Lane');
  final _city = TextEditingController(text: 'Portland');
  final _region = TextEditingController(text: 'OR');
  final _postal = TextEditingController(text: '97205');
  final _card = TextEditingController(text: '4242 4242 4242 4242');
  final _expiry = TextEditingController(
    text: '12/${((DateTime.now().year + 2) % 100).toString().padLeft(2, '0')}',
  );
  final _cvc = TextEditingController(text: '123');
  final _paypalEmail = TextEditingController(text: PaymentService.paypalSandboxEmail);
  final _paypalPassword = TextEditingController(text: PaymentService.paypalSandboxPassword);
  PaymentMethod _method = PaymentMethod.stripeTest;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _line1.dispose();
    _city.dispose();
    _region.dispose();
    _postal.dispose();
    _card.dispose();
    _expiry.dispose();
    _cvc.dispose();
    _paypalEmail.dispose();
    _paypalPassword.dispose();
    super.dispose();
  }

  Future<void> _place() async {
    final lines = ref.read(cartProvider);
    if (lines.isEmpty) {
      setState(() => _error = 'Your cart is empty.');
      return;
    }
    if ([_name, _line1, _city, _region, _postal].any((field) => field.text.trim().isEmpty)) {
      setState(() => _error = 'Complete the shipping address.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final pricing = priceLines(lines);
    final request = _method == PaymentMethod.stripeTest
        ? PaymentRequest.stripe(
            cardNumber: _card.text,
            expiry: _expiry.text,
            cvc: _cvc.text,
            amount: pricing.total,
          )
        : PaymentRequest.paypal(
            paypalEmail: _paypalEmail.text,
            paypalPassword: _paypalPassword.text,
            amount: pricing.total,
          );
    final receipt = ref.read(paymentServiceProvider).charge(request);
    if (!receipt.ok) {
      setState(() {
        _busy = false;
        _error = receipt.message;
      });
      return;
    }
    final offline = ref.read(offlineProvider);
    final order = ShopOrder(
      id: 'LM-${DateTime.now().millisecondsSinceEpoch}',
      createdAt: DateTime.now(),
      lines: lines,
      pricing: pricing,
      paymentMethod: _method.storageKey,
      paymentReference: receipt.reference,
      address: Address(
        fullName: _name.text.trim(),
        line1: _line1.text.trim(),
        city: _city.text.trim(),
        region: _region.text.trim(),
        postalCode: _postal.text.trim(),
      ),
      synced: false,
    );
    ref.read(orderProvider.notifier).add(order);
    ref.read(cartProvider.notifier).clear();
    await ref.read(syncServiceProvider).sync(offline: offline);
    final fresh = ref.read(orderStoreProvider).load()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    ref.read(orderProvider.notifier).replaceAll(fresh);
    if (!mounted) return;
    context.go('/order-success/${order.id}');
  }

  @override
  Widget build(BuildContext context) {
    final pricing = ref.watch(pricingProvider);
    final offline = ref.watch(offlineProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Ship to', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Full name')),
          const SizedBox(height: 10),
          TextField(controller: _line1, decoration: const InputDecoration(labelText: 'Address')),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: TextField(controller: _city, decoration: const InputDecoration(labelText: 'City'))),
              const SizedBox(width: 10),
              SizedBox(
                width: 80,
                child: TextField(controller: _region, decoration: const InputDecoration(labelText: 'State')),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 110,
                child: TextField(controller: _postal, decoration: const InputDecoration(labelText: 'Postal')),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Test payment', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            offline
                ? 'You are offline. The test payment is captured on this device and queued for Firestore.'
                : 'No live charge. Stripe and PayPal run in test mode.',
            style: const TextStyle(color: Color(0xFF6E675E)),
          ),
          const SizedBox(height: 12),
          SegmentedButton<PaymentMethod>(
            segments: const [
              ButtonSegment(value: PaymentMethod.stripeTest, label: Text('Stripe'), icon: Icon(Icons.credit_card)),
              ButtonSegment(value: PaymentMethod.paypalTest, label: Text('PayPal'), icon: Icon(Icons.account_balance_wallet_outlined)),
            ],
            selected: {_method},
            onSelectionChanged: (value) => setState(() => _method = value.first),
          ),
          const SizedBox(height: 12),
          if (_method == PaymentMethod.stripeTest) ...[
            TextField(controller: _card, decoration: const InputDecoration(labelText: 'Card number')),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: TextField(controller: _expiry, decoration: const InputDecoration(labelText: 'MM/YY'))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: _cvc, decoration: const InputDecoration(labelText: 'CVC'))),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Success 4242 4242 4242 4242. Decline 4000 0000 0000 0002.',
              style: TextStyle(fontSize: 12, color: Color(0xFF6E675E)),
            ),
          ] else ...[
            TextField(controller: _paypalEmail, decoration: const InputDecoration(labelText: 'Sandbox email')),
            const SizedBox(height: 10),
            TextField(
              controller: _paypalPassword,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Sandbox password'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Sandbox buyer buyer@lumen.test / sandbox.',
              style: TextStyle(fontSize: 12, color: Color(0xFF6E675E)),
            ),
          ],
          const SizedBox(height: 16),
          _TotalRow('Due today', money(pricing.total), strong: true),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: clay)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _place,
            child: Text(_busy ? 'Placing order…' : 'Place test order'),
          ),
        ],
      ),
    );
  }
}

class OrderSuccessScreen extends ConsumerWidget {
  const OrderSuccessScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(orderProvider).where((item) => item.id == orderId).firstOrNull;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.asset(
                'assets/lottie/success.json',
                height: 180,
                repeat: false,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.check_circle, color: moss, size: 96),
              ),
              const SizedBox(height: 8),
              const Text(
                'Order placed',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: ink),
              ),
              const SizedBox(height: 8),
              Text(orderId, style: const TextStyle(color: Color(0xFF6E675E))),
              if (order != null) ...[
                const SizedBox(height: 8),
                Text(
                  '${order.paymentMethod} · ${order.paymentReference}',
                  textAlign: TextAlign.center,
                ),
                Text(money(order.pricing.total), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => context.go('/orders'),
                child: const Text('View orders'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(orderProvider);
    final offline = ref.watch(offlineProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Orders')),
      body: orders.isEmpty
          ? const Center(child: Text('No orders yet.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (offline) const OfflineBanner(),
                for (final order in orders)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      title: Text(order.id, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                        '${order.itemCount} items · ${order.address.city} · ${order.synced ? 'synced' : 'saved on device'}',
                      ),
                      trailing: Text(money(order.pricing.total)),
                    ),
                  ),
              ],
            ),
    );
  }
}

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String? _syncMessage;
  bool _syncing = false;

  Future<void> _sync() async {
    setState(() => _syncing = true);
    final message = await ref.read(syncServiceProvider).sync(offline: ref.read(offlineProvider));
    final fresh = ref.read(orderStoreProvider).load()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    ref.read(orderProvider.notifier).replaceAll(fresh);
    if (mounted) {
      setState(() {
        _syncing = false;
        _syncMessage = message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final offline = ref.watch(offlineProvider);
    final pending = ref.watch(orderProvider).where((order) => !order.synced).length;
    final cached = ref.watch(productRepositoryProvider).cachedCount;
    return Scaffold(
      appBar: AppBar(title: const Text('You')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: ink,
                child: Text(
                  user?.initials ?? 'L',
                  style: const TextStyle(color: paper, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.name ?? 'Guest',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    Text(user?.email ?? 'Sign in to check out'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Simulate offline'),
                  subtitle: const Text('Hive keeps the cart, orders, and catalog cache.'),
                  value: offline,
                  onChanged: (value) => ref.read(offlineProvider.notifier).setOffline(value),
                ),
                ListTile(
                  title: const Text('Firestore sync'),
                  subtitle: Text(
                    FirebaseGate.ready
                        ? 'Firebase is connected.'
                        : 'Firebase config not found. Orders queue on device.',
                  ),
                  trailing: _syncing
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.sync),
                  onTap: _syncing ? null : _sync,
                ),
                ListTile(
                  title: const Text('Queued orders'),
                  trailing: Text('$pending'),
                ),
                ListTile(
                  title: const Text('Cached products'),
                  trailing: Text('$cached'),
                ),
              ],
            ),
          ),
          if (_syncMessage != null) ...[
            const SizedBox(height: 12),
            Text(_syncMessage!),
          ],
          const SizedBox(height: 16),
          if (user == null)
            FilledButton(
              onPressed: () => context.push('/login'),
              child: const Text('Sign in'),
            )
          else
            OutlinedButton(
              onPressed: () => ref.read(authProvider.notifier).signOut(),
              child: const Text('Sign out'),
            ),
        ],
      ),
    );
  }
}
