import 'package:flutter/material.dart';
import 'package:been/services/auth_controller.dart';
import 'package:been/services/auth_service.dart';
import 'package:been/services/profile_repository.dart';
import 'auth_scope.dart';
import 'auth_screen.dart';

/// Wraps the root Navigator so signing out also removes protected pushed routes.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.child, this.controller});
  final Widget child;
  final AuthController? controller;
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final AuthController _controller =
      widget.controller ?? AuthController(AuthService(), ProfileRepository());
  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AuthScope(
        controller: _controller,
        child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              if (_controller.profile != null && _controller.signedIn) {
                return KeyedSubtree(
                    key: ValueKey(_controller.profile!.id),
                    child: widget.child);
              }
              if (_controller.loading) {
                return _entryNavigator(const Scaffold(
                    body: Center(child: CircularProgressIndicator())));
              }
              if (!_controller.signedIn || _controller.needsSetup) {
                return _entryNavigator(AuthScreen(
                    key: ValueKey(_controller.needsSetup),
                    controller: _controller));
              }
              return _entryNavigator(Scaffold(
                  body: SafeArea(
                      child: Center(
                          child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                      _controller.errorMessage ??
                          'Your profile is unavailable.',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(
                      onPressed:
                          _controller.busy ? null : _controller.loadProfile,
                      child: const Text('Retry')),
                  TextButton(
                      onPressed: _controller.busy ? null : _controller.signOut,
                      child: const Text('Sign out')),
                ]),
              )))));
            }),
      );

  // Text selection and platform back handling need a Navigator/Overlay even
  // while the application's protected Navigator is absent.
  Widget _entryNavigator(Widget page) => Navigator(
        key: const ValueKey('authentication'),
        pages: [MaterialPage<void>(child: page)],
        onDidRemovePage: (_) {},
      );
}
