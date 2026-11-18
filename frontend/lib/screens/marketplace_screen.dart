import 'package:flutter/material.dart';

import 'package:jeevandhara2/models/product.dart';
import 'package:jeevandhara2/services/api_service.dart';
import 'package:jeevandhara2/services/marketplace_service.dart';
import 'package:jeevandhara2/theme/colors.dart';
import 'package:jeevandhara2/theme/locale.dart';
import 'package:jeevandhara2/widgets/layout.dart';
import 'package:jeevandhara2/widgets/ui/app_input.dart';
import 'package:jeevandhara2/widgets/ui/app_modal.dart';
import 'package:jeevandhara2/widgets/ui/buttons.dart';
import 'package:jeevandhara2/widgets/ui/cards.dart';
import 'package:jeevandhara2/widgets/ui/states.dart';

/// Community marketplace for farming inputs, read from `/marketplace`.
///
/// Rows are real: a product appears because somebody listed it, the price is
/// theirs, and `rating` is null until reviews exist — the card says "No
/// reviews" rather than drawing stars nobody earned. A buyer can add things to
/// a local cart, but checkout is explicitly not connected to an order endpoint
/// yet, so it never claims an order was placed.
class MarketplaceScreen extends StatefulWidget {
  /// Injectable for tests; a real run uses the default HTTP client.
  final MarketplaceService? service;

  const MarketplaceScreen({super.key, this.service});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  late final MarketplaceService _service =
      widget.service ?? MarketplaceService();

  final List<MarketplaceProduct> _products = [];
  final List<MarketplaceProduct> _cart = [];
  final TextEditingController _search = TextEditingController();
  String _category = 'All';
  bool _loading = true;
  String? _error;

  /// Null while logged out, which only hides the owner-only remove control.
  int? _userId;

