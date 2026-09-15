import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/validators.dart';
import '../../data/repositories/shop_repository.dart';
import 'auth_controller.dart';

class OtpScreen extends StatefulWidget {
  final String phone;
  final String role;
  final String? name;
  // Populated when the backend couldn't/didn't send a real SMS (its
  // textbee credentials aren't configured) and handed the code back
  // directly instead -- see HttpAuthRepository.sendOtp. Null means a
  // real SMS should have gone out.
  final String? debugOtp;
  const OtpScreen({
    super.key,
    required this.phone,
    required this.role,
    this.name,
    this.debugOtp,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Dev-mode convenience: pre-fill the code the backend handed back so
    // there's nothing to copy-paste. Still fully editable/visible.
    if (widget.debugOtp != null) {
      _otpController.text = widget.debugOtp!;
    }
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthController>();
    final success = await auth.verifyOtp(
      phone: widget.phone,
      otp: _otpController.text.trim(),
      role: widget.role,
      name: widget.name,
    );

    if (!mounted) return;

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? 'OTP verification failed')),
      );
      return;
    }

    if (widget.role == AppConstants.roleAdmin) {
      Navigator.pushNamedAndRemoveUntil(
          context, '/admin/dashboard', (route) => false);
      return;
    }

    if (widget.role == AppConstants.roleCustomer) {
      Navigator.pushNamedAndRemoveUntil(
          context, '/customer/home', (route) => false);
      return;
    }

    // Shopkeeper: route to shop setup if they don't have a shop yet.
    final shopRepo = context.read<ShopRepository>();
    final shop = await shopRepo.getShopByOwnerId(auth.currentUser!.id);
    if (!mounted) return;

    if (shop == null) {
      Navigator.pushNamedAndRemoveUntil(
          context, '/shopkeeper/shop-setup', (route) => false);
    } else {
      Navigator.pushNamedAndRemoveUntil(
          context, '/shopkeeper/dashboard', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Verify OTP')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Text('OTP sent to +91 ${widget.phone}',
                  style:
                      const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(
                widget.debugOtp == null
                    ? 'Check your SMS inbox for the code.'
                    : 'Dev mode: no SMS gateway is configured, so the code is shown below instead of being texted.',
                style: const TextStyle(color: Colors.black54),
              ),
              if (widget.debugOtp != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.amber.shade800, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        'Your OTP: ${widget.debugOtp}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              TextFormField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: const InputDecoration(
                  hintText: '4-digit OTP',
                  counterText: '',
                ),
                validator: Validators.otp,
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
                    : const Text('Verify & Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}