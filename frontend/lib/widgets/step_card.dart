import 'package:flutter/material.dart';
import 'package:jeevandhara2/theme/colors.dart';
import 'package:jeevandhara2/widgets/ui/cards.dart';
import 'package:jeevandhara2/widgets/ui/network_or_asset_image.dart';

class StepCard extends StatelessWidget {
  final String number;
  final String title;
  final String description;
  final IconData icon;
  final String? imageUrl;

  const StepCard({
    super.key,
    required this.number,
    required this.title,
    required this.description,
    required this.icon,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [c.primary, c.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  number,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              Icon(icon, color: c.primary, size: 22),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: TextStyle(
              fontSize: 13.5,
              color: c.textSecondary,
              height: 1.5,
            ),
          ),
          if (imageUrl != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 120,
                width: double.infinity,
                child: NetworkOrAssetImage(url: imageUrl, width: double.infinity, height: 120, fit: BoxFit.cover),
              ),
            ),
          ],
        ],
      ),
    );
  }
}