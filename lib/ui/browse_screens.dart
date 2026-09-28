import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/catalog_seed.dart';
import '../domain/catalog.dart';
import '../domain/models.dart';
import '../state/app_state.dart';
import 'theme.dart';
import 'widgets.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    if (position.pixels > position.maxScrollExtent - 320) {
      ref.read(homeCatalogProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(homeCatalogProvider);
    final featured = ref.watch(featuredProvider);
    final offline = ref.watch(offlineProvider);
    final user = ref.watch(authProvider).user;
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 1100 ? 4 : width >= 700 ? 3 : 2;

    return catalog.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ErrorRetry(
        message: '$error',
        onRetry: () => ref.invalidate(homeCatalogProvider),
      ),
      data: (state) {
        return RefreshIndicator(
          onRefresh: () => ref.read(homeCatalogProvider.notifier).refresh(),
          child: CustomScrollView(
            controller: _scroll,
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user == null ? 'Good to see you' : 'Hello, ${user.name.split(' ').first}',
                        style: const TextStyle(color: Color(0xFF6E675E)),
                      ),
                      const Text(
                        'Lumen',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                          color: ink,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (offline) const OfflineBanner(),
                      InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => context.go('/search'),
                        child: Ink(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          decoration: BoxDecoration(
                            color: card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: line),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.search, color: Color(0xFF6E675E)),
                              SizedBox(width: 8),
                              Text('Search the floor', style: TextStyle(color: Color(0xFF6E675E))),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 40,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _CategoryChip(
                              label: 'All',
                              selected: state.query.category == null,
                              onTap: () => ref.read(homeCatalogProvider.notifier).setCategory(null),
                            ),
                            for (final category in catalogCategories)
                              _CategoryChip(
                                label: category,
                                selected: state.query.category == category,
                                onTap: () => ref
                                    .read(homeCatalogProvider.notifier)
                                    .setCategory(category),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      const SectionLabel('On the table'),
                      SizedBox(
                        height: 210,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: featured.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final product = featured[index];
                            return SizedBox(
                              width: 160,
                              child: ProductCard(
                                product: product,
                                heroPrefix: 'feature',
                                onTap: () => context.push(
                                  '/product/${product.id}',
                                  extra: 'feature',
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SectionLabel('The floor'),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.62,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index >= state.items.length) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final product = state.items[index];
                      return ProductCard(
                        product: product,
                        heroPrefix: 'grid',
                        onTap: () => context.push('/product/${product.id}', extra: 'grid'),
                      );
                    },
                    childCount: state.items.length + (state.loadingMore ? 1 : 0),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        selectedColor: ink,
        labelStyle: TextStyle(
          color: selected ? paper : ink,
          fontWeight: FontWeight.w600,
        ),
        side: const BorderSide(color: line),
        backgroundColor: card,
      ),
    );
  }
}

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _scroll = ScrollController();
  final _text = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (!_scroll.hasClients) return;
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 280) {
        ref.read(searchCatalogProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    _text.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      ref.read(searchCatalogProvider.notifier).search(value);
    });
  }

  Future<void> _openFilters(CatalogQuery current) async {
    final next = await showModalBottomSheet<CatalogQuery>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _FilterSheet(initial: current),
    );
    if (next != null) {
      await ref.read(searchCatalogProvider.notifier).apply(next.copyWith(text: _text.text));
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(searchCatalogProvider);
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 1100 ? 4 : width >= 700 ? 3 : 2;

    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: catalog.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorRetry(
          message: '$error',
          onRetry: () => ref.invalidate(searchCatalogProvider),
        ),
        data: (state) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _text,
                        onChanged: _onChanged,
                        decoration: const InputDecoration(
                          hintText: 'Jackets, beans, lamps',
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: () => _openFilters(state.query),
                      icon: Badge(
                        isLabelVisible: state.query.activeFilterCount > 0,
                        label: Text('${state.query.activeFilterCount}'),
                        child: const Icon(Icons.tune),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: state.items.isEmpty
                    ? const Center(child: Text('Nothing matches that search.'))
                    : GridView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.62,
                        ),
                        itemCount: state.items.length + (state.loadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= state.items.length) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          final product = state.items[index];
                          return ProductCard(
                            product: product,
                            heroPrefix: 'search',
                            onTap: () => context.push(
                              '/product/${product.id}',
                              extra: 'search',
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.initial});

  final CatalogQuery initial;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late CatalogQuery _query = widget.initial;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Filter', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final category in catalogCategories)
                FilterChip(
                  label: Text(category),
                  selected: _query.category == category,
                  onSelected: (selected) {
                    setState(() {
                      _query = selected
                          ? _query.copyWith(category: category)
                          : _query.copyWith(clearCategory: true);
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Price', style: TextStyle(fontWeight: FontWeight.w700)),
          Wrap(
            spacing: 8,
            children: [
              _priceChip('Any', null, null),
              _priceChip('Under \$25', null, 25),
              _priceChip('\$25–\$75', 25, 75),
              _priceChip('\$75–\$150', 75, 150),
              _priceChip('\$150+', 150, null),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Rating', style: TextStyle(fontWeight: FontWeight.w700)),
          Wrap(
            spacing: 8,
            children: [
              _ratingChip('Any', 0),
              _ratingChip('4+', 4),
              _ratingChip('4.5+', 4.5),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Sort', style: TextStyle(fontWeight: FontWeight.w700)),
          Wrap(
            spacing: 8,
            children: [
              _sortChip('Featured', SortOption.featured),
              _sortChip('Price up', SortOption.priceLow),
              _sortChip('Price down', SortOption.priceHigh),
              _sortChip('Rating', SortOption.rating),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.pop(context, _query),
            child: const Text('Show results'),
          ),
        ],
      ),
    );
  }

  Widget _priceChip(String label, double? min, double? max) {
    final selected = _query.minPrice == min && _query.maxPrice == max;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() {
          _query = _query.copyWith(clearPrice: true);
          _query = CatalogQuery(
            text: _query.text,
            category: _query.category,
            minPrice: min,
            maxPrice: max,
            minRating: _query.minRating,
            sort: _query.sort,
          );
        });
      },
    );
  }

  Widget _ratingChip(String label, double rating) {
    return ChoiceChip(
      label: Text(label),
      selected: _query.minRating == rating,
      onSelected: (_) => setState(() => _query = _query.copyWith(minRating: rating)),
    );
  }

  Widget _sortChip(String label, SortOption sort) {
    return ChoiceChip(
      label: Text(label),
      selected: _query.sort == sort,
      onSelected: (_) => setState(() => _query = _query.copyWith(sort: sort)),
    );
  }
}

class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen({
    super.key,
    required this.productId,
    required this.heroPrefix,
  });

  final String productId;
  final String heroPrefix;

  @override
  ConsumerState<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  int _qty = 1;

  @override
  Widget build(BuildContext context) {
    final product = ref.watch(productProvider(widget.productId));
    if (product == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('That product is no longer on the floor.')),
      );
    }
    final wide = MediaQuery.sizeOf(context).width >= 800;
    final artwork = Hero(
      tag: '${widget.heroPrefix}-${product.id}',
      child: ProductArtwork(product: product, radius: 24),
    );
    final details = _Details(
      product: product,
      qty: _qty,
      onQty: (value) => setState(() => _qty = value),
      onAdd: () {
        final message = ref.read(cartProvider.notifier).add(product, quantity: _qty);
        final messenger = ScaffoldMessenger.of(context);
        if (message != null) {
          messenger.showSnackBar(SnackBar(content: Text(message)));
          return;
        }
        messenger.showSnackBar(SnackBar(content: Text('${product.name} added to cart')));
      },
    );
    return Scaffold(
      appBar: AppBar(title: Text(product.name)),
      body: wide
          ? Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Expanded(child: artwork),
                  const SizedBox(width: 28),
                  Expanded(child: details),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                AspectRatio(aspectRatio: 1.05, child: artwork),
                const SizedBox(height: 16),
                details,
              ],
            ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({
    required this.product,
    required this.qty,
    required this.onQty,
    required this.onAdd,
  });

  final Product product;
  final int qty;
  final ValueChanged<int> onQty;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(product.brand.toUpperCase(), style: const TextStyle(letterSpacing: 1.2, color: Color(0xFF6E675E))),
        const SizedBox(height: 6),
        Text(product.name, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: ink)),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(money(product.price), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
            const Icon(Icons.star, size: 16, color: Color(0xFFC6A15B)),
            Text('${product.rating.toStringAsFixed(1)} · ${product.reviewCount} reviews'),
          ],
        ),
        const SizedBox(height: 16),
        Text(product.description, style: const TextStyle(height: 1.4, fontSize: 16)),
        const SizedBox(height: 8),
        Text('${product.stock} in stock', style: const TextStyle(color: Color(0xFF6E675E))),
        const SizedBox(height: 16),
        Row(
          children: [
            IconButton.filledTonal(
              onPressed: qty > 1 ? () => onQty(qty - 1) : null,
              icon: const Icon(Icons.remove),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('$qty', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            IconButton.filledTonal(
              onPressed: qty < product.stock ? () => onQty(qty + 1) : null,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: onAdd, child: const Text('Add to cart')),
      ],
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
