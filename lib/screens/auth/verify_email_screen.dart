import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_extensions.dart';
import '../../services/api_service.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String? email;
  final String? role;

  const VerifyEmailScreen({super.key, this.email, this.role});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  late final TextEditingController _codeController;
  late final TextEditingController _emailController;
  bool _isLoading = false;
  bool _resendLoading = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.email ?? '');
    _codeController = TextEditingController();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  String get _email => _emailController.text.trim();
  String get _role => widget.role ?? 'customer';

  Future<void> _verify() async {
    if (_email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email')),
      );
      return;
    }
    final code = _codeController.text.trim();
    if (code.isEmpty || code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the 6-digit code from your email')),
      );
      return;
    }
    setState(() => _isLoading = true);
    final result = await ApiService.verifyEmail(email: _email, code: code);
    setState(() => _isLoading = false);
    if (!mounted) return;
    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Email verified. You can now log in.')),
      );
      context.go('/login?role=$_role');
    } else {
      final err = result['error'];
      final msg = err is Map ? (err['message'] ?? err['error']) : err?.toString() ?? 'Invalid or expired code.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg.toString())),
      );
    }
  }

  Future<void> _resendCode() async {
    if (_email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email')),
      );
      return;
    }
    setState(() => _resendLoading = true);
    final result = await ApiService.resendVerificationCode(email: _email);
    setState(() => _resendLoading = false);
    if (!mounted) return;
    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'A new code has been sent to your email.')),
      );
    } else {
      final err = result['error'];
      final msg = err is Map ? (err['message'] ?? err['error']) : err?.toString() ?? 'Failed to resend code.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: 24 + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () => context.go('/login?role=$_role'),
                icon: Icon(Iconsax.arrow_left, color: context.foregroundColor),
              ),
              const SizedBox(height: 16),
              Text(
                'Verify your email',
                style: TextStyle(
                  color: context.foregroundColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the 6-digit code we sent to ${_email.isEmpty ? "your email" : _email}',
                style: TextStyle(
                  color: context.mutedForegroundColor,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 32),
              if (widget.email == null || widget.email!.isEmpty) ...[
                Text(
                  'Email',
                  style: TextStyle(color: context.mutedForegroundColor, fontSize: 14),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'your@email.com',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Iconsax.sms),
                  ),
                  style: TextStyle(color: context.foregroundColor),
                ),
                const SizedBox(height: 20),
              ],
              Text(
                'Verification code',
                style: TextStyle(color: context.mutedForegroundColor, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  hintText: '000000',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Iconsax.code),
                  counterText: '',
                ),
                style: TextStyle(color: context.foregroundColor, fontSize: 18, letterSpacing: 4),
              ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Verify and continue'),
                ),
              ).animate().fadeIn(duration: 300.ms, delay: 100.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: _resendLoading ? null : _resendCode,
                  child: _resendLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          "Didn't receive the code? Resend",
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ).animate().fadeIn(duration: 300.ms, delay: 150.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
            ],
          ),
        ),
      ),
    );
  }
}
