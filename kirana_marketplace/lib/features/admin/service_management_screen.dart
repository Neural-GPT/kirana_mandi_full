import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/service_model.dart';
import '../../data/repositories/service_repository.dart';
import '../shared/widgets/empty_state.dart';

class ServiceManagementScreen extends StatefulWidget {
  const ServiceManagementScreen({super.key});

  @override
  State<ServiceManagementScreen> createState() =>
      _ServiceManagementScreenState();
}

class _ServiceManagementScreenState extends State<ServiceManagementScreen> {
  final _uuid = const Uuid();
  List<ServiceModel> _services = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final services =
        await context.read<ServiceRepository>().getAllServices(activeOnly: false);
    if (!mounted) return;
    setState(() {
      _services = services;
      _loading = false;
    });
  }

  Future<void> _addService() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Service Type'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Service name'),
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
        .read<ServiceRepository>()
        .create(ServiceModel(id: _uuid.v4(), name: name));
    _load();
  }

  Future<void> _toggleActive(ServiceModel service) async {
    await context
        .read<ServiceRepository>()
        .setActive(service.id, !service.isActive);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Services')),
      floatingActionButton: FloatingActionButton(
        onPressed: _addService,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _services.isEmpty
              ? const EmptyState(
                  icon: Icons.miscellaneous_services_outlined,
                  title: 'No service types yet')
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                  itemCount: _services.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final service = _services[index];
                    return Card(
                      child: ListTile(
                        title: Text(service.name),
                        subtitle: Text(service.isActive ? 'Active' : 'Disabled',
                            style: TextStyle(
                                color: service.isActive
                                    ? AppColors.success
                                    : AppColors.danger)),
                        trailing: Switch(
                          value: service.isActive,
                          onChanged: (_) => _toggleActive(service),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
