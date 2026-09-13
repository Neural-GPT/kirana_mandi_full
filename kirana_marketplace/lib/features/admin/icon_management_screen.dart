import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/icon_registry.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/product_icon_model.dart';
import '../../data/repositories/icon_repository.dart';
import '../shared/widgets/empty_state.dart';

/// Lets the admin enable/disable rows in the icon library table. Adding a
/// brand-new icon *glyph* requires a new app build (see IconRegistry docs);
/// this screen manages which of the bundled icons are currently offered to
/// shopkeepers, plus their label/category metadata (PRD §11).
class IconManagementScreen extends StatefulWidget {
  const IconManagementScreen({super.key});

  @override
  State<IconManagementScreen> createState() => _IconManagementScreenState();
}

class _IconManagementScreenState extends State<IconManagementScreen> {
  List<ProductIconModel> _icons = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final icons =
        await context.read<IconRepository>().getAllIcons(activeOnly: false);
    if (!mounted) return;
    setState(() {
      _icons = icons;
      _loading = false;
    });
  }

  Future<void> _toggleActive(ProductIconModel icon) async {
    await context.read<IconRepository>().setActive(icon.id, !icon.isActive);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Icon Library')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _icons.isEmpty
              ? const EmptyState(
                  icon: Icons.emoji_symbols_outlined, title: 'No icons found')
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _icons.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final icon = _icons[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.background,
                          foregroundColor: AppColors.primary,
                          child: Icon(IconRegistry.iconFor(icon.id)),
                        ),
                        title: Text(icon.label),
                        subtitle: Text(icon.id,
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 11)),
                        trailing: Switch(
                          value: icon.isActive,
                          onChanged: (_) => _toggleActive(icon),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
