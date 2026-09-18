import 'package:flutter/material.dart';
import '../models/product.dart';
import '../theme/colors.dart';
import '../theme/locale.dart';
import '../widgets/layout.dart';
import '../widgets/ui/buttons.dart';
import '../widgets/ui/cards.dart';
import '../widgets/ui/states.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  final List<MarketplaceProduct> _products = MarketplaceProduct.sampleData();
  String _category = 'All';
  final List<MarketplaceProduct> _cart = [];

  List<MarketplaceProduct> get _filtered =>
      _category == 'All' ? _products : _products.where((p) => p.category == _category).toList();

  void _addToCart(MarketplaceProduct product) {
    setState(() => _cart.add(product));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product.name} added to cart'),
        duration: const Duration(seconds: 1),
        action: SnackBarAction(label: 'View cart', onPressed: () => _openCart()),
      ),
    );
  }

  void _openCart() {
    final cart = List<MarketplaceProduct>.from(_cart);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _CartScreen(cart: cart)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return _products.isEmpty
        ? const EmptyState(
            icon: Icons.storefront_outlined,
            title: 'No products here yet',
            subtitle: 'Products from verified dealers will appear soon.',
          )
        : Column(
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
                            'Farming inputs & supplies',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: c.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _CartButton(count: _cart.length, onTap: _openCart),
                  ],
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
                              label: Text(cat, style: const TextStyle(fontSize: 12.5)),
                              selected: _category == cat,
                              onSelected: (_) => setState(() => _category = cat),
                              selectedColor: c.primaryLight,
                              side: BorderSide(color: _category == cat ? c.primary : c.border),
                              labelStyle: TextStyle(
                                color: _category == cat ? c.primaryDark : c.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ),
              Expanded(
                child: _filtered.isEmpty
                    ? const EmptyState(
                        icon: Icons.storefront_outlined,
                        title: 'No products in this category',
                        subtitle: 'Try another category.',
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 260,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.74,
                        ),
                        itemCount: _filtered.length,
                        itemBuilder: (context, index) => _ProductCard(
                          product: _filtered[index],
                          onAdd: () => _addToCart(_filtered[index]),
                        ),
                      ),
              ),
            ],
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
              child: Icon(Icons.shopping_cart_outlined, size: 21, color: c.textPrimary),
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
  final VoidCallback onAdd;

  const _ProductCard({required this.product, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [c.primaryLight, c.secondaryLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Center(child: Text(product.emoji, style: const TextStyle(fontSize: 42))),
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
                    const Icon(Icons.star, size: 13, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 2),
                    Text(
                      product.rating.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                      ),
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
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.add_shopping_cart, size: 16),
                          label: const Text('Add to Cart', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        )
                      : OutlinedButton(
                          onPressed: null,
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Out of stock', style: TextStyle(fontSize: 12)),
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

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Cart'),
        actions: const [Padding(padding: EdgeInsets.only(right: 12), child: ThemeToggle())],
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
                            child: Center(child: Text(p.emoji, style: const TextStyle(fontSize: 24))),
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
                                  style: TextStyle(fontSize: 11.5, color: c.textSecondary),
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
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.textPrimary),
                ),
                const SizedBox(height: 8),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final m in ['Cash on delivery', 'UPI', 'Credit / Debit card'])
                        RadioListTile<String>(
                          dense: true,
                          value: m,
                          groupValue: _payment,
                          onChanged: (v) => setState(() => _payment = v ?? 'Cash on delivery'),
                          activeColor: c.primary,
                          title: Text(m, style: const TextStyle(fontSize: 13.5)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Delivery method',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.textPrimary),
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
                          onChanged: (v) => setState(() => _delivery = v ?? 'Village pickup point'),
                          activeColor: c.primary,
                          title: Text(d, style: const TextStyle(fontSize: 13.5)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppCard(
                  child: Column(
                    children: [
                      _CartBillRow(label: 'Subtotal (${_cart.length} items)', value: '\u20B9${_subtotal.toStringAsFixed(0)}'),
                      const Divider(height: 1),
                      _CartBillRow(label: 'Delivery fee', value: _deliveryFee == 0 ? 'Free' : '\u20B9$_deliveryFee'),
                      const Divider(height: 1),
                      _CartBillRow(label: 'Total', value: '\u20B9${_total.toStringAsFixed(0)}', bold: true),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                AppPrimaryButton(
                  label: 'Place Order \u2022 \u20B9${_total.toStringAsFixed(0)}',
                  icon: Icons.local_mall_outlined,
                  onPressed: () {
                    setState(() => widget.cart.clear());
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Order placed! Track it in Notifications.')),
                    );
                    Navigator.of(context).pop();
                  },
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

  const _CartBillRow({required this.label, required this.value, this.bold = false});

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