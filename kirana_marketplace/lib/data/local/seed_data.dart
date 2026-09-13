import 'package:sqflite/sqflite.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/icon_registry.dart';

/// Seeds reference/catalog data only -- categories, services, and the
/// product icon library. Regions (areas) and shops are deliberately NOT
/// seeded: every area now comes either from an admin (Region Management)
/// or from a shopkeeper naming their own area during shop setup, and
/// every shop comes from a real shopkeeper signup. Starting with an
/// empty marketplace is correct for a real deployment; ship demo
/// regions/shops separately (e.g. a debug-only seeding script) if you
/// need them for a walkthrough.
Future<void> seedDatabase(Database db) async {
  final batch = db.batch();

  // --- Shop categories ---
  const shopCategories = [
    ['cat_shop_general', 'General Store'],
    ['cat_shop_dairy', 'Dairy'],
    ['cat_shop_stationery', 'Stationery'],
    ['cat_shop_vegetables', 'Vegetables & Fruits'],
    ['cat_shop_pharmacy', 'Pharmacy'],
  ];
  for (final c in shopCategories) {
    batch.insert('categories', {
      'id': c[0],
      'name': c[1],
      'type': AppConstants.categoryTypeShop,
      'is_active': 1,
    });
  }

  // --- Product categories ---
  const productCategories = [
    ['cat_prod_grocery', 'Grocery'],
    ['cat_prod_dairy', 'Dairy'],
    ['cat_prod_fruits', 'Fruits'],
    ['cat_prod_vegetables', 'Vegetables'],
    ['cat_prod_snacks', 'Snacks'],
    ['cat_prod_beverages', 'Beverages'],
    ['cat_prod_personal_care', 'Personal Care'],
    ['cat_prod_household', 'Household'],
    ['cat_prod_stationery', 'Stationery'],
  ];
  for (final c in productCategories) {
    batch.insert('categories', {
      'id': c[0],
      'name': c[1],
      'type': AppConstants.categoryTypeProduct,
      'is_active': 1,
    });
  }

  // --- Services (PRD §9) ---
  const services = [
    ['svc_home_delivery', 'Home Delivery'],
    ['svc_bulk_orders', 'Bulk Orders'],
    ['svc_wholesale', 'Wholesale'],
    ['svc_phone_orders', 'Phone Orders'],
    ['svc_custom_orders', 'Custom Orders'],
  ];
  for (final s in services) {
    batch.insert('services', {'id': s[0], 'name': s[1], 'is_active': 1});
  }

  // --- Product icon library (PRD §11) ---
  final iconLabels = <String, String>{
    'rice_01': 'Rice',
    'wheat_01': 'Wheat',
    'flour_01': 'Flour / Atta',
    'pulses_01': 'Pulses / Dal',
    'sugar_01': 'Sugar',
    'oil_01': 'Cooking Oil',
    'spices_01': 'Spices',
    'milk_01': 'Milk',
    'curd_01': 'Curd',
    'butter_01': 'Butter',
    'cheese_01': 'Cheese',
    'paneer_01': 'Paneer',
    'soap_01': 'Soap',
    'shampoo_01': 'Shampoo',
    'toothpaste_01': 'Toothpaste',
    'toothbrush_01': 'Toothbrush',
    'water_01': 'Water',
    'juice_01': 'Juice',
    'soft_drink_01': 'Soft Drink',
    'tea_01': 'Tea',
    'coffee_01': 'Coffee',
    'vegetables_01': 'Vegetables',
    'fruits_01': 'Fruits',
    'onion_01': 'Onion',
    'potato_01': 'Potato',
    'biscuits_01': 'Biscuits',
    'chips_01': 'Chips',
    'namkeen_01': 'Namkeen',
    'chocolate_01': 'Chocolate',
    'detergent_01': 'Detergent',
    'cleaning_01': 'Cleaning Supplies',
    'broom_01': 'Broom',
    'bulb_01': 'Bulb / Electricals',
    'notebook_01': 'Notebook',
    'pen_01': 'Pen',
    'generic_item_01': 'Other Item',
  };
  final iconCategoryMap = <String, String>{
    'rice_01': 'cat_prod_grocery',
    'wheat_01': 'cat_prod_grocery',
    'flour_01': 'cat_prod_grocery',
    'pulses_01': 'cat_prod_grocery',
    'sugar_01': 'cat_prod_grocery',
    'oil_01': 'cat_prod_grocery',
    'spices_01': 'cat_prod_grocery',
    'milk_01': 'cat_prod_dairy',
    'curd_01': 'cat_prod_dairy',
    'butter_01': 'cat_prod_dairy',
    'cheese_01': 'cat_prod_dairy',
    'paneer_01': 'cat_prod_dairy',
    'soap_01': 'cat_prod_personal_care',
    'shampoo_01': 'cat_prod_personal_care',
    'toothpaste_01': 'cat_prod_personal_care',
    'toothbrush_01': 'cat_prod_personal_care',
    'water_01': 'cat_prod_beverages',
    'juice_01': 'cat_prod_beverages',
    'soft_drink_01': 'cat_prod_beverages',
    'tea_01': 'cat_prod_beverages',
    'coffee_01': 'cat_prod_beverages',
    'vegetables_01': 'cat_prod_vegetables',
    'fruits_01': 'cat_prod_fruits',
    'onion_01': 'cat_prod_vegetables',
    'potato_01': 'cat_prod_vegetables',
    'biscuits_01': 'cat_prod_snacks',
    'chips_01': 'cat_prod_snacks',
    'namkeen_01': 'cat_prod_snacks',
    'chocolate_01': 'cat_prod_snacks',
    'detergent_01': 'cat_prod_household',
    'cleaning_01': 'cat_prod_household',
    'broom_01': 'cat_prod_household',
    'bulb_01': 'cat_prod_household',
    'notebook_01': 'cat_prod_stationery',
    'pen_01': 'cat_prod_stationery',
  };

  for (final id in IconRegistry.allIds) {
    batch.insert('icons', {
      'id': id,
      'label': iconLabels[id] ?? id,
      'category_id': iconCategoryMap[id],
      'is_active': 1,
    });
  }

  await batch.commit(noResult: true);
}