  List<MarketplaceProduct> get _filtered {
    final base = _category == 'All'
        ? _products
        : _products
            .where((p) => p.category == _category)
            .toList(growable: false);
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return base;
    return base
        .where((p) =>
            p.name.toLowerCase().contains(q) ||
            p.category.toLowerCase().contains(q) ||
            (p.description?.toLowerCase().contains(q) ?? false))
        .toList(growable: false);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _search.addListener(() {
      if (mounted) setState(() {});
    });
    _reload();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final user = await ApiService().getCurrentUser();
      if (!mounted) return;
      setState(() => _userId = user.id);
    } on Exception {
      // Browsing is public; without a session we simply show no owner controls.
    }
  }

  Future<void> _reload() async {
    setState(() {
      _loading = _products.isEmpty;
      _error = null;
    });
    try {
      final products = await _service.products();
      if (!mounted) return;
      setState(() {
        _products
          ..clear()
          ..addAll(products);
        _loading = false;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _addToCart(MarketplaceProduct product) {
    setState(() => _cart.add(product));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product.name} added to cart'),
        duration: const Duration(seconds: 1),
        action:
            SnackBarAction(label: 'View cart', onPressed: () => _openCart()),
      ),
    );
  }

  void _openCart() {
    final cart = List<MarketplaceProduct>.from(_cart);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _CartScreen(cart: cart)),
    );
  }

  Future<void> _openListProduct() async {
    await showAppModal(
      context: context,
      title: 'List an input',
      child: _ListProductForm(
        service: _service,
        onDone: (product) async {
          Navigator.of(context).pop();
          if (!mounted) return;
          setState(() => _products.insert(0, product));
          _snack('${product.name} is listed on the marketplace.');
        },
      ),
    );
  }

  Future<void> _removeProduct(MarketplaceProduct product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this listing?'),
        content: Text(
          '${product.name} will stop showing on the marketplace. The row is '
          'kept server-side so your history is not lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.retire(product.id);
      if (!mounted) return;
      setState(() {
        _products.removeWhere((p) => p.id == product.id);
        _cart.removeWhere((p) => p.id == product.id);
      });
      _snack('${product.name} removed.');
    } on Exception catch (e) {
      if (mounted) _snack(e.toString(), error: true);
    }
  }

  Future<void> _openEditProduct(MarketplaceProduct product) async {
    await showAppModal(
      context: context,
      title: 'Edit input',
      child: _ListProductForm(
        service: _service,
        product: product,
        onDone: (updated) {
          Navigator.of(context).pop();
          if (!mounted) return;
          setState(() {
            final index = _products.indexWhere((p) => p.id == updated.id);
            if (index >= 0) _products[index] = updated;
          });
          _snack('${updated.name} updated.');
        },
      ),
    );
  }

  void _snack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? context.colors.danger : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final filtered = _filtered;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.str('marketplace'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: c.textSecondary,
                        letterSpacing: 0.4,
                      ),
                    ),
                    Text(
                      '${_products.length} ${_products.length == 1 ? 'input' : 'inputs'} listed',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: _loading ? null : _openListProduct,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('List', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 8),
              _CartButton(count: _cart.length, onTap: _openCart),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: AppTextField(
            controller: _search,
            label: 'Search inputs',
            icon: Icons.search,
          ),
        ),
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: MarketplaceProduct.categories
                .map((cat) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label:
                            Text(cat, style: const TextStyle(fontSize: 12.5)),
                        selected: _category == cat,
                        onSelected: (_) => setState(() => _category = cat),
                        selectedColor: c.primaryLight,
                        side: BorderSide(
                            color: _category == cat ? c.primary : c.border),
                        labelStyle: TextStyle(
                          color: _category == cat
                              ? c.primaryDark
                              : c.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
        Expanded(child: _body(filtered)),
      ],
    );
  }

  Widget _body(List<MarketplaceProduct> filtered) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: LoadingSkeleton(rows: 3),
      );
    }
    if (_error != null) {
      return EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Could not load the marketplace',
        subtitle: _error!,
        actionLabel: 'Try again',
        onAction: _reload,
      );
    }
    if (_products.isEmpty) {
      return EmptyState(
        icon: Icons.storefront_outlined,
        title: 'No inputs listed yet',
        subtitle: 'Be the first to list seed, fertiliser or a tool for your '
            'neighbours.',
        actionLabel: 'List an input',
        onAction: _openListProduct,
      );
    }
    if (filtered.isEmpty) {
      return EmptyState(
        icon: Icons.storefront_outlined,
        title: 'Nothing in this category',
        subtitle: 'Try another category, or list the first one.',
        actionLabel: 'List an input',
        onAction: _openListProduct,
      );
    }
    return RefreshIndicator(
      onRefresh: _reload,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 260,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.72,
        ),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final product = filtered[index];
          return _ProductCard(
            product: product,
            isOwner: product.isOwnedBy(_userId),
            onAdd: () => _addToCart(product),
            onEdit: () => _openEditProduct(product),
            onRemove: () => _removeProduct(product),
          );
        },
      ),
    );
  }
}

