import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/region_model.dart';
import '../../data/repositories/region_repository.dart';
import '../shared/widgets/empty_state.dart';

class RegionManagementScreen extends StatefulWidget {
  const RegionManagementScreen({super.key});

  @override
  State<RegionManagementScreen> createState() => _RegionManagementScreenState();
}

class _RegionManagementScreenState extends State<RegionManagementScreen> {
  final _uuid = const Uuid();
  List<RegionModel> _regions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final regions =
        await context.read<RegionRepository>().getAllRegions(activeOnly: false);
    if (!mounted) return;
    setState(() {
      _regions = regions;
      _loading = false;
    });
  }

  Future<void> _addOrEditRegion({RegionModel? existing}) async {
    final controller = TextEditingController(text: existing?.name ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Add Region' : 'Rename Region'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Region name'),
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

    final repo = context.read<RegionRepository>();
    if (existing == null) {
      await repo.createRegion(RegionModel(id: _uuid.v4(), name: name));
    } else {
      await repo.updateRegion(existing.copyWith(name: name));
    }
    _load();
  }

  Future<void> _toggleActive(RegionModel region) async {
    await context
        .read<RegionRepository>()
        .setRegionActive(region.id, !region.isActive);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Regions')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEditRegion(),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _regions.isEmpty
              ? const EmptyState(
                  icon: Icons.map_outlined, title: 'No regions added yet')
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                  itemCount: _regions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final region = _regions[index];
                    return Card(
                      child: ListTile(
                        title: Text(region.name),
                        subtitle: Text(region.isActive ? 'Active' : 'Disabled',
                            style: TextStyle(
                                color: region.isActive
                                    ? AppColors.success
                                    : AppColors.danger)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () =>
                                  _addOrEditRegion(existing: region),
                            ),
                            Switch(
                              value: region.isActive,
                              onChanged: (_) => _toggleActive(region),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
