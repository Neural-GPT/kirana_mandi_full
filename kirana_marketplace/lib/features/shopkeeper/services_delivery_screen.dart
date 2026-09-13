import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/service_model.dart';
import '../../data/models/shop_model.dart';
import '../../data/repositories/service_repository.dart';
import '../../data/repositories/shop_repository.dart';
import '../authentication/auth_controller.dart';

class ServicesDeliveryScreen extends StatefulWidget {
  final ShopModel shop;
  const ServicesDeliveryScreen({super.key, required this.shop});

  @override
  State<ServicesDeliveryScreen> createState() =>
      _ServicesDeliveryScreenState();
}

class _ServicesDeliveryScreenState extends State<ServicesDeliveryScreen> {
  List<ServiceModel> _allServices = [];
  final Set<String> _selectedServiceIds = {};

  late bool _homeDelivery;
  late final TextEditingController _radiusController;
  late final TextEditingController _feeController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _homeDelivery = widget.shop.homeDeliveryAvailable;
    _radiusController = TextEditingController(
        text: widget.shop.deliveryRadiusKm?.toString() ?? '');
    _feeController =
        TextEditingController(text: widget.shop.deliveryFee?.toString() ?? '');
    _load();
  }

  Future<void> _load() async {
    final serviceRepo = context.read<ServiceRepository>();
    final services = await serviceRepo.getAllServices();
    final shopServiceIds =
        await serviceRepo.getServiceIdsForShop(widget.shop.id);
    if (!mounted) return;
    setState(() {
      _allServices = services;
      _selectedServiceIds.addAll(shopServiceIds);
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final auth = context.read<AuthController>().currentUser!;
    final shopRepo = context.read<ShopRepository>();
    final serviceRepo = context.read<ServiceRepository>();

    try {
      final updated = widget.shop.copyWith(
        homeDeliveryAvailable: _homeDelivery,
        deliveryRadiusKm: _homeDelivery
            ? double.tryParse(_radiusController.text.trim())
            : null,
        deliveryFee: _homeDelivery
            ? double.tryParse(_feeController.text.trim())
            : null,
      );
      await shopRepo.updateShop(updated, requestingUserId: auth.id);
      await serviceRepo.setShopServices(
          widget.shop.id, _selectedServiceIds.toList());
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _radiusController.dispose();
    _feeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Services & Delivery')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Services Offered',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _allServices.map((s) {
              final selected = _selectedServiceIds.contains(s.id);
              return FilterChip(
                label: Text(s.name),
                selected: selected,
                onSelected: (val) {
                  setState(() {
                    if (val) {
                      _selectedServiceIds.add(s.id);
                    } else {
                      _selectedServiceIds.remove(s.id);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          const Text('Delivery',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Home delivery available'),
            value: _homeDelivery,
            onChanged: (v) => setState(() => _homeDelivery = v),
          ),
          if (_homeDelivery) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _radiusController,
              decoration:
                  const InputDecoration(labelText: 'Delivery radius (km)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _feeController,
              decoration: const InputDecoration(labelText: 'Delivery fee (₹)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Save'),
          ),
        ],
      ),
    );
  }
}
