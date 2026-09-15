import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/validators.dart';
import 'auth_controller.dart';

class PhoneEntryScreen extends StatefulWidget {
  final String role;
  const PhoneEntryScreen({super.key, required this.role});

  @override
  State<PhoneEntryScreen> createState() => _PhoneEntryScreenState();
}

class _PhoneEntryScreenState extends State<PhoneEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthController>();
    final phone = _phoneController.text.trim();
    final debugOtp = await auth.sendOtp(phone);
    if (!mounted) return;
    Navigator.pushNamed(context, '/otp', arguments: {
      'phone': phone,
      'role': widget.role,
      'debugOtp': debugOtp,
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.role == AppConstants.roleAdmin
        ? 'Admin Login'
        : 'Shopkeeper Login';
    final auth = context.watch<AuthController>();

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              const Text('Enter your phone number',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              const Text(
                "We'll send a one-time password to verify it's you.",
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 20),
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