import 'package:flutter/material.dart';

class SocialAuthButton extends StatelessWidget {
  const SocialAuthButton({
    super.key,
    required this.label,
    required this.assetPath,
    required this.onTap,
    this.isLoading = false,
  });

  final String label;
  final String assetPath;
  final VoidCallback onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: isLoading ? null : onTap,
        child: Ink(
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.09),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              else
                _leadingIcon(),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _leadingIcon() {
    if (assetPath.isNotEmpty) {
      return Image.asset(
        assetPath,
        width: 22,
        height: 22,
        errorBuilder: (_, __, ___) => const Icon(
          Icons.g_mobiledata,
          color: Colors.white,
          size: 22,
        ),
      );
    }
    return const Icon(
      Icons.g_mobiledata,
      color: Colors.white,
      size: 22,
    );
  }
}
