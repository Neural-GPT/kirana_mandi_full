import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/validators.dart';
import '../authentication/auth_controller.dart';

/// Customers now log in too (previously they could browse with no
/// account at all). We ask for their name up front -- separately from
/// the phone+OTP step -- so every order/cart entry can show a real name
/// instead of just a phone number, and so the app can greet them by name.
class CustomerLoginScreen extends StatefulWidget {
  const CustomerLoginScreen({super.key});

  @override
  State<CustomerLoginScreen> createState() => _CustomerLoginScreenState();
}

class _CustomerLoginScreenState extends State<CustomerLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _showWakingUpHint = false;
  Timer? _hintTimer;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _hintTimer?.cancel();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthController>();
    final phone = _phoneController.text.trim();
    final name = _nameController.text.trim();

    // Most of the time this returns in well under a second. When it
    // doesn't, it's almost always the backend waking up from an idle
    // spin-down (see ApiClient's timeout comment) rather than anything
    // actually wrong -- say so after a few seconds instead of leaving a
    // bare spinner that looks stuck or broken.
    setState(() => _showWakingUpHint = false);
    _hintTimer?.cancel();
    _hintTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showWakingUpHint = true);
    });

    final debugOtp = await auth.sendOtp(phone);
    _hintTimer?.cancel();
    if (!mounted) return;
    setState(() => _showWakingUpHint = false);
    if (auth.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(auth.error!)));
      return;
    }
    Navigator.pushNamed(context, '/otp', arguments: {
      'phone': phone,
      'role': AppConstants.roleCustomer,
      'name': name,
      'debugOtp': debugOtp,
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Customer Login')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              const Text('Tell us who you are',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              const Text(
                "We'll send an OTP to your phone to verify it's you.",
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Your name'),
                validator: (v) => Validators.required(v, label: 'Name'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                decoration: const InputDecoration(
                  prefixText: '+91  ',
                  hintText: '10-digit mobile number',
                  counterText: '',
                ),
                validator: Validators.phone,
              ),
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
                    : const Text('Send OTP'),
              ),
              if (_showWakingUpHint) ...[
                const SizedBox(height: 12),
                const Text(
                  'Connecting to the server -- this can take a little longer '
                  'right after a period of inactivity.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}