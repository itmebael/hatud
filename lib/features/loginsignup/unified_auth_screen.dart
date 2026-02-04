import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:hatud_tricycle_app/common/my_colors.dart';
import 'package:hatud_tricycle_app/common/responsive_helper.dart';
import 'package:hatud_tricycle_app/common/viiticons_icons.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'package:hatud_tricycle_app/features/loginsignup/login_faceid/login_faceid_screen.dart';
import 'package:hatud_tricycle_app/features/loginsignup/reset_password/forgot/forgot_password_screen.dart';
import 'package:hatud_tricycle_app/features/dashboard/passenger/passenger_dashboard.dart';
import 'package:hatud_tricycle_app/features/dashboard/driver/driver_dashboard.dart';
import 'package:hatud_tricycle_app/features/dashboard/admin/admin_dashboard.dart';
import 'package:hatud_tricycle_app/features/dashboard/bplo/bplo_dashboard.dart';
import 'package:hatud_tricycle_app/features/face_recognition/face_registration_screen.dart';
import 'package:hatud_tricycle_app/widgets/role_selection_widget.dart';

import 'login/bloc/bloc.dart';
import '../../supabase_client.dart';
import 'package:hatud_tricycle_app/repo/pref_manager.dart';
import 'package:uuid/uuid.dart';
import 'package:hatud_tricycle_app/l10n/app_localizations.dart';

class UnifiedAuthScreen extends StatelessWidget {
  static const String routeName = "unified_auth";
  final bool showSignUp;

  const UnifiedAuthScreen({Key? key, this.showSignUp = false})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LoginBloc(),
      child: UnifiedAuth(showSignUp: showSignUp),
    );
  }
}

class UnifiedAuth extends StatefulWidget {
  final bool showSignUp;

  const UnifiedAuth({Key? key, this.showSignUp = false}) : super(key: key);

  @override
  _UnifiedAuthState createState() => _UnifiedAuthState();
}

