import 'package:flutter/material.dart';
import '../../../core/constants/icon_registry.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/product_icon_model.dart';

/// Grid of selectable icons from the built-in library (PRD §11). Shopkeepers
/// pick one instead of uploading a product photo.
class IconPickerGrid extends StatelessWidget {
  final List<ProductIconModel> icons;
  final String? selectedIconId;
  final ValueChanged<String> onSelected;

  const IconPickerGrid({
    super.key,
    required this.icons,
    required this.selectedIconId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      itemCount: icons.length,
      itemBuilder: (context, index) {
        final icon = icons[index];
        final selected = icon.id == selectedIconId;
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onSelected(icon.id),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary.withOpacity(0.15)
                      : AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? AppColors.primary : AppColors.divider,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Icon(
                  IconRegistry.iconFor(icon.id),
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                icon.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10),
              ),
            ],
          ),
        );
      },
    );
  }
}
