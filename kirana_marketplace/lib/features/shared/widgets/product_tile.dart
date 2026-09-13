import 'package:flutter/material.dart';
import '../../../core/constants/icon_registry.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/product_model.dart';

class ProductTile extends StatelessWidget {
  final ProductModel product;
  final Widget? trailing;
  final String? subtitle;

  const ProductTile({
    super.key,
    required this.product,
    this.trailing,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(IconRegistry.iconFor(product.iconId),
                  color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(subtitle ?? product.unit,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                  if (!product.isAvailable)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text('Currently unavailable',
                          style: TextStyle(
                              color: AppColors.danger,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else
              Text(Formatters.rupees(product.price),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
