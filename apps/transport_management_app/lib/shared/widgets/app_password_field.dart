import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

class AppPasswordField extends StatefulWidget {
  const AppPasswordField({
    required this.controller,
    required this.labelText,
    super.key,
    this.validator,
    this.helperText,
    this.autofillHints = const [AutofillHints.password],
    this.textInputAction,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final String labelText;
  final String? helperText;
  final String? Function(String?)? validator;
  final Iterable<String> autofillHints;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  State<AppPasswordField> createState() => _AppPasswordFieldState();
}

class _AppPasswordFieldState extends State<AppPasswordField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final action = _visible ? l10n.hidePassword : l10n.showPassword;
    return TextFormField(
      controller: widget.controller,
      obscureText: !_visible,
      enableSuggestions: false,
      autocorrect: false,
      autofillHints: widget.autofillHints,
      validator: widget.validator,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onFieldSubmitted,
      decoration: InputDecoration(
        labelText: widget.labelText,
        helperText: widget.helperText,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: Semantics(
          button: true,
          label: action,
          child: IconButton(
            key: Key('password-visibility-${widget.key ?? widget.labelText}'),
            tooltip: action,
            onPressed: () => setState(() => _visible = !_visible),
            icon: Icon(_visible ? Icons.visibility_off : Icons.visibility),
          ),
        ),
      ),
    );
  }
}
