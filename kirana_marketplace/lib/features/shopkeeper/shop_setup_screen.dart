import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/run_guarded.dart';
import '../../core/utils/validators.dart';
import '../../data/models/category_model.dart';
import '../../data/models/region_model.dart';
import '../../data/models/shop_model.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/region_repository.dart';
import '../../data/repositories/shop_repository.dart';
import '../authentication/auth_controller.dart';

/// Handles both the first-time shop-creation flow and later profile edits
/// (PRD §7). When [existingShop] is null this is a "create" form; otherwise
/// it edits in place.
class ShopSetupScreen extends StatefulWidget {
  final ShopModel? existingShop;
  const ShopSetupScreen({super.key, this.existingShop});

  @override
  State<ShopSetupScreen> createState() => _ShopSetupScreenState();
}

class _ShopSetupScreenState extends State<ShopSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _ownerController;
  late final TextEditingController _phoneController;
  late final TextEditingController _altPhoneController;
  late final TextEditingController _descController;
  late final TextEditingController _latController;
  late final TextEditingController _lngController;
  late final TextEditingController _addressController;
  late final TextEditingController _logoUrlController;
  late final TextEditingController _bannerUrlController;

  String? _categoryId;
  String? _regionId;
  Color _primaryColor = AppColors.primary;
  Color? _secondaryColor;
  bool _saving = false;
  bool _locating = false;

  // A small curated palette rather than a full color picker -- keeps
  // branding simple for a shopkeeper who just wants "my shop looks like
  // this colour" without a native picker plugin dependency.
  static const _palette = <Color>[
    AppColors.primary,
    Color(0xFF1565C0), // blue
    Color(0xFF6A1B9A), // purple
    Color(0xFFAD1457), // pink
    AppColors.danger,
    Color(0xFFEF6C00), // orange
    Color(0xFFF9A825), // amber
    Color(0xFF00838F), // teal
    Color(0xFF37474F), // slate
  ];

  List<CategoryModel> _categories = [];
  List<RegionModel> _regions = [];

  bool get _isEditing => widget.existingShop != null;

  @override
  void initState() {
    super.initState();
    final shop = widget.existingShop;
    final auth = context.read<AuthController>().currentUser;

    _nameController = TextEditingController(text: shop?.name ?? '');
    _ownerController = TextEditingController(text: shop?.ownerName ?? '');
    _phoneController =
        TextEditingController(text: shop?.phone ?? auth?.phone ?? '');
    _altPhoneController = TextEditingController(text: shop?.altPhone ?? '');
    _descController = TextEditingController(text: shop?.description ?? '');
    _latController =
        TextEditingController(text: shop?.latitude?.toString() ?? '');
    _lngController =
        TextEditingController(text: shop?.longitude?.toString() ?? '');
    _addressController =
        TextEditingController(text: shop?.formattedAddress ?? '');
    _logoUrlController = TextEditingController(text: shop?.logoUrl ?? '');
    _bannerUrlController = TextEditingController(text: shop?.bannerUrl ?? '');
    _categoryId = shop?.categoryId;
    _regionId = shop?.regionId;
    _primaryColor = _parseHex(shop?.primaryColor) ?? AppColors.primary;
    _secondaryColor = _parseHex(shop?.secondaryColor);

    _loadOptions();
  }

  Color? _parseHex(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    var value = hex.trim();
    if (value.startsWith('#')) value = value.substring(1);
    if (value.length == 6) value = 'FF$value';
    final intValue = int.tryParse(value, radix: 16);
    return intValue == null ? null : Color(intValue);
  }

  String _toHex(Color color) =>
      '#${color.value.toRadixString(16).substring(2).toUpperCase()}';

  static const _addNewAreaValue = '__add_new_area__';

  Future<void> _loadOptions() async {
    final categories = await context
        .read<CategoryRepository>()
        .getByType(AppConstants.categoryTypeShop);
    final regions = await context.read<RegionRepository>().getAllRegions();
    if (!mounted) return;
    setState(() {
      _categories = categories;
      _regions = regions;
    });
  }

  /// Lets the shopkeeper either pick an area an admin (or another
  /// shopkeeper) already created, or type a brand new one. New areas are
  /// added to the same `regions` table admins manage, so they
  /// immediately show up for customers browsing "by Area" and for every
  /// other shopkeeper's dropdown too.
  Future<void> _addNewArea() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add a new area'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Area name',
            hintText: 'e.g. Trans Yamuna Colony',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;

    final region = await runGuarded(
      context,
      () => context.read<RegionRepository>().findOrCreateByName(name),
    );
    if (region == null || !mounted) return;

    setState(() {
      if (!_regions.any((r) => r.id == region.id)) {
        _regions = [..._regions, region]
          ..sort((a, b) => a.name.compareTo(b.name));
      }
      _regionId = region.id;
    });
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      final permission = await Geolocator.checkPermission();
      var granted = permission;
      if (permission == LocationPermission.denied) {
        granted = await Geolocator.requestPermission();
      }
      if (granted == LocationPermission.denied ||
          granted == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Location permission denied. Enter coordinates manually.')));
        }
        return;
      }
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Location services are off on this device.')));
        }
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      _latController.text = position.latitude.toStringAsFixed(6);
      _lngController.text = position.longitude.toStringAsFixed(6);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not fetch location. Enter it manually.')));
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_regionId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please select a region')));
      return;
    }

    setState(() => _saving = true);
    final auth = context.read<AuthController>().currentUser!;
    final shopRepo = context.read<ShopRepository>();

    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());

    try {
      if (_isEditing) {
        final updated = widget.existingShop!.copyWith(
          name: _nameController.text.trim(),
          ownerName: _ownerController.text.trim(),
          phone: _phoneController.text.trim(),
          altPhone: _altPhoneController.text.trim().isEmpty
              ? null
              : _altPhoneController.text.trim(),
          description: _descController.text.trim(),
          categoryId: _categoryId,
          regionId: _regionId,
          latitude: lat,
          longitude: lng,
          formattedAddress: _addressController.text.trim().isEmpty
              ? null
              : _addressController.text.trim(),
          logoUrl: _logoUrlController.text.trim(),
          bannerUrl: _bannerUrlController.text.trim(),
          primaryColor: _toHex(_primaryColor),
          secondaryColor: _secondaryColor == null ? '' : _toHex(_secondaryColor!),
        );
        var succeeded = false;
        await runGuarded<void>(
          context,
          () async {
            await shopRepo.updateShop(updated, requestingUserId: auth.id);
            succeeded = true;
          },
        );
        if (!succeeded) return; // error already shown by runGuarded
        if (mounted) Navigator.pop(context, true);
      } else {
        final shop = ShopModel(
          id: '',
          ownerUserId: auth.id,
          name: _nameController.text.trim(),
          ownerName: _ownerController.text.trim(),
          phone: _phoneController.text.trim(),
          altPhone: _altPhoneController.text.trim().isEmpty
              ? null
              : _altPhoneController.text.trim(),
          description: _descController.text.trim(),
          categoryId: _categoryId,
          regionId: _regionId!,
          latitude: lat,
          longitude: lng,
          formattedAddress: _addressController.text.trim().isEmpty
              ? null
              : _addressController.text.trim(),
          createdAt: '',
          logoUrl: _logoUrlController.text.trim().isEmpty
              ? null
              : _logoUrlController.text.trim(),
          bannerUrl: _bannerUrlController.text.trim().isEmpty
              ? null
              : _bannerUrlController.text.trim(),
          primaryColor: _toHex(_primaryColor),
          secondaryColor: _secondaryColor == null ? null : _toHex(_secondaryColor!),
        );
        final created = await runGuarded(context, () => shopRepo.createShop(shop));
        if (created == null) return; // error already shown by runGuarded
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
              context, '/shopkeeper/dashboard', (route) => false);
        }
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ownerController.dispose();
    _phoneController.dispose();
    _altPhoneController.dispose();
    _descController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _addressController.dispose();
    _logoUrlController.dispose();
    _bannerUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Shop' : 'Set Up Your Shop')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (!_isEditing)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'Tell customers about your shop. An admin will review and approve it before it goes live.',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            const _SectionLabel('Basic Information'),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Shop name'),
              validator: (v) => Validators.required(v, label: 'Shop name'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ownerController,
              decoration: const InputDecoration(labelText: 'Owner name'),
              validator: (v) => Validators.required(v, label: 'Owner name'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Phone number'),
              keyboardType: TextInputType.phone,
              validator: Validators.phone,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _altPhoneController,
              decoration: const InputDecoration(
                  labelText: 'Alternate phone (optional)'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descController,
              decoration: const InputDecoration(labelText: 'Shop description'),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _categoryId,
              decoration: const InputDecoration(labelText: 'Shop category'),
              items: _categories
                  .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                  .toList(),
              onChanged: (v) => setState(() => _categoryId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _regionId,
              decoration: const InputDecoration(
                labelText: 'Area',
                helperText:
                    "Pick your area, or add it if it isn't listed yet.",
              ),
              items: [
                ..._regions
                    .map((r) => DropdownMenuItem(value: r.id, child: Text(r.name))),
                const DropdownMenuItem(
                  value: _addNewAreaValue,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 18),
                      SizedBox(width: 6),
                      Text('Add a new area'),
                    ],
                  ),
                ),
              ],
              onChanged: (v) {
                if (v == _addNewAreaValue) {
                  _addNewArea();
                  return;
                }
                setState(() => _regionId = v);
              },
              validator: (v) =>
                  (v == null || v == _addNewAreaValue) ? 'Please select an area' : null,
            ),
            const SizedBox(height: 20),
            const _SectionLabel('Shop Location'),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _latController,
                    decoration: const InputDecoration(labelText: 'Latitude'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true, signed: true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _lngController,
                    decoration: const InputDecoration(labelText: 'Longitude'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true, signed: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _locating ? null : _useCurrentLocation,
              icon: _locating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location, size: 18),
              label: const Text('Use current location'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _addressController,
              decoration:
                  const InputDecoration(labelText: 'Address (optional)'),
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            const _SectionLabel('White-Label Branding'),
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Optional -- used to skin your own branded customer app '
                '(see App Deployment on your dashboard once your shop is set up).',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ),
            TextFormField(
              controller: _logoUrlController,
              decoration: const InputDecoration(
                labelText: 'Logo image URL (optional)',
                hintText: 'https://...',
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _bannerUrlController,
              decoration: const InputDecoration(
                labelText: 'Banner image URL (optional)',
                hintText: 'https://...',
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 14),
            const Text('Brand color',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _palette
                  .map((color) => _ColorSwatch(
                        color: color,
                        selected: color.value == _primaryColor.value,
                        onTap: () => setState(() => _primaryColor = color),
                      ))
                  .toList(),
            ),
            if (_isEditing && widget.existingShop!.shopCode.isNotEmpty) ...[
              const SizedBox(height: 20),
              const _SectionLabel('Shop Code'),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.existingShop!.shopCode,
                        style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            letterSpacing: 2),
                      ),
                    ),
                    const Text('Share this with customers',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(_isEditing ? 'Save Changes' : 'Submit for Approval'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _ColorSwatch({required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: selected
              ? Border.all(color: AppColors.textPrimary, width: 2.5)
              : null,
        ),
        child: selected
            ? const Icon(Icons.check, color: Colors.white, size: 18)
            : null,
      ),
    );
  }
}