class _CartButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _CartButton({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: c.surfaceAlt,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(Icons.shopping_cart_outlined,
                  size: 21, color: c.textPrimary),
            ),
          ),
        ),
        if (count > 0)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: c.danger,
                shape: BoxShape.circle,
                border: Border.all(color: c.surface, width: 1.5),
              ),
              alignment: Alignment.center,
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  final MarketplaceProduct product;
  final bool isOwner;
  final VoidCallback onAdd;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const _ProductCard({
    required this.product,
    required this.isOwner,
    required this.onAdd,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [c.primaryLight, c.secondaryLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Center(
                      child: Text(product.emoji,
                          style: const TextStyle(fontSize: 42))),
                ),
                if (isOwner)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Material(
                          color: c.surface,
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: onEdit,
                            child: Padding(
                              padding: const EdgeInsets.all(5),
                              child: Icon(Icons.edit_outlined,
                                  size: 16, color: c.primary),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Material(
                          color: c.surface,
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: onRemove,
                            child: Padding(
                              padding: const EdgeInsets.all(5),
                              child: Icon(Icons.delete_outline,
                                  size: 16, color: c.danger),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: c.textPrimary,
                        ),
                      ),
                    ),
                    if (product.hasRating) ...[
                      const Icon(Icons.star,
                          size: 13, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 2),
                      Text(
                        product.rating!.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: c.textPrimary,
                        ),
                      ),
                    ] else
                      Text(
                        'No reviews',
                        style:
                            TextStyle(fontSize: 10.5, color: c.textSecondary),
                      ),
                  ],
                ),
                Text(
                  product.category,
                  style: TextStyle(fontSize: 11, color: c.textSecondary),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        product.priceLabel,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: c.primaryDark,
                        ),
                      ),
                    ),
                    Icon(
                      product.inStock ? Icons.check_circle : Icons.cancel,
                      size: 13,
                      color: product.inStock ? c.positive : c.danger,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 36,
                  child: product.inStock
                      ? FilledButton.icon(
                          onPressed: onAdd,
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.add_shopping_cart, size: 16),
                          label: const Text('Add to Cart',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600)),
                        )
                      : OutlinedButton(
                          onPressed: null,
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Out of stock',
                              style: TextStyle(fontSize: 12)),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Form for listing a farming input. Mirrors the tool-listing form: it posts to
/// the server and only reports success once the server has answered.
class _ListProductForm extends StatefulWidget {
  final MarketplaceService service;
  final MarketplaceProduct? product;
  final ValueChanged<MarketplaceProduct> onDone;

  const _ListProductForm(
      {required this.service, this.product, required this.onDone});

  @override
  State<_ListProductForm> createState() => _ListProductFormState();
}

class _ListProductFormState extends State<_ListProductForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _unit = TextEditingController(text: 'pack');
  final _description = TextEditingController();
  String _category = 'Seeds';
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    if (p != null) {
      _name.text = p.name;
      _price.text = p.price == p.price.roundToDouble()
          ? p.price.toInt().toString()
          : p.price.toString();
      _unit.text = p.unit;
      _category = p.category;
      _description.text = p.description ?? '';
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _unit.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final price = double.tryParse(_price.text.trim());
    if (price == null || price <= 0) {
      setState(() => _error = 'Enter a price greater than 0.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final MarketplaceProduct product;
      if (widget.product != null) {
        product = await widget.service.update(
          widget.product!.id,
          name: _name.text.trim(),
          price: price,
          category: _category,
          unit: _unit.text.trim().isEmpty ? 'pack' : _unit.text.trim(),
          description: _description.text.trim(),
        );
      } else {
        product = await widget.service.create(
          name: _name.text.trim(),
          price: price,
          category: _category,
          unit: _unit.text.trim().isEmpty ? 'pack' : _unit.text.trim(),
          description: _description.text.trim(),
        );
      }
      if (!mounted) return;
      widget.onDone(product);
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          AppTextField(
            controller: _name,
            label: 'Product name',
            icon: Icons.inventory_2_outlined,
            hint: 'e.g. Hybrid tomato seed',
            validator: (v) =>
                (v == null || v.trim().length < 2) ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: _price,
                  label: 'Price',
                  icon: Icons.currency_rupee,
                  keyboardType: TextInputType.number,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 110,
                child: AppTextField(
                  controller: _unit,
                  label: 'Unit',
                  icon: Icons.straighten,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppDropdownField(
            label: 'Category',
            icon: Icons.category_outlined,
            value: _category,
            items: MarketplaceProduct.sellCategories,
            onChanged: (v) => setState(() => _category = v ?? 'Seeds'),
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _description,
            label: 'Description (optional)',
            icon: Icons.notes,
            hint: 'Quality, brand, quantity available\u2026',
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(fontSize: 12.5, color: c.danger),
            ),
          ],
          const SizedBox(height: 20),
          AppPrimaryButton(
            label: _saving
                ? 'Saving\u2026'
                : (widget.product == null
                    ? 'List on marketplace'
                    : 'Save changes'),
            icon: Icons.storefront_outlined,
            loading: _saving,
            onPressed: _saving ? null : _submit,
          ),
        ],
      ),
    );
  }
}

