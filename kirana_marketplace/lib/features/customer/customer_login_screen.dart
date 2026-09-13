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

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthController>();
    final phone = _phoneController.text.trim();
    final name = _nameController.text.trim();
    await auth.sendOtp(phone);
    if (!mounted) return;
    Navigator.pushNamed(context, '/otp', arguments: {
      'phone': phone,
      'role': AppConstants.roleCustomer,
      'name': name,
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
            ],
          ),
        ),
      ),
    );
  }
}
