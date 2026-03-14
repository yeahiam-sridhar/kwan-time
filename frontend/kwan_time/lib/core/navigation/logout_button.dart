import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_providers.dart';
import '../theme/kwan_theme.dart';

enum LogoutButtonStyle {
  /// Icon button for compact surfaces like AppBar actions.
  iconButton,

  /// Full-width outlined button for profile or settings sections.
  outlinedButton,

  /// Row-style action for drawers or settings lists.
  listTile,
}

class LogoutButton extends ConsumerStatefulWidget {
  const LogoutButton({
    super.key,
    this.style = LogoutButtonStyle.iconButton,
  });

  final LogoutButtonStyle style;

  @override
  ConsumerState<LogoutButton> createState() => _LogoutButtonState();
}

class _LogoutButtonState extends ConsumerState<LogoutButton> {
  bool _isLoading = false;

  Future<void> _logout() async {
    if (_isLoading) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ref.read(authServiceProvider).signOut();
      // No manual navigation here.
      // The app-level auth gate handles the signed-out state.
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sign out failed: $error'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: KwanColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<bool> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF162347),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Sign out?',
          style: KwanText.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'You will be returned to the login screen.',
          style: KwanText.bodyMedium.copyWith(
            color: KwanColors.textMuted,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Cancel',
              style: KwanText.bodyMedium.copyWith(
                color: KwanColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Sign out',
              style: KwanText.bodyMedium.copyWith(
                color: KwanColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    return confirmed ?? false;
  }

  Future<void> _onTap() async {
    final confirmed = await _confirmLogout();
    if (!confirmed) {
      return;
    }
    await _logout();
  }

  @override
  Widget build(BuildContext context) {
    return switch (widget.style) {
      LogoutButtonStyle.iconButton => _buildIconButton(),
      LogoutButtonStyle.outlinedButton => _buildOutlinedButton(),
      LogoutButtonStyle.listTile => _buildListTile(),
    };
  }

  Widget _buildIconButton() {
    return IconButton(
      tooltip: 'Sign out',
      onPressed: _isLoading ? null : _onTap,
      icon: _isLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: KwanColors.textSecondary,
              ),
            )
          : const Icon(
              Icons.logout_rounded,
              color: KwanColors.textSecondary,
              size: 22,
            ),
    );
  }

  Widget _buildOutlinedButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: _isLoading ? null : _onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: KwanColors.error,
          side: BorderSide(
            color: KwanColors.error.withValues(alpha: 0.5),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: _isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: KwanColors.error,
                ),
              )
            : const Icon(
                Icons.logout_rounded,
                size: 18,
              ),
        label: const Text(
          'Sign out',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildListTile() {
    return ListTile(
      onTap: _isLoading ? null : _onTap,
      leading: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: KwanColors.error,
              ),
            )
          : const Icon(
              Icons.logout_rounded,
              color: KwanColors.error,
              size: 22,
            ),
      title: const Text(
        'Sign out',
        style: TextStyle(
          color: KwanColors.error,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        'Return to login screen',
        style: KwanText.bodySmall.copyWith(
          color: KwanColors.textMuted,
        ),
      ),
    );
  }
}
