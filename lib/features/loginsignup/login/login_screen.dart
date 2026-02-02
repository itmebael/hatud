import 'package:flutter/material.dart';
import 'package:hatud_tricycle_app/features/loginsignup/unified_auth_screen.dart';

class LoginScreen extends StatelessWidget {
  static const String routeName = "login";

  @override
  Widget build(BuildContext context) {
    // Redirect to the new unified authentication screen
    return UnifiedAuthScreen();
  }
}