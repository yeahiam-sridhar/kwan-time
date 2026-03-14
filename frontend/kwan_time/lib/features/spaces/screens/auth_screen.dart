import 'package:flutter/material.dart';

import '../../../core/theme/kwan_colors.dart';
import '../services/auth_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  final _svc = AuthService();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isRegister = false;
  bool _loading = false;
  String? _error;

  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  )..forward();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _fade.dispose();
    super.dispose();
  }

  Future<void> _handleEmail() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Please fill all fields');
      return;
    }
    if (pass.length < 6) {
      setState(() => _error = 'Password must be 6+ characters');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_isRegister) {
        await _svc.registerWithEmail(email, pass);
      } else {
        await _svc.signInWithEmail(email, pass);
      }
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _error = _friendly(e.toString()));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _handleGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await _svc.signInWithGoogle();
      if (r != null && mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _error = _friendly(e.toString()));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _friendly(String raw) {
    if (raw.contains('user-not-found')) {
      return 'No account with that email.';
    }
    if (raw.contains('wrong-password')) {
      return 'Incorrect password.';
    }
    if (raw.contains('email-already')) {
      return 'Email already registered.';
    }
    if (raw.contains('network-request')) {
      return 'No internet connection.';
    }
    return 'Something went wrong. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KwanColors.surface,
      appBar: AppBar(
        backgroundColor: KwanColors.surface,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
      ),
      body: FadeTransition(
        opacity: _fade,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isRegister ? 'Create Account' : 'Welcome Back',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Sign in to sync shared calendar spaces.',
                  style: TextStyle(
                    color: KwanColors.white(0.45),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 36),
                _FullBtn(
                  icon: Icons.g_mobiledata,
                  label: 'Continue with Google',
                  onTap: _loading ? null : _handleGoogle,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(child: Divider(color: KwanColors.white(0.1))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'or',
                        style: TextStyle(
                          color: KwanColors.white(0.3),
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: KwanColors.white(0.1))),
                  ],
                ),
                const SizedBox(height: 24),
                _Field(
                  ctrl: _emailCtrl,
                  hint: 'Email',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                _Field(
                  ctrl: _passCtrl,
                  hint: 'Password',
                  icon: Icons.lock_outline,
                  obscure: true,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: KwanColors.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: KwanColors.error,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                _FullBtn(
                  label: _isRegister ? 'Create Account' : 'Sign In',
                  onTap: _loading ? null : _handleEmail,
                  loading: _loading,
                ),
                const SizedBox(height: 16),
                Center(
                  child: GestureDetector(
                    onTap: () => setState(() => _isRegister = !_isRegister),
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: _isRegister
                                ? 'Already have an account? '
                                : 'No account? ',
                            style: TextStyle(
                              color: KwanColors.white(0.45),
                              fontSize: 14,
                            ),
                          ),
                          TextSpan(
                            text: _isRegister ? 'Sign In' : 'Register',
                            style: const TextStyle(
                              color: KwanColors.primary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.ctrl,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
  });

  final TextEditingController ctrl;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(
          icon,
          color: KwanColors.white(0.4),
          size: 20,
        ),
        hintText: hint,
        hintStyle: TextStyle(color: KwanColors.white(0.3)),
        filled: true,
        fillColor: KwanColors.white(0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: KwanColors.primary,
            width: 1.5,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
      ),
    );
  }
}

class _FullBtn extends StatelessWidget {
  const _FullBtn({
    required this.label,
    this.onTap,
    this.loading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onTap;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        icon: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Icon(icon ?? Icons.arrow_forward, size: 20),
        label: Text(label),
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: KwanColors.primary,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
      ),
    );
  }
}
