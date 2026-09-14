import 'package:flutter/widgets.dart';
import 'package:been/models/app_profile.dart';
import 'package:been/services/auth_controller.dart';

class AuthScope extends InheritedNotifier<AuthController> {
  const AuthScope(
      {super.key, required AuthController controller, required super.child})
      : super(notifier: controller);

  static AuthController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AuthScope>()!.notifier!;
  static AppProfile? profileOf(BuildContext context) => of(context).profile;
}
