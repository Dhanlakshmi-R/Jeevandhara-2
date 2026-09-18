import 'package:flutter/material.dart';
import '../models/market_price.dart';
import '../theme/colors.dart';

class MarketPricesSection extends StatelessWidget {
  final List<MarketPrice> prices;
  final VoidCallback onViewAll;

  const MarketPricesSection({
    super.key,
    required this.prices,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Today's Market Prices",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
              ),
              TextButton(onPressed: onViewAll, child: const Text('View all')),
            ],
          ),
          const Divider(height: 1, color: Color(0xFFE0DDD3)),
          for (final price in prices) _PriceRow(price: price),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final MarketPrice price;

  const _PriceRow({required this.price});

  @override
  Widget build(BuildContext context) {
    final trendColor = price.isRising ? AppColors.positive : AppColors.negative;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.cream,
            child: Text(price.emoji, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              price.crop,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textDark),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                price.priceLabel,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(
                    price.isRising ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 14,
                    color: trendColor,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${price.changePercent.abs().toStringAsFixed(1)}%',
                    style: TextStyle(fontSize: 12, color: trendColor, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}