class _UnifiedAuthState extends State<UnifiedAuth>
    with TickerProviderStateMixin {
  late LoginBloc loginBloc;

  // Image picker instance
  final ImagePicker _picker = ImagePicker();

  // Form controllers
  TextEditingController _nameCntrl = TextEditingController();
  TextEditingController _mobileCntrl = TextEditingController();
  TextEditingController _passCntrl = TextEditingController();
  TextEditingController _confirmPassCntrl = TextEditingController();
  TextEditingController _emailCntrl = TextEditingController();
  TextEditingController _addressCntrl = TextEditingController();
  // Passenger-specific extra fields
  TextEditingController _idNumberCntrl = TextEditingController();
  TextEditingController _driverLicenseNumberCntrl = TextEditingController();
  TextEditingController _tricyclePlateNumberCntrl = TextEditingController();

  // Profile state
  String? _profileImagePath;
  String? _driverLicenseImagePath;
  String? _tricyclePlateImagePath;
  String? _passengerIdImagePath;

  // Focus nodes
  FocusNode _nameNode = FocusNode();
  FocusNode _mobileNode = FocusNode();
  FocusNode _passwordNode = FocusNode();
  FocusNode _confirmPassNode = FocusNode();
  FocusNode _emailNode = FocusNode();
  FocusNode _addressNode = FocusNode();
  FocusNode _idNumberNode = FocusNode();
  FocusNode _driverLicenseNode = FocusNode();
  FocusNode _tricyclePlateNode = FocusNode();

  // State management
  bool _isLogin = true;
  String? selectedRole;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _faceIdRegistered = false; // Track if face ID registration is completed
  String? _tempFaceAuthId; // Store the ID used for face registration

  // Form keys
  final _loginKey = GlobalKey<FormState>();
  final _registerKey = GlobalKey<FormState>();

  // Animation controllers
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _isLogin =
        !widget.showSignUp; // If showSignUp is true, set _isLogin to false
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    loginBloc = BlocProvider.of<LoginBloc>(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<LoginBloc, LoginState>(
        listener: (context, state) {
          if (state is LoadingLoginState) {
            setState(() {
              _isLoading = true;
            });
          } else if (state is GotoHomeState) {
            setState(() {
              _isLoading = false;
            });
            _navigateToDashboard();
          } else if (state is ErrorLoginState) {
            setState(() {
              _isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.errorMsg.toString())),
            );
          }
        },
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool isTabletWidth =
                  constraints.maxWidth >= ResponsiveHelper.mobileBreakpoint;
              final bool isDesktopWidth =
                  constraints.maxWidth >= ResponsiveHelper.tabletBreakpoint;
              final bool showSidePanel = constraints.maxWidth >= 1080;
              final bool showIllustration = constraints.maxWidth >= 720;

              final EdgeInsets pagePadding = EdgeInsets.symmetric(
                horizontal: showSidePanel
                    ? 56
                    : isDesktopWidth
                        ? 42
                        : isTabletWidth
                            ? 28
                            : 16,
                vertical: showSidePanel
                    ? 40
                    : isDesktopWidth
                        ? 32
                        : isTabletWidth
                            ? 26
                            : 16,
              );

              return Stack(
                children: [
                  _buildAnimatedBackground(constraints),
                  Align(
                    alignment: Alignment.topCenter,
                    child: SingleChildScrollView(
                      padding: pagePadding,
                      physics: const BouncingScrollPhysics(),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: showSidePanel
                                ? 1180
                                : isDesktopWidth
                                    ? 920
                                    : isTabletWidth
                                        ? 720
                                        : 520,
                          ),
                          child: _buildResponsiveShell(
                            context: context,
                            showSidePanel: showSidePanel,
                            showIllustration: showIllustration,
                            isCompact: !isTabletWidth,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildResponsiveShell({
    required BuildContext context,
    required bool showSidePanel,
    required bool showIllustration,
    required bool isCompact,
  }) {
    final borderRadius = BorderRadius.circular(showSidePanel ? 32 : 22);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 40,
            offset: const Offset(0, 24),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
            ),
            child: showSidePanel
                ? IntrinsicHeight(
                    child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Flexible(
                        flex: 5,
                        child: _buildHeroSection(
                          context: context,
                          showIllustration: showIllustration,
                          showSidePanel: true,
                          compact: false,
                        ),
                      ),
                      Flexible(
                        flex: 7,
                        child: _buildFormSection(
                          context: context,
                          isWide: true,
                          isCompact: false,
                        ),
                      ),
                    ],
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildHeroSection(
                        context: context,
                        showIllustration: showIllustration,
                        showSidePanel: false,
                        compact: isCompact,
                      ),
                      _buildFormSection(
                        context: context,
                        isWide: !isCompact,
                        isCompact: isCompact,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection({
    required BuildContext context,
    required bool showIllustration,
    required bool showSidePanel,
    required bool compact,
  }) {
    final theme = Theme.of(context);
    final double horizontalPadding = showSidePanel
        ? 38
        : compact
            ? 18
            : 26;
    final double verticalPadding = showSidePanel
        ? 44
        : compact
            ? 22
            : 30;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              kPrimaryColor,
              kAccentColor,
              const Color(0xFF5D5FEF),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          image: const DecorationImage(
            image: AssetImage('assets/onboarding_shape.png'),
            fit: BoxFit.cover,
            opacity: 0.09,
          ),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: showIllustration && showSidePanel
                  ? MainAxisSize.max
                  : MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.92, end: 1),
                  duration: const Duration(milliseconds: 360),
                  curve: Curves.easeOutBack,
                  builder: (context, value, child) =>
                      Transform.scale(scale: value, child: child),
                  child: Container(
                    width: compact ? 70 : 88,
                    height: compact ? 70 : 88,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Image.asset(
                        'assets/logo_small.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _isLogin 
                      ? AppLocalizations.of(context)!.welcomeBack 
                      : AppLocalizations.of(context)!.createYourAccount,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _isLogin
                      ? AppLocalizations.of(context)!.accessYourRides
                      : AppLocalizations.of(context)!.joinOurCommunity,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildHeroBadge(context, Icons.bolt_rounded, AppLocalizations.of(context)!.quickBooking),
                    _buildHeroBadge(
                        context, Icons.shield_rounded, AppLocalizations.of(context)!.securePayments),
                    if (showIllustration)
                      _buildHeroBadge(
                          context, Icons.timeline_rounded, AppLocalizations.of(context)!.liveRideTracking),
                  ],
                ),
                if (showIllustration && !showSidePanel) ...[
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      height: 180,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.9, end: 1),
                        duration: const Duration(milliseconds: 520),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) =>
                            Transform.scale(scale: value, child: child),
                        child: Image.asset(
                          'assets/onboarding_1.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ],
                // Reserve space for the image in side panel mode
                if (showIllustration && showSidePanel)
                   const SizedBox(height: 200), 
              ],
            ),
            if (showIllustration && showSidePanel)
              Positioned(
                bottom: 0,
                right: 0,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.88, end: 1),
                  duration: const Duration(milliseconds: 520),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) =>
                      Transform.scale(scale: value, child: child),
                  child: Image.asset(
                    'assets/onboarding_1.png',
                    fit: BoxFit.contain,
                    height: 240,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormSection({
    required BuildContext context,
    required bool isWide,
    required bool isCompact,
  }) {
    final double horizontalPadding = isWide ? 34 : 20;
    final double verticalPadding = isWide ? 36 : 24;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildAuthToggle(context),
            const SizedBox(height: 32),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: _isLogin ? _buildLoginForm() : _buildRegisterForm(),
            ),
            _buildAdditionalOptions(context, isCompact: isCompact),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthToggle(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 50,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: kOrangeLight.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeInOut,
            alignment: _isLogin ? Alignment.centerLeft : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      kPrimaryColor,
                      kAccentColor,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: kPrimaryColor.withValues(alpha: 0.4),
                      blurRadius: 18,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _toggleAuthMode(true),
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: _isLogin ? Colors.white : kBlack,
                          ) ??
                          TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _isLogin ? Colors.white : kBlack,
                          ),
                      child: Text(AppLocalizations.of(context)!.signIn),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _toggleAuthMode(false),
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: !_isLogin ? Colors.white : kBlack,
                          ) ??
                          TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: !_isLogin ? Colors.white : kBlack,
                          ),
                      child: Text(AppLocalizations.of(context)!.signUp),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalOptions(BuildContext context,
      {required bool isCompact}) {
    final forgotPasswordButton = _isLogin
        ? TextButton(
            onPressed: () {
              Navigator.of(context).pushNamed(ForgotPasswordScreen.routeName);
            },
            child: Text(AppLocalizations.of(context)!.forgotPassword),
          )
        : null;

    Widget faceIdButton(bool fullWidth) {
      final button = OutlinedButton.icon(
        onPressed: () {
          Navigator.of(context).pushNamed(LoginFaceIDScreen.routeName);
        },
        icon: const Icon(Viiticons.face),
        label: Text(AppLocalizations.of(context)!.useFaceId),
      );

      if (fullWidth) {
        return SizedBox(
          width: double.infinity,
          child: button,
        );
      }
      return button;
    }

    if (isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          Divider(
            color: kOrangeLight.withValues(alpha: 0.2),
            height: 32,
            thickness: 1,
          ),
          const SizedBox(height: 20),
          faceIdButton(true),
          if (forgotPasswordButton != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: forgotPasswordButton,
            ),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 36),
        Divider(
          color: kOrangeLight.withValues(alpha: 0.2),
          height: 32,
          thickness: 1,
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            faceIdButton(false),
            if (forgotPasswordButton != null) ...[
              const SizedBox(width: 16),
              forgotPasswordButton,
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildHeroBadge(BuildContext context, IconData icon, String label) {
    final theme = Theme.of(context);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.92, end: 1),
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutBack,
      builder: (context, value, child) =>
          Transform.scale(scale: value, child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 16,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedBackground(BoxConstraints constraints) {
    final double maxWidth = constraints.maxWidth;
    final double heroDiameter = maxWidth * 0.45;
    final double accentDiameter = maxWidth * 0.35;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.93, end: 1),
      duration: const Duration(milliseconds: 620),
      curve: Curves.easeOutCubic,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              kOrangeLight.withValues(alpha: 0.3),
              Colors.white,
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              left: -heroDiameter * 0.25,
              top: -heroDiameter * 0.2,
              child: _buildGlowingCircle(
                diameter: heroDiameter,
                color: kPrimaryColor.withValues(alpha: 0.3),
              ),
            ),
            Positioned(
              right: -accentDiameter * 0.3,
              bottom: -accentDiameter * 0.2,
              child: _buildGlowingCircle(
                diameter: accentDiameter,
                color: const Color(0xFF5D5FEF).withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlowingCircle({
    required double diameter,
    required Color color,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color,
            color.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: diameter * 0.45,
            spreadRadius: diameter * 0.1,
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _loginKey,
      child: Column(
        key: const ValueKey('login'),
        children: [
          // Role Selection
          RoleSelectionWidget(
            selectedRole: selectedRole,
            onRoleChanged: (role) {
              setState(() {
                selectedRole = role;
              });
            },
          ),
          const SizedBox(height: 20),

          // Mobile/Email Field
          TextFormField(
            controller: _mobileCntrl,
            focusNode: _mobileNode,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.mobileNumberOrEmail,
              prefixIcon:
                  const Icon(Icons.person_outline, color: kPrimaryColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: kGrey),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: kGrey),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kPrimaryColor, width: 2),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.trim().isEmpty)
                return AppLocalizations.of(context)!.pleaseEnterMobileOrEmail;
              return null;
            },
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) =>
                _fieldFocusChange(context, _mobileNode, _passwordNode),
          ),
          const SizedBox(height: 16),

          // Password Field
          TextFormField(
            controller: _passCntrl,
            focusNode: _passwordNode,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.password,
              prefixIcon: const Icon(Icons.lock_outline, color: kPrimaryColor),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: kTextLoginfaceid,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: kGrey),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: kGrey),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kPrimaryColor, width: 2),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return AppLocalizations.of(context)!.passwordIsRequired;
              if (v.length < 6) return AppLocalizations.of(context)!.minimum6Characters;
              return null;
            },
          ),
          const SizedBox(height: 24),

          // Sign In Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      AppLocalizations.of(context)!.signIn,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterForm() {
    final selectedRoleLower = (selectedRole ?? '').toLowerCase();
    final isDriver = selectedRoleLower == 'driver';

    return Form(
      key: _registerKey,
      child: Column(
        key: const ValueKey('register'),
        children: [
          // Profile Picture Upload
          Center(
            child: Stack(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: kPrimaryColor,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: kPrimaryColor.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 48,
                    backgroundColor: kOrangeLight,
                    backgroundImage: _profileImagePath != null
                        ? FileImage(File(_profileImagePath!)) as ImageProvider
                        : null,
                    child: _profileImagePath == null
                        ? const Icon(Icons.person,
                            size: 50, color: kPrimaryColor)
                        : null,
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _showProfileImagePicker,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: kPrimaryColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: kPrimaryColor.withValues(alpha: 0.3),
                            blurRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Full Name Field
          TextFormField(
            controller: _nameCntrl,
            focusNode: _nameNode,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.fullName,
              prefixIcon:
                  const Icon(Icons.person_outline, color: kPrimaryColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: kGrey),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: kGrey),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kPrimaryColor, width: 2),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? AppLocalizations.of(context)!.nameIsRequired : null,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) =>
                _fieldFocusChange(context, _nameNode, _emailNode),
          ),
          const SizedBox(height: 16),

          // Email Field
          TextFormField(
            controller: _emailCntrl,
            focusNode: _emailNode,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.emailAddress,
              prefixIcon:
                  const Icon(Icons.email_outlined, color: kPrimaryColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: kGrey),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: kGrey),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kPrimaryColor, width: 2),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return AppLocalizations.of(context)!.emailIsRequired;
              if (!v.contains('@')) return AppLocalizations.of(context)!.pleaseEnterValidEmail;
              return null;
            },
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) =>
                _fieldFocusChange(context, _emailNode, _mobileNode),
          ),
          const SizedBox(height: 16),

          // Mobile Field
          TextFormField(
            controller: _mobileCntrl,
            focusNode: _mobileNode,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.mobileNumber,
              prefixIcon:
                  const Icon(Icons.phone_outlined, color: kPrimaryColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: kGrey),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: kGrey),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kPrimaryColor, width: 2),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            ),
            keyboardType: TextInputType.phone,
            validator: (v) {
              if (v == null || v.trim().isEmpty)
                return AppLocalizations.of(context)!.mobileNumberIsRequired;
              return null;
            },
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) =>
                _fieldFocusChange(context, _mobileNode, _addressNode),
          ),
          const SizedBox(height: 16),

          // Address Field
          TextFormField(
            controller: _addressCntrl,
            focusNode: _addressNode,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.address,
              prefixIcon:
                  const Icon(Icons.location_on_outlined, color: kPrimaryColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: kGrey),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: kGrey),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kPrimaryColor, width: 2),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            ),
            keyboardType: TextInputType.streetAddress,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return AppLocalizations.of(context)!.addressIsRequired;
              return null;
            },
            textInputAction: TextInputAction.next,
            maxLines: 2,
          ),
          const SizedBox(height: 16),

          // Passenger-only fields: ID and Note
          if (!isDriver) ...[
            TextFormField(
              controller: _idNumberCntrl,
              focusNode: _idNumberNode,
              decoration: InputDecoration(
                labelText: 'ID Number',
                prefixIcon:
                    const Icon(Icons.badge_outlined, color: kPrimaryColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: kGrey),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: kGrey),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kPrimaryColor, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    vertical: 16, horizontal: 16),
              ),
              validator: (v) {
                if (!isDriver && (v == null || v.trim().isEmpty)) {
                  return 'ID is required';
                }
                return null;
              },
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) =>
                  _fieldFocusChange(context, _idNumberNode, _passwordNode),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _capturePassengerIdPhoto,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kGrey),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.camera_alt,
                      color: _passengerIdImagePath == null
                          ? kPrimaryColor
                          : kGreen,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _passengerIdImagePath == null
                            ? 'Capture ID Photo'
                            : 'ID Photo captured',
                        style: TextStyle(
                          color: kBlack,
                          fontWeight: FontWeight.w500,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    if (_passengerIdImagePath != null) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.check_circle, color: kGreen, size: 18),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Role Selection
          RoleSelectionWidget(
            selectedRole: selectedRole,
            onRoleChanged: (role) {
              setState(() {
                selectedRole = role;
              });
            },
            showAdmin: false,
          ),
          const SizedBox(height: 16),

          if (isDriver) ...[
            TextFormField(
              controller: _driverLicenseNumberCntrl,
              focusNode: _driverLicenseNode,
              decoration: InputDecoration(
                labelText:
                    AppLocalizations.of(context)!.driverLicenseNumberLabel,
                prefixIcon:
                    const Icon(Icons.credit_card, color: kPrimaryColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: kGrey),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: kGrey),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: kPrimaryColor, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    vertical: 16, horizontal: 16),
              ),
              validator: (v) {
                if (isDriver && (v == null || v.trim().isEmpty)) {
                  return AppLocalizations.of(context)!
                      .driverLicenseNumberRequired;
                }
                return null;
              },
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) => _fieldFocusChange(
                  context, _driverLicenseNode, _tricyclePlateNode),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _tricyclePlateNumberCntrl,
              focusNode: _tricyclePlateNode,
              decoration: InputDecoration(
                labelText:
                    AppLocalizations.of(context)!.tricyclePlateNumberLabel,
                prefixIcon:
                    const Icon(Icons.confirmation_number, color: kPrimaryColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: kGrey),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: kGrey),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: kPrimaryColor, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    vertical: 16, horizontal: 16),
              ),
              validator: (v) {
                if (isDriver && (v == null || v.trim().isEmpty)) {
                  return AppLocalizations.of(context)!
                      .tricyclePlateNumberRequired;
                }
                return null;
              },
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) => _fieldFocusChange(
                  context, _tricyclePlateNode, _passwordNode),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _captureDriverLicensePhoto,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kGrey),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.camera_alt,
                              color: _driverLicenseImagePath == null
                                  ? kPrimaryColor
                                  : kGreen),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _driverLicenseImagePath == null
                                  ? AppLocalizations.of(context)!
                                      .driverLicenseNumberLabel
                                  : AppLocalizations.of(context)!
                                      .driverLicensePhotoRequired
                                      .split(' ')
                                      .first,
                              style: TextStyle(
                                color: kBlack,
                                fontWeight: FontWeight.w500,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: _captureTricyclePlatePhoto,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kGrey),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.camera_alt,
                              color: _tricyclePlateImagePath == null
                                  ? kPrimaryColor
                                  : kGreen),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _tricyclePlateImagePath == null
                                  ? AppLocalizations.of(context)!
                                      .tricyclePlateNumberLabel
                                  : AppLocalizations.of(context)!
                                      .tricyclePlatePhotoRequired
                                      .split(' ')
                                      .first,
                              style: TextStyle(
                                color: kBlack,
                                fontWeight: FontWeight.w500,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Face ID Registration (Required for Driver and Passenger)
          Builder(
            builder: (context) {
              final isPassengerForFace = selectedRoleLower == 'passenger';
              if (isDriver || isPassengerForFace) {
                return Column(
                  children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _faceIdRegistered 
                    ? Colors.green[50] 
                    : Colors.orange[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _faceIdRegistered 
                      ? Colors.green[300]! 
                      : Colors.orange[300]!,
                  width: 2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _faceIdRegistered ? Icons.check_circle : Icons.face,
                        color: _faceIdRegistered 
                            ? Colors.green[700] 
                            : Colors.orange[700],
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Face ID Registration',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _faceIdRegistered 
                                ? Colors.green[900] 
                                : Colors.orange[900],
                          ),
                        ),
                      ),
                      if (_faceIdRegistered)
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 24,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _faceIdRegistered
                        ? 'Face ID registration completed successfully.'
                        : 'Face ID registration is required to create your account. Please register your face before proceeding.',
                    style: TextStyle(
                      fontSize: 13,
                      color: _faceIdRegistered 
                          ? Colors.green[800] 
                          : Colors.orange[800],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        // Generate temporary user ID for face registration
                        final tempUserId = const Uuid().v4();
                        _tempFaceAuthId = tempUserId; // Save the ID for account creation
                        final displayNameForFace = _nameCntrl.text.trim();
                        
                        final faceRegistrationCompleted = await Navigator.of(context).pushNamed<bool>(
                          FaceRegistrationScreen.routeName,
                          arguments: {
                            'prefilledUserId': tempUserId,
                            'prefilledDisplayName':
                                displayNameForFace.isEmpty ? null : displayNameForFace,
                          },
                        );

                        if (faceRegistrationCompleted == true && mounted) {
                          setState(() {
                            _faceIdRegistered = true;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Face ID registration completed successfully!'),
                              backgroundColor: Colors.green,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        } else if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Face ID registration is required. Please complete it to continue.'),
                              backgroundColor: Colors.orange,
                              duration: Duration(seconds: 3),
                            ),
                          );
                        }
                      },
                      icon: Icon(
                        _faceIdRegistered ? Icons.check_circle : Icons.face,
                        color: Colors.white,
                      ),
                      label: Text(
                        _faceIdRegistered ? 'Face ID Registered' : 'Register Face ID',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _faceIdRegistered 
                            ? Colors.green[700] 
                            : kPrimaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          ),
          const SizedBox(height: 16),

          // Password Field
          TextFormField(
            controller: _passCntrl,
            focusNode: _passwordNode,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.password,
              prefixIcon: const Icon(Icons.lock_outline, color: kPrimaryColor),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: kTextLoginfaceid,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: kGrey),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: kGrey),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kPrimaryColor, width: 2),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return AppLocalizations.of(context)!.passwordIsRequired;
              if (v.length < 6) return AppLocalizations.of(context)!.minimum6Characters;
              return null;
            },
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) =>
                _fieldFocusChange(context, _passwordNode, _confirmPassNode),
          ),
          const SizedBox(height: 16),

          // Confirm Password Field
          TextFormField(
            controller: _confirmPassCntrl,
            focusNode: _confirmPassNode,
            obscureText: _obscureConfirmPassword,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.confirmPassword,
              prefixIcon: const Icon(Icons.lock_outline, color: kPrimaryColor),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility_off
                      : Icons.visibility,
                  color: kTextLoginfaceid,
                ),
                onPressed: () {
                  setState(() {
                    _obscureConfirmPassword = !_obscureConfirmPassword;
                  });
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: kGrey),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: kGrey),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kPrimaryColor, width: 2),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return AppLocalizations.of(context)!.pleaseConfirmPassword;
              if (v != _passCntrl.text) return AppLocalizations.of(context)!.passwordsDoNotMatch;
              return null;
            },
          ),
          const SizedBox(height: 24),

          // Sign Up Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitRegister,
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      AppLocalizations.of(context)!.createAccount,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleAuthMode(bool isLogin) {
    setState(() {
      _isLogin = isLogin;
    });
    _animationController.reset();
    _animationController.forward();
  }

  void _submitLogin() {
    if (_loginKey.currentState?.validate() ?? false) {
      if (selectedRole == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.pleaseSelectRole),
            backgroundColor: kDanger,
          ),
        );
        return;
      }

      // Show loading state
      setState(() {
        _isLoading = true;
      });

      // Authenticate with Supabase
      _loginWithSupabase();
    }
  }

  Future<void> _submitRegister() async {
    if (_registerKey.currentState?.validate() ?? false) {
      if (selectedRole == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.pleaseSelectRole),
            backgroundColor: kDanger,
          ),
        );
        return;
      }

      final selectedRoleLower = (selectedRole ?? '').toLowerCase();
      final isDriver = selectedRoleLower == 'driver';
      final isPassenger = selectedRoleLower == 'passenger';

      if (isDriver) {
        if (_driverLicenseImagePath == null ||
            _driverLicenseImagePath!.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  AppLocalizations.of(context)!.driverLicensePhotoRequired),
              backgroundColor: kDanger,
            ),
          );
          return;
        }

        if (_tricyclePlateImagePath == null ||
            _tricyclePlateImagePath!.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  AppLocalizations.of(context)!.tricyclePlatePhotoRequired),
              backgroundColor: kDanger,
            ),
          );
          return;
        }
      } else if (isPassenger) {
        if (_passengerIdImagePath == null || _passengerIdImagePath!.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Passenger ID photo is required'),
              backgroundColor: kDanger,
              duration: Duration(seconds: 3),
            ),
          );
          return;
        }
      }

      // Face ID registration is MANDATORY before account creation
      // Require face registration for Driver and Passenger
      if (isDriver || isPassenger) {
        if (!_faceIdRegistered) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please complete Face ID registration before creating your account.'),
              backgroundColor: kDanger,
              duration: Duration(seconds: 3),
            ),
          );
          return;
        }
      }

      // Show loading state
      setState(() {
        _isLoading = true;
      });

      _registerWithSupabase();
    }
  }

  Future<void> _loginWithSupabase() async {
    try {
      // Ensure Supabase is initialized
      await AppSupabase.initialize();
      final client = AppSupabase.client;

      final loginIdentifier = _mobileCntrl.text.trim();
      final password = _passCntrl.text.trim();

      // Special handling for BPLO admin login (username: admin_lto, password: admin123)
      if (loginIdentifier.toLowerCase() == 'admin_lto' && password == 'admin123') {
        // Check if BPLO admin user exists in database
        final ltoResponse = await client
            .from('users')
            .select()
            .or('email.eq.admin_lto,phone_number.eq.admin_lto')
            .eq('role', 'lto_admin')
            .limit(1)
            .maybeSingle();

        // If BPLO admin doesn't exist, create it or handle the login
        // For now, we'll allow login if the role is lto_admin
        if (ltoResponse != null || loginIdentifier.toLowerCase() == 'admin_lto') {
          final pref = await PrefManager.getInstance();
          pref.userEmail = ltoResponse?['email'] as String? ?? 'admin_lto';
          pref.userName = ltoResponse?['full_name'] as String? ?? 'BPLO Admin';
          pref.userRole = 'lto_admin';
          pref.userPhone = ltoResponse?['phone_number'] as String? ?? 'admin_lto';
          pref.userAddress = ltoResponse?['address'] as String?;
          pref.userImage = ltoResponse?['profile_image'] as String?;
          pref.isLogin = true;

          if (!mounted) return;
          setState(() => _isLoading = false);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Welcome, BPLO Admin!'),
              backgroundColor: kGreen,
              duration: Duration(seconds: 2),
            ),
          );

          Navigator.of(context).pushReplacementNamed(BPLODashboard.routeName);
          return;
        }
      }

      // Regular login flow for other users
      // Query user from database using email or mobile
      final response = await client
          .from('users')
          .select()
          .or('email.eq.$loginIdentifier,phone_number.eq.$loginIdentifier')
          .limit(1)
          .maybeSingle();

      if (response == null) {
        // User not found
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'User not found. Please check your email/mobile or sign up.'),
            backgroundColor: kDanger,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      // Check if user's role matches the selected role
      final userRole = (response['role'] as String?)?.toLowerCase() ?? 'client';
      final selectedRoleLower = (selectedRole ?? '').toLowerCase();

      // Map display roles to database roles
      final roleMap = {
        'passenger': 'client',
        'driver': 'owner',
        'admin': 'admin',
        'lto': 'lto_admin',
      };

      final expectedRole = roleMap[selectedRoleLower] ?? 'client';

      // Allow lto_admin to login if role is lto_admin (even if selected role doesn't match)
      if (userRole == 'lto_admin') {
        // BPLO admin can login directly
      } else if (userRole != expectedRole) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'This account is registered as ${userRole}. Please select the correct role.'),
            backgroundColor: kDanger,
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }

      // Check account status
      final status = response['status'] as String?;
      if (status == 'inactive' || status == 'suspended') {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.accountInactive),
            backgroundColor: kDanger,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      // Save user data to PrefManager for dashboard usage
      final pref = await PrefManager.getInstance();
      pref.userEmail = response['email'] as String?;
      pref.userName = response['full_name'] as String?;
      pref.userRole = response['role'] as String?;
      pref.userPhone = response['phone_number'] as String?;
      pref.userAddress = response['address'] as String?;
      pref.userImage = response['profile_image'] as String?;
      // Set login status to true for persistent login
      pref.isLogin = true;

      if (!mounted) return;
      setState(() => _isLoading = false);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.welcomeBackUser(response['full_name'] ?? AppLocalizations.of(context)!.welcome)),
          backgroundColor: kGreen,
          duration: const Duration(seconds: 2),
        ),
      );

      // Navigate to dashboard
      _navigateToDashboard();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.loginFailed(e.toString())),
          backgroundColor: kDanger,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _registerWithSupabase() async {
    try {
      // ensure supabase is initialized
      await AppSupabase.initialize();

      final client = AppSupabase.client;

      // Use the ID from face registration if available, otherwise generate new one
      final userId = _tempFaceAuthId ?? const Uuid().v4();
      final roleValue = (() {
        final r = (selectedRole ?? 'client').toLowerCase();
        // Map display roles to database roles
        final roleMap = {
          'passenger': 'client',
          'driver': 'owner',
          'admin': 'admin',
        };
        return roleMap[r] ?? 'client';
      })();

      String? profileImageUrl;
      String? driverLicenseImageUrl;
      String? tricyclePlateImageUrl;
      String? passengerIdImageUrl;
      if (_profileImagePath != null && _profileImagePath!.isNotEmpty) {
        try {
          // Generate unique filename
          final email = _emailCntrl.text.trim();
          final fileName =
              'profile_${email.replaceAll('@', '_').replaceAll('.', '_')}_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final file = File(_profileImagePath!);

          // Upload to Supabase Storage
          await client.storage.from('avatars').upload(fileName, file);

          // Get public URL
          profileImageUrl =
              client.storage.from('avatars').getPublicUrl(fileName);

          print('Profile image uploaded successfully: $profileImageUrl');
        } catch (uploadError) {
          print('Failed to upload profile image: $uploadError');
          // Continue with registration even if image upload fails
          profileImageUrl = null;
        }
      }

      if (_driverLicenseImagePath != null &&
          _driverLicenseImagePath!.isNotEmpty) {
        try {
          final email = _emailCntrl.text.trim();
          final fileName =
              'license_${email.replaceAll('@', '_').replaceAll('.', '_')}_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final file = File(_driverLicenseImagePath!);
          await client.storage.from('avatars').upload(fileName, file);
          driverLicenseImageUrl =
              client.storage.from('avatars').getPublicUrl(fileName);
        } catch (_) {
          driverLicenseImageUrl = null;
        }
      }

      if (_tricyclePlateImagePath != null &&
          _tricyclePlateImagePath!.isNotEmpty) {
        try {
          final email = _emailCntrl.text.trim();
          final fileName =
              'plate_${email.replaceAll('@', '_').replaceAll('.', '_')}_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final file = File(_tricyclePlateImagePath!);
          await client.storage.from('avatars').upload(fileName, file);
          tricyclePlateImageUrl =
              client.storage.from('avatars').getPublicUrl(fileName);
        } catch (_) {
          tricyclePlateImageUrl = null;
        }
      }

      // Passenger ID image (required for Passenger)
      final selectedRoleLower = (selectedRole ?? '').toLowerCase();
      final isPassenger = selectedRoleLower == 'passenger';
      if (isPassenger) {
        // Validate that passenger ID image is provided
        if (_passengerIdImagePath == null || _passengerIdImagePath!.isEmpty) {
          if (!mounted) return;
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Passenger ID photo is required. Please capture your ID photo before registering.'),
              backgroundColor: kDanger,
              duration: Duration(seconds: 4),
            ),
          );
          return;
        }

        // Upload passenger ID image - this is REQUIRED for passengers
        try {
          final email = _emailCntrl.text.trim();
          final fileName =
              'passenger_id_${email.replaceAll('@', '_').replaceAll('.', '_')}_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final file = File(_passengerIdImagePath!);
          
          // Check if file exists
          if (!file.existsSync()) {
            if (!mounted) return;
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Passenger ID image file not found. Please capture your ID photo again.'),
                backgroundColor: kDanger,
                duration: Duration(seconds: 4),
              ),
            );
            return;
          }

          await client.storage.from('avatars').upload(fileName, file);
          passengerIdImageUrl =
              client.storage.from('avatars').getPublicUrl(fileName);
          
          // Verify upload was successful - getPublicUrl always returns a string
          if (passengerIdImageUrl.isEmpty) {
            throw Exception('Failed to get image URL after upload');
          }
        } catch (uploadError) {
          print('Failed to upload passenger ID image: $uploadError');
          if (!mounted) return;
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to upload passenger ID image: $uploadError. Please try again.'),
              backgroundColor: kDanger,
              duration: const Duration(seconds: 4),
            ),
          );
          return;
        }
      }

      // Prepare user data for insertion
      final userData = <String, dynamic>{
        'id': userId,
        'email': _emailCntrl.text.trim(),
        'full_name': _nameCntrl.text.trim(),
        'role': roleValue,
        'phone_number': _mobileCntrl.text.trim(),
        'profile_image': profileImageUrl, // NOW SAVES URL, NOT LOCAL PATH!
        'address': _addressCntrl.text.trim(),
        'status': 'active',
        'id_number': _idNumberCntrl.text.trim().isEmpty
            ? null
            : _idNumberCntrl.text.trim(),
        'driver_license_number': _driverLicenseNumberCntrl.text.trim().isEmpty
            ? null
            : _driverLicenseNumberCntrl.text.trim(),
        'driver_license_image': driverLicenseImageUrl,
        'tricycle_plate_number':
            _tricyclePlateNumberCntrl.text.trim().isEmpty
                ? null
                : _tricyclePlateNumberCntrl.text.trim(),
        'tricycle_plate_image': tricyclePlateImageUrl,
      };

      // For passengers, id_image is REQUIRED (not null)
      if (isPassenger) {
        // passengerIdImageUrl should already be validated and set above
        // But add a final check to be safe
        if (passengerIdImageUrl == null || passengerIdImageUrl.isEmpty) {
          if (!mounted) return;
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Passenger ID image upload failed. Please try again.'),
              backgroundColor: kDanger,
              duration: Duration(seconds: 4),
            ),
          );
          return;
        }
        userData['id_image'] = passengerIdImageUrl;
      } else {
        // For non-passengers, id_image can be null
        userData['id_image'] = null;
      }

      await client.from('users').insert(userData);

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.accountCreatedSuccessfully),
          backgroundColor: kGreen,
          duration: const Duration(seconds: 3),
        ),
      );

      setState(() {
        _isLogin = true;
      });

      // Save to local prefs for dashboard usage
      try {
        final pref = await PrefManager.getInstance();
        pref.userEmail = _emailCntrl.text.trim();
        pref.userName = _nameCntrl.text.trim();
        pref.userRole = roleValue;
        pref.userPhone = _mobileCntrl.text.trim();
        pref.userAddress = _addressCntrl.text.trim();
        pref.userImage = profileImageUrl; // Save URL, not local path
        // Set login status to true for persistent login
        pref.isLogin = true;
      } catch (_) {}

      // Face registration is now mandatory and happens BEFORE account creation
      // No need to offer it again here

      // Clear register form
      _nameCntrl.clear();
      _emailCntrl.clear();
      _mobileCntrl.clear();
      _addressCntrl.clear();
      _idNumberCntrl.clear();
      _driverLicenseNumberCntrl.clear();
      _tricyclePlateNumberCntrl.clear();
      _passCntrl.clear();
      _confirmPassCntrl.clear();
      setState(() {
        _profileImagePath = null;
        _driverLicenseImagePath = null;
        _tricyclePlateImagePath = null;
        _passengerIdImagePath = null;
        _faceIdRegistered = false;
        _tempFaceAuthId = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.registrationFailed(e.toString())),
          backgroundColor: kDanger,
        ),
      );
    }
  }

  void _navigateToDashboard() {
    // Add a small delay to show the success message
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        // Check user role from PrefManager to handle BPLO admin
        PrefManager.getInstance().then((pref) {
          final userRole = pref.userRole?.toLowerCase() ?? '';
          
          // Navigate based on actual user role from database
          if (userRole == 'lto_admin') {
            Navigator.of(context).pushReplacementNamed(BPLODashboard.routeName);
            return;
          }
          
          // Otherwise use selected role
        switch (selectedRole) {
          case "Passenger":
            Navigator.of(context)
                .pushReplacementNamed(PassengerDashboard.routeName);
            break;
          case "Driver":
            Navigator.of(context)
                .pushReplacementNamed(DriverDashboard.routeName);
            break;
          case "Admin":
            Navigator.of(context)
                .pushReplacementNamed(AdminDashboard.routeName);
            break;
          default:
            // Fallback to passenger dashboard if no role is selected
            Navigator.of(context)
                .pushReplacementNamed(PassengerDashboard.routeName);
        }
        });
      }
    });
  }

  void _fieldFocusChange(
      BuildContext context, FocusNode currentFocus, FocusNode nextFocus) {
    currentFocus.unfocus();
    FocusScope.of(context).requestFocus(nextFocus);
  }

  void _showProfileImagePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: kGrey,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Choose Profile Picture',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: kBlack,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildImagePickerOption(
                  icon: Icons.camera_alt,
                  label: 'Camera',
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromCamera();
                  },
                ),
                _buildImagePickerOption(
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromGallery();
                  },
                ),
                if (_profileImagePath != null)
                  _buildImagePickerOption(
                    icon: Icons.delete,
                    label: 'Remove',
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _profileImagePath = null;
                      });
                    },
                    color: kDanger,
                  ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePickerOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (color ?? kPrimaryColor).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color ?? kPrimaryColor,
              size: 32,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: color ?? kBlack,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImageFromCamera() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final cameraStatus = await Permission.camera.request();

        if (cameraStatus.isDenied || cameraStatus.isPermanentlyDenied) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                        AppLocalizations.of(context)!.cameraPermissionRequired),
                  ),
                ],
              ),
              backgroundColor: kDanger,
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: AppLocalizations.of(context)!.settings,
                textColor: Colors.white,
                onPressed: () => openAppSettings(),
              ),
            ),
          );
          return;
        }
      }

      final XFile? image = await _picker
          .pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      )
          .catchError((error) {
        // Handle platform-specific errors
        if (error.toString().contains('PlatformException')) {
          throw Exception(
              'Camera not supported on this platform. Please use a mobile device or emulator.');
        }
        throw error;
      });

      if (image != null) {
        setState(() {
          _profileImagePath = image.path;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(AppLocalizations.of(context)!.profilePictureUpdatedSuccessfully),
                ),
              ],
            ),
            backgroundColor: kGreen,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(e.toString().contains('not supported')
                    ? AppLocalizations.of(context)!.cameraWorksOnMobileOnly
                    : AppLocalizations.of(context)!.failedToCaptureImage),
              ),
            ],
          ),
          backgroundColor: kDanger,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        PermissionStatus storageStatus;

        if (Platform.isAndroid) {
          // For Android 13+ (API 33+), use photos permission
          final androidInfo = await DeviceInfoPlugin().androidInfo;
          if (androidInfo.version.sdkInt >= 33) {
            storageStatus = await Permission.photos.request();
          } else {
            // For older Android versions, use storage permission
            storageStatus = await Permission.storage.request();
          }
        } else {
          // For iOS
          storageStatus = await Permission.photos.request();
        }

        if (storageStatus.isDenied || storageStatus.isPermanentlyDenied) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                        AppLocalizations.of(context)!.storagePermissionRequired),
                  ),
                ],
              ),
              backgroundColor: kDanger,
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'Settings',
                textColor: Colors.white,
                onPressed: () => openAppSettings(),
              ),
            ),
          );
          return;
        }
      }

      final XFile? image = await _picker
          .pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      )
          .catchError((error) {
        // Handle platform-specific errors
        if (error.toString().contains('PlatformException')) {
          throw Exception(
              AppLocalizations.of(context)!.galleryNotSupported);
        }
        throw error;
      });

      if (image != null) {
        setState(() {
          _profileImagePath = image.path;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(AppLocalizations.of(context)!.profilePictureUpdatedSuccessfully),
                ),
              ],
            ),
            backgroundColor: kGreen,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(e.toString().contains('not supported')
                    ? 'Image picker works on mobile devices only'
                    : 'Failed to pick image. Please try again.'),
              ),
            ],
          ),
          backgroundColor: kDanger,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameCntrl.dispose();
    _mobileCntrl.dispose();
    _passCntrl.dispose();
    _confirmPassCntrl.dispose();
    _emailCntrl.dispose();
    _addressCntrl.dispose();
    _idNumberCntrl.dispose();
    _driverLicenseNumberCntrl.dispose();
    _tricyclePlateNumberCntrl.dispose();
    _nameNode.dispose();
    _mobileNode.dispose();
    _passwordNode.dispose();
    _confirmPassNode.dispose();
    _emailNode.dispose();
    _addressNode.dispose();
    _idNumberNode.dispose();
    _driverLicenseNode.dispose();
    _tricyclePlateNode.dispose();
    loginBloc.close();
    super.dispose();
  }

  Future<void> _captureDriverLicensePhoto() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final cameraStatus = await Permission.camera.request();
        if (cameraStatus.isDenied || cameraStatus.isPermanentlyDenied) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(AppLocalizations.of(context)!
                        .cameraPermissionRequired),
                  ),
                ],
              ),
              backgroundColor: kDanger,
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: AppLocalizations.of(context)!.settings,
                textColor: Colors.white,
                onPressed: () => openAppSettings(),
              ),
            ),
          );
          return;
        }
      }

      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _driverLicenseImagePath = image.path;
        });
        await _extractTextAndFill(image.path, _driverLicenseNumberCntrl);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(AppLocalizations.of(context)!.failedToCaptureImage),
              ),
            ],
          ),
          backgroundColor: kDanger,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _captureTricyclePlatePhoto() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final cameraStatus = await Permission.camera.request();
        if (cameraStatus.isDenied || cameraStatus.isPermanentlyDenied) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(AppLocalizations.of(context)!
                        .cameraPermissionRequired),
                  ),
                ],
              ),
              backgroundColor: kDanger,
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: AppLocalizations.of(context)!.settings,
                textColor: Colors.white,
                onPressed: () => openAppSettings(),
              ),
            ),
          );
          return;
        }
      }

      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _tricyclePlateImagePath = image.path;
        });
        await _extractTextAndFill(image.path, _tricyclePlateNumberCntrl);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(AppLocalizations.of(context)!.failedToCaptureImage),
              ),
            ],
          ),
          backgroundColor: kDanger,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _capturePassengerIdPhoto() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final cameraStatus = await Permission.camera.request();
        if (cameraStatus.isDenied || cameraStatus.isPermanentlyDenied) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child:
                        Text(AppLocalizations.of(context)!.cameraPermissionRequired),
                  ),
                ],
              ),
              backgroundColor: kDanger,
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: AppLocalizations.of(context)!.settings,
                textColor: Colors.white,
                onPressed: () => openAppSettings(),
              ),
            ),
          );
          return;
        }
      }

      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _passengerIdImagePath = image.path;
        });
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(AppLocalizations.of(context)!.failedToCaptureImage),
              ),
            ],
          ),
          backgroundColor: kDanger,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _extractTextAndFill(
      String imagePath, TextEditingController controller) async {
    try {
      if (!(Platform.isAndroid || Platform.isIOS)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Auto-fill from photo works only on Android and iOS devices.'),
            backgroundColor: kDanger,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }
      final inputImage = InputImage.fromFilePath(imagePath);
      final textRecognizer = TextRecognizer();
      final recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();
      final candidate = _extractBestNumberCandidate(recognizedText.text);
      if (candidate != null && candidate.isNotEmpty) {
        controller.text = candidate;
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Could not read a license or plate number from the photo.'),
            backgroundColor: kDanger,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Text recognition failed. Please try again or type it manually.'),
          backgroundColor: kDanger,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  String? _extractBestNumberCandidate(String text) {
    final tokens = text.split(RegExp(r'\s+'));
    String? best;
    for (final token in tokens) {
      final cleaned =
          token.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
      if (cleaned.length >= 4 && RegExp(r'[0-9]').hasMatch(cleaned)) {
        if (best == null || cleaned.length > best.length) {
          best = cleaned;
        }
      }
    }
    return best;
  }
}
