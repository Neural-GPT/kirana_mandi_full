import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/env_config.dart';
import 'auth_controller.dart';

/// Admin login is deliberately NOT phone+OTP: the id and password are
/// preset by whoever deploys the app via `--dart-define` (see
/// EnvConfig), so there's a single owner-controlled door into the admin
/// dashboard that doesn't depend on an SMS gateway or a seeded phone
/// number.
class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;
  String? _formError;

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _formError = null);

    final auth = context.read<AuthController>();

    if (EnvConfig.useRemoteApi) {
      // The backend is the real authorization boundary once one exists
      // -- send the entered credentials straight to it rather than
      // checking them on-device first.
      final success = await auth.loginAdmin(
        adminId: _idController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      if (!success) {
        setState(() => _formError = auth.error ?? 'Could not log in. Try again.');
        return;
      }
      Navigator.pushNamedAndRemoveUntil(context, '/admin/dashboard', (route) => false);
      return;
    }

    if (!EnvConfig.isAdminLoginConfigured) {
      setState(() => _formError =
          'Admin login isn\'t configured yet. Set ADMIN_ID and ADMIN_PASSWORD '
          'via --dart-define when building/running the app.');
      return;
    }

    final idMatches = _idController.text.trim() == EnvConfig.adminId;
    final passwordMatches = _passwordController.text == EnvConfig.adminPassword;
    if (!idMatches || !passwordMatches) {
      setState(() => _formError = 'Incorrect id or password.');
      return;
    }

    final success = await auth.loginAdmin(
      adminId: _idController.text.trim(),
      password: _passwordController.text,
    );
    if (!mounted) return;
    if (!success) {
      setState(() => _formError = auth.error ?? 'Could not log in. Try again.');
      return;
    }
    Navigator.pushNamedAndRemoveUntil(context, '/admin/dashboard', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Login')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              const Text('Sign in with your admin credentials',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              const Text(
                'These are configured by whoever deployed this app -- not a '
                'phone number or OTP.',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _idController,
                decoration: const InputDecoration(labelText: 'Admin ID'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter the admin id' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    icon: Icon(_obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Enter the password' : null,
                onFieldSubmitted: (_) => _submit(),
              ),
              if (_formError != null) ...[
                const SizedBox(height: 12),
                Text(_formError!,
                    style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: auth.busy ? null : _submit,
                child: auth.busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Log In'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
