import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/category_model.dart';
import '../../data/repositories/category_repository.dart';
import '../shared/widgets/empty_state.dart';

class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  State<CategoryManagementScreen> createState() =>
      _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _uuid = const Uuid();

  List<CategoryModel> _shopCategories = [];
  List<CategoryModel> _productCategories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final repo = context.read<CategoryRepository>();
    final shopCats =
        await repo.getByType(AppConstants.categoryTypeShop, activeOnly: false);
    final productCats = await repo.getByType(AppConstants.categoryTypeProduct,
        activeOnly: false);
    if (!mounted) return;
    setState(() {
      _shopCategories = shopCats;
      _productCategories = productCats;
      _loading = false;
    });
  }

  Future<void> _addCategory(String type) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Category'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Category name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await context
        .read<CategoryRepository>()
        .create(CategoryModel(id: _uuid.v4(), name: name, type: type));
    _load();
  }

  Future<void> _toggleActive(CategoryModel category) async {
    await context
        .read<CategoryRepository>()
        .setActive(category.id, !category.isActive);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildList(List<CategoryModel> categories) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (categories.isEmpty) {
      return const EmptyState(
          icon: Icons.category_outlined, title: 'No categories yet');
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      itemCount: categories.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final category = categories[index];
        return Card(
          child: ListTile(
            title: Text(category.name),
            subtitle: Text(category.isActive ? 'Active' : 'Disabled',
                style: TextStyle(
                    color: category.isActive
                        ? AppColors.success
                        : AppColors.danger)),
            trailing: Switch(
              value: category.isActive,
              onChanged: (_) => _toggleActive(category),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Categories'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Shop Categories'),
            Tab(text: 'Product Categories'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addCategory(
          _tabController.index == 0
              ? AppConstants.categoryTypeShop
              : AppConstants.categoryTypeProduct,
        ),
        child: const Icon(Icons.add),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildList(_shopCategories),
          _buildList(_productCategories),
        ],
      ),
    );
  }
}
