import 'package:flutter/material.dart';
import 'package:kwan_time/core/theme/kwan_theme.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// BOOKING FORM WIDGET — Collects client information
/// ═══════════════════════════════════════════════════════════════════════════

class BookingFormWidget extends StatefulWidget {
  const BookingFormWidget({
    required this.onSubmit,
    super.key,
    this.isSubmitting = false,
  });
  final Function(String name, String email, String? notes) onSubmit;
  final bool isSubmitting;

  @override
  State<BookingFormWidget> createState() => _BookingFormWidgetState();
}

class _BookingFormWidgetState extends State<BookingFormWidget> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _notesController;
  late FocusNode _nameFocus;
  late FocusNode _emailFocus;
  late FocusNode _notesFocus;

  bool _isNameValid = false;
  bool _isEmailValid = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _notesController = TextEditingController();
    _nameFocus = FocusNode();
    _emailFocus = FocusNode();
    _notesFocus = FocusNode();

    _nameController.addListener(_validateName);
    _emailController.addListener(_validateEmail);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _notesController.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _notesFocus.dispose();
    super.dispose();
  }

  void _validateName() {
    setState(() {
      _isNameValid = _nameController.text.trim().isNotEmpty;
    });
  }

  void _validateEmail() {
    setState(() {
      final email = _emailController.text.trim();
      _isEmailValid = _isValidEmail(email);
    });
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  bool get _isFormValid => _isNameValid && _isEmailValid;

  void _submit() {
    if (_isFormValid) {
      widget.onSubmit(
        _nameController.text.trim(),
        _emailController.text.trim(),
        _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          // Name field
          _buildNameField(context),
          const SizedBox(height: 16),
          // Email field
          _buildEmailField(context),
          const SizedBox(height: 16),
          // Notes field
          _buildNotesField(context),
          const SizedBox(height: 24),
          // Submit button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isFormValid && !widget.isSubmitting ? _submit : null,
              style: FilledButton.styleFrom(
                backgroundColor: KwanTheme.neonBlue,
                disabledBackgroundColor: KwanTheme.glassStroke,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: widget.isSubmitting
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white.withOpacity(0.8),
                        ),
                      ),
                    )
                  : const Text('Confirm Booking'),
            ),
          ),
        ],
      );

  Widget _buildNameField(BuildContext context) => TextField(
        controller: _nameController,
        focusNode: _nameFocus,
        enabled: !widget.isSubmitting,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white,
            ),
        textInputAction: TextInputAction.next,
        onSubmitted: (_) => _emailFocus.requestFocus(),
        decoration: InputDecoration(
          hintText: 'Full Name',
          hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: KwanTheme.glassText,
              ),
          filled: true,
          fillColor: KwanTheme.darkGlass.withOpacity(0.3),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: _isNameValid ? KwanTheme.neonGreen : KwanTheme.glassStroke,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: _isNameValid ? KwanTheme.neonGreen : KwanTheme.glassStroke,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: _isNameValid ? KwanTheme.neonGreen : KwanTheme.neonBlue,
              width: 2,
            ),
          ),
          prefixIcon: Icon(
            Icons.person,
            color: _isNameValid ? KwanTheme.neonGreen : KwanTheme.glassText,
          ),
          suffixIcon: _isNameValid ? const Icon(Icons.check_circle, color: KwanTheme.neonGreen) : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      );

  Widget _buildEmailField(BuildContext context) => TextField(
        controller: _emailController,
        focusNode: _emailFocus,
        enabled: !widget.isSubmitting,
        keyboardType: TextInputType.emailAddress,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white,
            ),
        textInputAction: TextInputAction.next,
        onSubmitted: (_) => _notesFocus.requestFocus(),
        decoration: InputDecoration(
          hintText: 'Email Address',
          hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: KwanTheme.glassText,
              ),
          filled: true,
          fillColor: KwanTheme.darkGlass.withOpacity(0.3),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: _isEmailValid ? KwanTheme.neonGreen : KwanTheme.glassStroke,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: _isEmailValid ? KwanTheme.neonGreen : KwanTheme.glassStroke,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: _isEmailValid ? KwanTheme.neonGreen : KwanTheme.neonBlue,
              width: 2,
            ),
          ),
          prefixIcon: Icon(
            Icons.email,
            color: _isEmailValid ? KwanTheme.neonGreen : KwanTheme.glassText,
          ),
          suffixIcon: _isEmailValid ? const Icon(Icons.check_circle, color: KwanTheme.neonGreen) : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      );

  Widget _buildNotesField(BuildContext context) => TextField(
        controller: _notesController,
        focusNode: _notesFocus,
        enabled: !widget.isSubmitting,
        maxLines: 4,
        minLines: 3,
        keyboardType: TextInputType.multiline,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white,
            ),
        textInputAction: TextInputAction.newline,
        decoration: InputDecoration(
          hintText: 'Notes (optional) - Tell us more about what you\'d like to discuss...',
          hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: KwanTheme.glassText,
              ),
          filled: true,
          fillColor: KwanTheme.darkGlass.withOpacity(0.3),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: KwanTheme.glassStroke),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: KwanTheme.glassStroke),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: KwanTheme.neonBlue,
              width: 2,
            ),
          ),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Icon(
              Icons.note_alt,
              color: KwanTheme.glassText,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      );
}
