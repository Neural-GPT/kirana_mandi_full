import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/run_guarded.dart';
import '../../core/utils/validators.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/admin_repository.dart';
import '../authentication/auth_controller.dart';
import '../shared/widgets/empty_state.dart';

/// Only reachable from the admin dashboard when the logged-in user is a
/// super admin (see AdminDashboardScreen). Lets them see every
/// admin/super-admin account and add new ones by phone number -- admin
/// accounts are never self-service signups (see AuthRepository).
class ManageAdminsScreen extends StatefulWidget {
  const ManageAdminsScreen({super.key});

  @override
  State<ManageAdminsScreen> createState() => _ManageAdminsScreenState();
}

class _ManageAdminsScreenState extends State<ManageAdminsScreen> {
  List<UserModel> _admins = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final admins = await context.read<AdminRepository>().getAllAdmins();
    if (!mounted) return;
    setState(() {
      _admins = admins;
      _loading = false;
    });
  }

  Future<void> _addAdmin() async {
    final phoneController = TextEditingController();
    final nameController = TextEditingController();
    String role = AppConstants.roleAdmin;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Admin'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text('Admin', style: TextStyle(fontSize: 13)),
                      value: AppConstants.roleAdmin,
                      groupValue: role,
                      onChanged: (v) => setDialogState(() => role = v!),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text('Super Admin', style: TextStyle(fontSize: 13)),
                      value: AppConstants.roleSuperAdmin,
                      groupValue: role,
                      onChanged: (v) => setDialogState(() => role = v!),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                final phoneError = Validators.phone(phoneController.text.trim());
                final nameError =
                    Validators.required(nameController.text.trim(), label: 'Name');
                if (phoneError != null || nameError != null) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(phoneError ?? nameError!)));
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (result != true || !mounted) return;

    final auth = context.read<AuthController>().currentUser!;
    final added = await runGuarded(
      context,
      () => context.read<AdminRepository>().addAdmin(
            phone: phoneController.text.trim(),
            name: nameController.text.trim(),
            role: role,
            addedByUserId: auth.id,
          ),
      successMessage: 'Admin added',
    );
    if (added != null) _load();
  }

  Future<void> _removeAdmin(UserModel admin) async {
    final auth = context.read<AuthController>().currentUser!;
    if (admin.id == auth.id) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You can't remove your own account.")));
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove admin?'),
        content: Text(
            '${admin.name ?? admin.phone} will lose admin access immediately.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true) return;

    await runGuarded(
      context,
      () => context
          .read<AdminRepository>()
          .removeAdmin(admin.id, requestedByRole: auth.role),
      successMessage: 'Admin removed',
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Admins')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addAdmin,
        icon: const Icon(Icons.person_add_alt_outlined),
        label: const Text('Add Admin'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _admins.isEmpty
              ? const EmptyState(
                  icon: Icons.admin_panel_settings_outlined,
                  title: 'No admins found')
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                  itemCount: _admins.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final admin = _admins[index];
                    final isSuper = admin.role == AppConstants.roleSuperAdmin;
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: (isSuper
                                  ? AppColors.accent
                                  : AppColors.primary)
                              .withOpacity(0.12),
                          foregroundColor:
                              isSuper ? AppColors.accent : AppColors.primary,
                          child: Icon(isSuper
                              ? Icons.shield_outlined
                              : Icons.admin_panel_settings_outlined),
                        ),
                        title: Text(admin.name?.isNotEmpty == true
                            ? admin.name!
                            : admin.phone),
                        subtitle: Text(
                            '${admin.phone} · ${isSuper ? 'Super Admin' : 'Admin'}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: AppColors.danger),
                          onPressed: () => _removeAdmin(admin),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
