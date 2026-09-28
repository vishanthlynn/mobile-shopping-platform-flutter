import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories.dart';
import '../data/stores.dart';
import '../domain/catalog.dart';
import '../domain/models.dart';
import '../domain/payments.dart';

final userStoreProvider = Provider<UserStore>((ref) => MemoryUserStore());
final cartStoreProvider = Provider<CartStore>((ref) => MemoryCartStore());
final orderStoreProvider = Provider<OrderStore>((ref) => MemoryOrderStore());
final metaStoreProvider = Provider<MetaStore>((ref) => MemoryMetaStore());

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository(meta: ref.watch(metaStoreProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final store = ref.watch(userStoreProvider);
  ensureDemoUser(store);
  return AuthRepository(store);
});

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    meta: ref.watch(metaStoreProvider),
    orders: ref.watch(orderStoreProvider),
    products: ref.watch(productRepositoryProvider),
  );
});

final paymentServiceProvider = Provider<PaymentService>((ref) => const PaymentService());

final featuredProvider = Provider<List<Product>>((ref) {
  return ref.watch(productRepositoryProvider).featured();
});

class AuthState {
  const AuthState({this.user, this.busy = false, this.error});

  final UserAccount? user;
  final bool busy;
  final String? error;

  AuthState copyWith({
    UserAccount? user,
    bool clearUser = false,
    bool? busy,
    String? error,
    bool clearError = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      busy: busy ?? this.busy,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() => AuthState(user: ref.read(authRepositoryProvider).current());

  Future<bool> signIn(String email, String password) async {
    state = state.copyWith(busy: true, clearError: true);
    final result = await ref.read(authRepositoryProvider).signIn(email, password);
    if (!result.ok) {
      state = state.copyWith(busy: false, error: result.message);
      return false;
    }
    state = AuthState(user: result.user);
    return true;
  }

  Future<bool> register(String name, String email, String password) async {
    state = state.copyWith(busy: true, clearError: true);
    final result =
        await ref.read(authRepositoryProvider).register(name, email, password);
    if (!result.ok) {
      state = state.copyWith(busy: false, error: result.message);
      return false;
    }
    state = AuthState(user: result.user);
    return true;
  }

  void signOut() {
    ref.read(authRepositoryProvider).signOut();
    state = const AuthState();
  }
}

final authProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);

class CartController extends Notifier<List<CartLine>> {
  @override
  List<CartLine> build() => ref.read(cartStoreProvider).load();

  String? add(Product product, {int quantity = 1}) {
    final reserved = reservedQuantity(state, product.id);
    if (reserved + quantity > product.stock) {
      return 'Only ${product.stock} left of ${product.name}.';
    }
    final next = upsertLine(state, product, quantity);
    state = next;
    ref.read(cartStoreProvider).save(next);
    return null;
  }

  void setQty(String productId, int quantity) {
    final next = setQuantity(state, productId, quantity);
    state = next;
    ref.read(cartStoreProvider).save(next);
  }

  void clear() {
    state = [];
    ref.read(cartStoreProvider).save(const []);
  }
}

final cartProvider =
    NotifierProvider<CartController, List<CartLine>>(CartController.new);

final cartCountProvider = Provider<int>((ref) {
  return ref.watch(cartProvider).fold(0, (sum, line) => sum + line.quantity);
});

final pricingProvider = Provider<PriceBreakdown>((ref) {
  return priceLines(ref.watch(cartProvider));
});

class OrderController extends Notifier<List<ShopOrder>> {
  @override
  List<ShopOrder> build() {
    final orders = ref.read(orderStoreProvider).load();
    orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return orders;
  }

  void add(ShopOrder order) {
    final next = [order, ...state];
    state = next;
    ref.read(orderStoreProvider).save(next);
  }

  void replaceAll(List<ShopOrder> orders) {
    state = orders;
    ref.read(orderStoreProvider).save(orders);
  }
}

final orderProvider =
    NotifierProvider<OrderController, List<ShopOrder>>(OrderController.new);

class OfflineController extends Notifier<bool> {
  @override
  bool build() => ref.read(metaStoreProvider).get<bool>('offline') ?? false;

  void setOffline(bool value) {
    ref.read(metaStoreProvider).put('offline', value);
    state = value;
  }
}

final offlineProvider =
    NotifierProvider<OfflineController, bool>(OfflineController.new);

class CatalogState {
  const CatalogState({
    required this.items,
    required this.query,
    required this.hasMore,
    required this.nextPage,
    this.loadingMore = false,
    this.error,
  });

  final List<Product> items;
  final CatalogQuery query;
  final bool hasMore;
  final int nextPage;
  final bool loadingMore;
  final String? error;

  CatalogState copyWith({
    List<Product>? items,
    CatalogQuery? query,
    bool? hasMore,
    int? nextPage,
    bool? loadingMore,
    String? error,
    bool clearError = false,
  }) {
    return CatalogState(
      items: items ?? this.items,
      query: query ?? this.query,
      hasMore: hasMore ?? this.hasMore,
      nextPage: nextPage ?? this.nextPage,
      loadingMore: loadingMore ?? this.loadingMore,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class CatalogController extends AsyncNotifier<CatalogState> {
  @override
  Future<CatalogState> build() => _open(const CatalogQuery());

  Future<void> apply(CatalogQuery query) async {
    final previous = state.asData?.value;
    if (previous != null) {
      state = AsyncData(previous.copyWith(query: query, loadingMore: true, clearError: true));
    } else {
      state = const AsyncLoading();
    }
    state = AsyncData(await _open(query));
  }

  Future<void> setCategory(String? category) {
    final current = state.asData?.value.query ?? const CatalogQuery();
    final query = category == null || current.category == category
        ? current.copyWith(clearCategory: true)
        : current.copyWith(category: category);
    return apply(query);
  }

  Future<void> search(String text) {
    final current = state.asData?.value.query ?? const CatalogQuery();
    return apply(current.copyWith(text: text));
  }

  Future<void> refresh() {
    final current = state.asData?.value.query ?? const CatalogQuery();
    return apply(current);
  }

  Future<void> loadMore() async {
    final current = state.asData?.value;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncData(current.copyWith(loadingMore: true, clearError: true));
    try {
      final page = await ref.read(productRepositoryProvider).fetch(
            query: current.query,
            page: current.nextPage,
          );
      final latest = state.asData?.value ?? current;
      state = AsyncData(
        latest.copyWith(
          items: [...current.items, ...page.items],
          hasMore: page.hasMore,
          nextPage: page.nextPage,
          loadingMore: false,
        ),
      );
    } catch (error) {
      state = AsyncData(
        current.copyWith(loadingMore: false, error: error.toString()),
      );
    }
  }

  Future<CatalogState> _open(CatalogQuery query) async {
    final page = await ref.read(productRepositoryProvider).fetch(query: query, page: 0);
    return CatalogState(
      items: page.items,
      query: query,
      hasMore: page.hasMore,
      nextPage: page.nextPage,
    );
  }
}

final homeCatalogProvider =
    AsyncNotifierProvider<CatalogController, CatalogState>(CatalogController.new);

final searchCatalogProvider =
    AsyncNotifierProvider<CatalogController, CatalogState>(CatalogController.new);

final productProvider = Provider.family<Product?, String>((ref, id) {
  return ref.watch(productRepositoryProvider).findById(id);
});
