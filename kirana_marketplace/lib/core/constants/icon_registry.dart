import 'package:flutter/material.dart';

/// The app never stores or uploads product images. Instead a product/shop
/// icon is referenced purely by a stable string id (e.g. "milk_01"), and
/// this registry maps that id to a bundled Material icon.
///
/// Only the icon *id* is persisted in the database (see [ProductIconModel]).
/// This map is the "asset" itself and ships inside the app binary, so
/// catalog creation never depends on uploads or blob storage (PRD §11 / §34).
///
/// The super admin's "manage icon library" screen manages rows in the
/// `icons` table (id, label, category) which must reference an id present
/// in this map. Extending the library ships a new app build; the id/label
/// metadata itself can still be edited freely via the admin dashboard.
class IconRegistry {
  IconRegistry._();

  static const Map<String, IconData> _icons = {
    // Groceries
    'rice_01': Icons.rice_bowl,
    'wheat_01': Icons.grass,
    'flour_01': Icons.inventory_2,
    'pulses_01': Icons.scatter_plot,
    'sugar_01': Icons.icecream_outlined,
    'oil_01': Icons.opacity,
    'spices_01': Icons.local_fire_department_outlined,

    // Dairy
    'milk_01': Icons.local_drink,
    'curd_01': Icons.icecream,
    'butter_01': Icons.square_rounded,
    'cheese_01': Icons.circle,
    'paneer_01': Icons.crop_square,

    // Personal care
    'soap_01': Icons.soap,
    'shampoo_01': Icons.shower,
    'toothpaste_01': Icons.medication_liquid,
    'toothbrush_01': Icons.brush,

    // Beverages
    'water_01': Icons.water_drop,
    'juice_01': Icons.local_bar,
    'soft_drink_01': Icons.bubble_chart,
    'tea_01': Icons.emoji_food_beverage,
    'coffee_01': Icons.coffee,

    // Produce
    'vegetables_01': Icons.eco,
    'fruits_01': Icons.apple,
    'onion_01': Icons.circle_outlined,
    'potato_01': Icons.egg,

    // Snacks
    'biscuits_01': Icons.cookie,
    'chips_01': Icons.fastfood,
    'namkeen_01': Icons.grain,
    'chocolate_01': Icons.cake,

    // Household
    'detergent_01': Icons.local_laundry_service,
    'cleaning_01': Icons.cleaning_services,
    'broom_01': Icons.brush_outlined,
    'bulb_01': Icons.lightbulb_outline,

    // Stationery
    'notebook_01': Icons.menu_book,
    'pen_01': Icons.edit,

    // Generic / fallback
    'generic_item_01': Icons.shopping_bag_outlined,
  };

  static const String fallbackId = 'generic_item_01';

  static IconData iconFor(String iconId) => _icons[iconId] ?? _icons[fallbackId]!;

  static bool exists(String iconId) => _icons.containsKey(iconId);

  static List<String> get allIds => _icons.keys.toList(growable: false);
}
