import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/validators.dart';
import '../../data/models/category_model.dart';
import '../../data/models/product_icon_model.dart';
import '../../data/models/product_model.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/icon_repository.dart';
import '../../data/repositories/product_repository.dart';
import '../authentication/auth_controller.dart';
import '../shared/widgets/icon_picker_grid.dart';

class ProductFormScreen extends StatefulWidget {
  final String shopId;
  final ProductModel? existingProduct;
  const ProductFormScreen({super.key, required this.shopId, this.existingProduct});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _unitController;
  late final TextEditingController _descController;

  String? _categoryId;
  String? _iconId;
  bool _isAvailable = true;
  bool _saving = false;

  List<CategoryModel> _categories = [];
  List<ProductIconModel> _icons = [];

  bool get _isEditing => widget.existingProduct != null;

  @override
  void initState() {
    super.initState();
    final p = widget.existingProduct;
    _nameController = TextEditingController(text: p?.name ?? '');
    _priceController = TextEditingController(text: p?.price.toString() ?? '');
    _unitController = TextEditingController(text: p?.unit ?? '');
    _descController = TextEditingController(text: p?.description ?? '');
    _categoryId = p?.categoryId;
    _iconId = p?.iconId;
    _isAvailable = p?.isAvailable ?? true;
    _load();
  }

  Future<void> _load() async {
    final categories = await context
        .read<CategoryRepository>()
        .getByType(AppConstants.categoryTypeProduct);
    final icons = await context.read<IconRepository>().getAllIcons();
    if (!mounted) return;
    setState(() {
      _categories = categories;
      _icons = icons;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_iconId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please choose an icon')));
      return;
    }
    setState(() => _saving = true);
    final auth = context.read<AuthController>().currentUser!;
    final productRepo = context.read<ProductRepository>();

    try {
      if (_isEditing) {
        final updated = widget.existingProduct!.copyWith(
          name: _nameController.text.trim(),
          categoryId: _categoryId,
          price: double.parse(_priceController.text.trim()),
          unit: _unitController.text.trim(),
          iconId: _iconId,
          isAvailable: _isAvailable,
          description: _descController.text.trim(),
        );
        await productRepo.updateProduct(updated, requestingUserId: auth.id);
      } else {
        final product = ProductModel(
          id: '',
          shopId: widget.shopId,
          name: _nameController.text.trim(),
          categoryId: _categoryId,
          price: double.parse(_priceController.text.trim()),
          unit: _unitController.text.trim(),
          iconId: _iconId!,
          isAvailable: _isAvailable,
          description: _descController.text.trim(),
        );
        await productRepo.createProduct(product, requestingUserId: auth.id);
      }
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _unitController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Product' : 'Add Product')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Product name'),
              validator: (v) => Validators.required(v, label: 'Product name'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _categoryId,
              decoration: const InputDecoration(labelText: 'Category'),
              items: _categories
                  .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                  .toList(),
              onChanged: (v) => setState(() => _categoryId = v),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _priceController,
                    decoration: const InputDecoration(labelText: 'Price (₹)'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: Validators.price,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _unitController,
                    decoration: const InputDecoration(
                        labelText: 'Unit', hintText: 'e.g. 1 kg, 500 ml'),
                    validator: (v) => Validators.required(v, label: 'Unit'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descController,
              decoration:
                  const InputDecoration(labelText: 'Description (optional)'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Available for sale'),
              value: _isAvailable,
              onChanged: (v) => setState(() => _isAvailable = v),
            ),
            const SizedBox(height: 16),
            const Text('Choose an icon',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            IconPickerGrid(
              icons: _icons,
              selectedIconId: _iconId,
              onSelected: (id) => setState(() => _iconId = id),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(_isEditing ? 'Save Changes' : 'Add Product'),
            ),
          ],
        ),
      ),
    );
  }
}