class _CartScreen extends StatefulWidget {
  final List<MarketplaceProduct> cart;

  const _CartScreen({required this.cart});

  @override
  State<_CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<_CartScreen> {
  String _payment = 'Cash on delivery';
  String _delivery = 'Village pickup point';

  List<MarketplaceProduct> get _cart => widget.cart;

  double get _subtotal => _cart.fold(0, (sum, p) => sum + p.price);
  double get _deliveryFee => _delivery.contains('Home') ? 60 : 0;
  double get _total => _subtotal + _deliveryFee;

  /// Checkout has no order endpoint behind it yet, so it says so rather than
  /// pretending an order exists. Nothing is charged and the cart is kept.
  Future<void> _showCheckoutNotice() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ordering is not connected yet'),
        content: const Text(
          'The marketplace lists real inputs and prices, but there is no '
          'order endpoint behind checkout yet. Nothing has been sent to a '
          'seller and nothing will be charged. Your cart is kept so you can '
          'finish checking out once ordering is live.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Cart'),
        actions: const [
          Padding(padding: EdgeInsets.only(right: 12), child: ThemeToggle())
        ],
      ),
      body: _cart.isEmpty
          ? const EmptyState(
              icon: Icons.shopping_cart_outlined,
              title: 'Your cart is empty',
              subtitle: 'Browse the marketplace and add products.',
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final p in _cart)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppCard(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: c.primaryLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                                child: Text(p.emoji,
                                    style: const TextStyle(fontSize: 24))),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: c.textPrimary,
                                  ),
                                ),
                                Text(
                                  '${p.priceLabel} ${p.category}',
                                  style: TextStyle(
                                      fontSize: 11.5, color: c.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            p.priceLabel,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: c.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  'Payment method',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary),
                ),
                const SizedBox(height: 8),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final m in [
                        'Cash on delivery',
                        'UPI',
                        'Credit / Debit card'
                      ])
                        RadioListTile<String>(
                          dense: true,
                          value: m,
                          groupValue: _payment,
                          onChanged: (v) => setState(
                              () => _payment = v ?? 'Cash on delivery'),
                          activeColor: c.primary,
                          title:
                              Text(m, style: const TextStyle(fontSize: 13.5)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Delivery method',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary),
                ),
                const SizedBox(height: 8),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final d in ['Village pickup point', 'Home delivery'])
                        RadioListTile<String>(
                          dense: true,
                          value: d,
                          groupValue: _delivery,
                          onChanged: (v) => setState(
                              () => _delivery = v ?? 'Village pickup point'),
                          activeColor: c.primary,
                          title:
                              Text(d, style: const TextStyle(fontSize: 13.5)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppCard(
                  child: Column(
                    children: [
                      _CartBillRow(
                          label: 'Subtotal (${_cart.length} items)',
                          value: '\u20B9${_subtotal.toStringAsFixed(0)}'),
                      const Divider(height: 1),
                      _CartBillRow(
                          label: 'Delivery fee',
                          value: _deliveryFee == 0
                              ? 'Free'
                              : '\u20B9$_deliveryFee'),
                      const Divider(height: 1),
                      _CartBillRow(
                          label: 'Total',
                          value: '\u20B9${_total.toStringAsFixed(0)}',
                          bold: true),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Checkout is not connected to an order endpoint yet — this '
                  'cart is not sent to any seller.',
                  style: TextStyle(fontSize: 11.5, color: c.textSecondary),
                ),
                const SizedBox(height: 16),
                AppPrimaryButton(
                  label: 'Checkout \u2022 \u20B9${_total.toStringAsFixed(0)}',
                  icon: Icons.local_mall_outlined,
                  onPressed: _showCheckoutNotice,
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}

class _CartBillRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _CartBillRow(
      {required this.label, required this.value, this.bold = false});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = c.textPrimary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: bold ? 15.5 : 13.5,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                color: color,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: bold ? 15.5 : 13.5,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
