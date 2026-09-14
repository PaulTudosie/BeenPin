import 'package:flutter/material.dart';
import 'package:been/core/theme/app_colors.dart';
import 'package:been/services/auth_controller.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.controller});
  final AuthController controller;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _username = TextEditingController();
  final _displayName = TextEditingController();
  bool _signUp = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller.needsSetup) {
      final metadata = widget.controller.auth.currentUser?.userMetadata;
      _username.text = metadata?['username'] as String? ?? '';
      _displayName.text = metadata?['display_name'] as String? ?? '';
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _username.dispose();
    _displayName.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final controller = widget.controller;
    if (controller.busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    if (controller.needsSetup) {
      await controller.completeProfile(
          _username.text.trim(), _displayName.text.trim());
    } else if (_signUp) {
      await controller.signUp(
          email: _email.text.trim(),
          password: _password.text,
          username: _username.text.trim(),
          displayName: _displayName.text.trim());
    } else {
      await controller.signIn(_email.text.trim(), _password.text);
    }
    if (mounted && controller.notice != null) {
      _password.clear();
      setState(() => _signUp = false);
    }
  }

  Widget _field(TextEditingController controller, String label,
          {bool password = false, bool email = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextFormField(
          controller: controller,
          enabled: !widget.controller.busy,
          obscureText: password,
          autocorrect: false,
          enableSuggestions: !password,
          keyboardType: email ? TextInputType.emailAddress : TextInputType.text,
          textInputAction:
              password ? TextInputAction.done : TextInputAction.next,
          onFieldSubmitted: password ? (_) => _submit() : null,
          validator: (value) {
            if (value == null ||
                (password ? value.isEmpty : value.trim().isEmpty)) {
              return 'Enter your ${label.toLowerCase()}.';
            }
            if (email &&
                !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim())) {
              return 'Enter a valid email address.';
            }
            if (password && _signUp && value.length < 6) {
              return 'Use at least 6 characters.';
            }
            return null;
          },
          decoration: InputDecoration(
            labelText: label,
            filled: true,
            fillColor: AppColors.surfaceSoft,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.border)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final setup = controller.needsSetup;
    return Scaffold(
        body: SafeArea(
            child: Center(
                child: SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text.rich(
                    const TextSpan(children: [
                      TextSpan(
                          text: 'Been',
                          style: TextStyle(color: AppColors.brandBlue)),
                      TextSpan(
                          text: 'Pin',
                          style: TextStyle(color: AppColors.brandGreen)),
                    ]),
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .headlineLarge
                        ?.copyWith(fontSize: 32)),
                const SizedBox(height: 28),
                Text(
                    setup
                        ? 'Finish your profile'
                        : _signUp
                            ? 'Create your account'
                            : 'Welcome back',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 24),
                if (_signUp || setup) ...[
                  _field(_displayName, 'Display name'),
                  _field(_username, 'Username'),
                ],
                if (!setup) ...[
                  _field(_email, 'Email', email: true),
                  _field(_password, 'Password', password: true),
                ],
                if (controller.errorMessage != null)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(controller.errorMessage!,
                          semanticsLabel: controller.errorMessage,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error))),
                if (controller.notice != null)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(controller.notice!)),
                FilledButton(
                    onPressed: controller.busy ? null : _submit,
                    child: controller.busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(setup
                            ? 'Save profile'
                            : _signUp
                                ? 'Create account'
                                : 'Sign in')),
                TextButton(
                    onPressed: controller.busy
                        ? null
                        : setup
                            ? controller.signOut
                            : () {
                                _form.currentState?.reset();
                                _password.clear();
                                controller.errorMessage = null;
                                controller.notice = null;
                                setState(() => _signUp = !_signUp);
                              },
                    child: Text(setup
                        ? 'Sign out'
                        : _signUp
                            ? 'Already have an account? Sign in'
                            : 'Create account')),
              ],
            )),
      ),
    ))));
  }
}
