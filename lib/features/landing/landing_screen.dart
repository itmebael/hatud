import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hatud_tricycle_app/features/language/language_screen.dart';
import 'package:hatud_tricycle_app/features/dashboard/passenger/passenger_dashboard.dart';
import 'package:hatud_tricycle_app/features/dashboard/driver/driver_dashboard.dart';
import 'package:hatud_tricycle_app/features/dashboard/admin/admin_dashboard.dart';
import 'package:hatud_tricycle_app/repo/pref_manager.dart';

import 'bloc/bloc.dart';

///The main landing screen where we can write code for app main door.
class LandingScreen extends StatefulWidget {
  final Locale defaultLocale;

  LandingScreen(this.defaultLocale);

  @override
  _LandingScreenState createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  Locale? _currentLocale;

  @override
  void initState() {
    super.initState();
    _currentLocale = widget.defaultLocale;
    // Listen for locale changes
    _setupLocaleListener();
  }

  void _setupLocaleListener() {
    // This will be called when locale changes in the main app
    // We'll update the locale when the widget rebuilds
  }

  @override
  void didUpdateWidget(LandingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.defaultLocale != widget.defaultLocale) {
      setState(() {
        _currentLocale = widget.defaultLocale;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Update locale from the parent MaterialApp if available
    final locale = Localizations.localeOf(context);
    if (_currentLocale?.languageCode != locale.languageCode) {
      setState(() {
        _currentLocale = locale;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // No longer creating a nested MaterialApp - using the one from main.dart
    // This ensures proper localization context throughout the app
    return Landing();
  }

  @override
  void dispose() {
    super.dispose();
  }
}

class Landing extends StatefulWidget {
  @override
  _LandingState createState() => _LandingState();
}

class _LandingState extends State<Landing> {
  late LandingBloc landingBloc;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    landingBloc = BlocProvider.of<LandingBloc>(context);
    landingBloc.add(
      LandingIsGuest(),
    );
  }

  Future<void> _navigateToDashboard() async {
    // Get user role from preferences
    final pref = await PrefManager.getInstance();
    final userRole = pref.userRole?.toLowerCase() ?? 'client';

    // Map database roles to display roles
    String? dashboardRoute;
    if (userRole == 'client' || userRole == 'passenger') {
      dashboardRoute = PassengerDashboard.routeName;
    } else if (userRole == 'owner' || userRole == 'driver') {
      dashboardRoute = DriverDashboard.routeName;
    } else if (userRole == 'admin') {
      dashboardRoute = AdminDashboard.routeName;
    } else {
      // Default to passenger dashboard
      dashboardRoute = PassengerDashboard.routeName;
    }

    // Navigate to appropriate dashboard
    if (mounted) {
      Navigator.of(context).pushReplacementNamed(dashboardRoute);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: BlocListener<LandingBloc, LandingState>(
          listener: (context, state) {
            if (state is LandingGoToUser) {
              // User is logged in, navigate to appropriate dashboard
              _navigateToDashboard();
            } else if (state is LandingGoToGuest) {
              Navigator.of(context).pushReplacementNamed(
                LanguageScreen.routeName,
              );
            }
          },
          child: BlocBuilder<LandingBloc, LandingState>(
            builder: (context, state) {
              if (state is LandingInitialState) {
                return _buildLoadingState();
              } else if (state is LandingLoadingState) {
                return _buildLoadingState();
              } else if (state is ErrorState) {
                return _buildErrorState(state.errorMsg);
              } else {
                return _buildLoadingState();
              }
            },
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    landingBloc.close();
  }

  _buildLoadingState() {
    return Center(
      child: CircularProgressIndicator(),
    );
  }

  _buildErrorState(msg) {
    return Center(
      child: GestureDetector(
        child: Text(msg),
        onTap: () {
          landingBloc.add(
            LandingIsGuest(),
          );
        },
      ),
    );
  }


}
