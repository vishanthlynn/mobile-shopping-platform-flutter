import '../domain/catalog.dart';
import '../domain/models.dart';
import 'catalog_seed.dart';
import 'crypto_util.dart';
import 'firebase_gate.dart';
import 'stores.dart';

class ProductRepository {
  ProductRepository({
    required this.meta,
    this.pageSize = 8,
    this.delay = const Duration(milliseconds: 280),
    List<Product>? products,
  }) : _products = products ?? seedProducts;

  final MetaStore meta;
  final int pageSize;
  final Duration delay;
  final List<Product> _products;

  List<Product> get all => mergeCatalog(_products, _readRemote());

  List<Product> featured() => all.where((product) => product.featured).toList();

  Product? findById(String id) {
    for (final product in all) {
      if (product.id == id) return product;
    }
    return null;
  }

  Future<PageSlice<Product>> fetch({
    required CatalogQuery query,
    required int page,
  }) async {
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    final filtered = applyCatalogQuery(all, query);
    _cacheSnapshot(filtered);
    return slicePage(filtered, page, pageSize);
  }

  void _cacheSnapshot(List<Product> products) {
    meta.put(
      'catalog_cache',
      products.map((product) => product.toMap()).toList(),
    );
    meta.put('catalog_cached_at', DateTime.now().toIso8601String());
  }

  List<Product> _readRemote() {
    final raw = meta.get<List<dynamic>>('remote_products');
    if (raw == null) return const [];
    return raw.whereType<Map>().map(Product.fromMap).toList();
  }

  int get cachedCount {
    final raw = meta.get<List<dynamic>>('catalog_cache');
    return raw?.length ?? 0;
  }
}

class AuthRepository {
  AuthRepository(this.store);

  final UserStore store;

  UserAccount? current() {
    final raw = store.readSession();
    if (raw == null) return null;
    return UserAccount.fromMap(raw);
  }

  Future<AuthResult> signIn(String email, String password) async {
    final normalized = email.trim().toLowerCase();
    if (!_validEmail(normalized) || password.isEmpty) {
      return const AuthResult.failure('Enter the email and password.');
    }
    final record = store.readUser(normalized);
    if (record == null || record['passwordHash'] != hashPassword(password)) {
      return const AuthResult.failure('Those credentials do not match an account.');
    }
    await FirebaseGate.mirrorSignIn(email: normalized, password: password);
    final account = UserAccount(
      id: record['id'] as String,
      name: record['name'] as String,
      email: normalized,
    );
    store.writeSession(account.toMap());
    return AuthResult.success(account);
  }

  Future<AuthResult> register(String name, String email, String password) async {
    final trimmedName = name.trim();
    final normalized = email.trim().toLowerCase();
    if (trimmedName.length < 2) {
      return const AuthResult.failure('Add the name you want on orders.');
    }
    if (!_validEmail(normalized)) {
      return const AuthResult.failure('Enter a valid email.');
    }
    if (password.length < 6) {
      return const AuthResult.failure('Use at least 6 characters.');
    }
    if (store.readUser(normalized) != null) {
      return const AuthResult.failure('An account with that email already exists.');
    }
    final account = UserAccount(
      id: newId('user'),
      name: trimmedName,
      email: normalized,
    );
    store.writeUser(normalized, {
      ...account.toMap(),
      'passwordHash': hashPassword(password),
    });
    await FirebaseGate.mirrorSignIn(email: normalized, password: password);
    store.writeSession(account.toMap());
    return AuthResult.success(account);
  }

  void signOut() {
    store.writeSession(null);
    FirebaseGate.signOut();
  }

  bool _validEmail(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }
}

class SyncService {
  SyncService({
    required this.meta,
    required this.orders,
    required this.products,
  });

  final MetaStore meta;
  final OrderStore orders;
  final ProductRepository products;

  Future<String> sync({required bool offline}) async {
    if (offline) {
      return 'Offline. Orders stay in Hive until you reconnect.';
    }
    final pending = orders.load().where((order) => !order.synced).toList();
    final report = await FirebaseGate.pushOrders(pending);
    if (report.syncedIds.isNotEmpty) {
      final next = orders.load().map((order) {
        if (report.syncedIds.contains(order.id)) return order.copyWith(synced: true);
        return order;
      }).toList();
      orders.save(next);
    }
    if (report.remoteProducts.isNotEmpty) {
      meta.put(
        'remote_products',
        report.remoteProducts.map((product) => product.toMap()).toList(),
      );
    }
    meta.put('last_sync', DateTime.now().toIso8601String());
    if (!report.firebaseReady) {
      final cached = products.cachedCount;
      return pending.isEmpty
          ? 'Catalog cache updated on this device ($cached items). Add Firebase config to sync to Firestore.'
          : '${pending.length} order(s) queued on device. Add Firebase config to push them to Firestore.';
    }
    return 'Synced ${report.syncedIds.length} order(s) to Firestore.';
  }
}
