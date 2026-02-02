import 'package:flutter/material.dart';
import 'package:hatud_tricycle_app/features/language/language_screen.dart';
import 'package:hatud_tricycle_app/features/onboard/onboard_screen.dart';
import 'package:hatud_tricycle_app/features/loginsignup/login/login_screen.dart';
import 'package:hatud_tricycle_app/features/loginsignup/unified_auth_screen.dart';
import 'package:hatud_tricycle_app/features/loginsignup/login_faceid/login_faceid_screen.dart';
import 'package:hatud_tricycle_app/features/loginsignup/reset_password/forgot/forgot_password_screen.dart';
import 'package:hatud_tricycle_app/features/loginsignup/reset_password/otp/otp_screen.dart';
import 'package:hatud_tricycle_app/features/loginsignup/reset_password/reset/reset_screen.dart';
import 'package:hatud_tricycle_app/features/loginsignup/signup/signup_screen.dart';
import 'package:hatud_tricycle_app/features/dashboard/passenger/passenger_dashboard.dart';
import 'package:hatud_tricycle_app/features/dashboard/driver/driver_dashboard.dart';
import 'package:hatud_tricycle_app/features/dashboard/admin/admin_dashboard.dart';
import 'package:hatud_tricycle_app/features/dashboard/bplo/bplo_dashboard.dart';
import 'package:hatud_tricycle_app/features/face_recognition/face_registration_screen.dart';

class RouteGenerator {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case LanguageScreen.routeName:
        return MaterialPageRoute(
          builder: (context) => LanguageScreen(),
          settings: settings,
        );

      case OnBoardScreen.routeName:
        return MaterialPageRoute(
          builder: (context) => OnBoardScreen(),
          settings: settings,
        );

      case LoginScreen.routeName:
        return MaterialPageRoute(
          builder: (context) => LoginScreen(),
          settings: settings,
        );

      case UnifiedAuthScreen.routeName:
        final args = settings.arguments as Map<String, dynamic>?;
        final showSignUp = args?['showSignUp'] ?? false;
        return MaterialPageRoute(
          builder: (context) => UnifiedAuthScreen(showSignUp: showSignUp),
          settings: settings,
        );

      case ForgotPasswordScreen.routeName:
        return MaterialPageRoute(
          builder: (context) => ForgotPasswordScreen(),
          settings: settings,
        );

      case OTPScreen.routeName:
        return MaterialPageRoute(
          builder: (context) => OTPScreen(),
          settings: settings,
        );

      case ResetPassScreen.routeName:
        return MaterialPageRoute(
          builder: (context) => ResetPassScreen(),
          settings: settings,
        );

      case LoginFaceIDScreen.routeName:
        return MaterialPageRoute(
          builder: (context) => LoginFaceIDScreen(),
          settings: settings,
        );

      case SignupScreen.routeName:
        return MaterialPageRoute(
          builder: (context) => SignupScreen(),
          settings: settings,
        );

      case PassengerDashboard.routeName:
        return MaterialPageRoute(
          builder: (context) => PassengerDashboard(),
          settings: settings,
        );

      case DriverDashboard.routeName:
        return MaterialPageRoute(
          builder: (context) => DriverDashboard(),
          settings: settings,
        );

      case AdminDashboard.routeName:
        return MaterialPageRoute(
          builder: (context) => AdminDashboard(),
          settings: settings,
        );

      case BPLODashboard.routeName:
        return MaterialPageRoute(
          builder: (context) => BPLODashboard(),
          settings: settings,
        );

      case FaceRegistrationScreen.routeName:
        final args = settings.arguments as Map<String, dynamic>?;
        final prefilledUserId = args?['prefilledUserId'] as String?;
        final prefilledDisplayName = args?['prefilledDisplayName'] as String?;
        return MaterialPageRoute<bool?>(
          builder: (context) => FaceRegistrationScreen(
            prefilledUserId: prefilledUserId,
            prefilledDisplayName: prefilledDisplayName,
          ),
          settings: settings,
        );

      default:
        return _errorRoute();
    }
  }

  static Route<dynamic> _errorRoute() {
    return MaterialPageRoute(builder: (_) {
      return SafeArea(
        child: Scaffold(
          appBar: AppBar(
            title: Text('Error'),
            backgroundColor: Colors.red,
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
                SizedBox(height: 16),
                Text(
                  'Route not found',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'The requested page could not be found.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    // Navigate back or to home
                  },
                  child: Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}