import 'package:flutter/material.dart';

/// Responsive helper utility for building responsive designs
/// Supports mobile, tablet, and desktop layouts
class ResponsiveHelper {
  // Screen size breakpoints
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 1000;

  /// Get screen width
  static double screenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  /// Get screen height
  static double screenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  /// Check if device is mobile
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileBreakpoint;
  }

  /// Check if device is tablet
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < tabletBreakpoint;
  }

  /// Check if device is desktop
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= tabletBreakpoint;
  }

  /// Get device orientation
  static Orientation getOrientation(BuildContext context) {
    return MediaQuery.of(context).orientation;
  }

  /// Check if landscape mode
  static bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }

  /// Check if portrait mode
  static bool isPortrait(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.portrait;
  }

  // ==================== Responsive Spacing ====================

  /// Get responsive padding based on screen size
  static EdgeInsets responsivePadding(BuildContext context) {
    if (isMobile(context)) {
      return EdgeInsets.all(12);
    } else if (isTablet(context)) {
      return EdgeInsets.all(16);
    } else {
      return EdgeInsets.all(24);
    }
  }

  /// Get responsive horizontal padding
  static EdgeInsets responsiveHorizontalPadding(BuildContext context) {
    if (isMobile(context)) {
      return EdgeInsets.symmetric(horizontal: 12);
    } else if (isTablet(context)) {
      return EdgeInsets.symmetric(horizontal: 16);
    } else {
      return EdgeInsets.symmetric(horizontal: 24);
    }
  }

  /// Get responsive vertical padding
  static EdgeInsets responsiveVerticalPadding(BuildContext context) {
    if (isMobile(context)) {
      return EdgeInsets.symmetric(vertical: 12);
    } else if (isTablet(context)) {
      return EdgeInsets.symmetric(vertical: 16);
    } else {
      return EdgeInsets.symmetric(vertical: 24);
    }
  }

  /// Get responsive SizedBox height
  static double responsiveHeight(BuildContext context, {
    required double mobile,
    double? tablet,
    double? desktop,
  }) {
    if (isDesktop(context) && desktop != null) {
      return desktop;
    } else if (isTablet(context) && tablet != null) {
      return tablet;
    }
    return mobile;
  }

  /// Get responsive SizedBox width
  static double responsiveWidth(BuildContext context, {
    required double mobile,
    double? tablet,
    double? desktop,
  }) {
    if (isDesktop(context) && desktop != null) {
      return desktop;
    } else if (isTablet(context) && tablet != null) {
      return tablet;
    }
    return mobile;
  }

  // ==================== Responsive Font Sizes ====================

  /// Get responsive font size for headlines
  static double headlineSize(BuildContext context) {
    if (isMobile(context)) {
      return 20;
    } else if (isTablet(context)) {
      return 24;
    } else {
      return 32;
    }
  }

  /// Get responsive font size for titles
  static double titleSize(BuildContext context) {
    if (isMobile(context)) {
      return 16;
    } else if (isTablet(context)) {
      return 18;
    } else {
      return 24;
    }
  }

  /// Get responsive font size for body text
  static double bodySize(BuildContext context) {
    if (isMobile(context)) {
      return 14;
    } else if (isTablet(context)) {
      return 15;
    } else {
      return 16;
    }
  }

  /// Get responsive font size for small text
  static double smallSize(BuildContext context) {
    if (isMobile(context)) {
      return 12;
    } else if (isTablet(context)) {
      return 13;
    } else {
      return 14;
    }
  }

  // ==================== Responsive Widget Dimensions ====================

  /// Get responsive card height
  static double cardHeight(BuildContext context) {
    if (isMobile(context)) {
      return 120;
    } else if (isTablet(context)) {
      return 140;
    } else {
      return 160;
    }
  }

  /// Get responsive icon size
  static double iconSize(BuildContext context) {
    if (isMobile(context)) {
      return 24;
    } else if (isTablet(context)) {
      return 32;
    } else {
      return 40;
    }
  }

  /// Get responsive button height
  static double buttonHeight(BuildContext context) {
    if (isMobile(context)) {
      return 44;
    } else if (isTablet(context)) {
      return 48;
    } else {
      return 52;
    }
  }

  /// Get responsive map height
  static double mapHeight(BuildContext context) {
    if (isMobile(context)) {
      return screenHeight(context) * 0.35;
    } else if (isTablet(context)) {
      return screenHeight(context) * 0.45;
    } else {
      return screenHeight(context) * 0.55;
    }
  }
  
  /// Get responsive dialog width
  static double dialogWidth(BuildContext context) {
    if (isMobile(context)) {
      return screenWidth(context) * 0.9;
    } else if (isTablet(context)) {
      return screenWidth(context) * 0.7;
    } else {
      return 600; // Max width for desktop
    }
  }
  
  /// Get responsive dialog padding
  static EdgeInsets dialogPadding(BuildContext context) {
    if (isMobile(context)) {
      return EdgeInsets.all(16);
    } else if (isTablet(context)) {
      return EdgeInsets.all(20);
    } else {
      return EdgeInsets.all(24);
    }
  }
  
  /// Get responsive icon size for dialogs
  static double dialogIconSize(BuildContext context) {
    if (isMobile(context)) {
      return 28;
    } else if (isTablet(context)) {
      return 36;
    } else {
      return 40;
    }
  }
  
  /// Get responsive button padding
  static EdgeInsets buttonPadding(BuildContext context) {
    if (isMobile(context)) {
      return EdgeInsets.symmetric(horizontal: 16, vertical: 12);
    } else if (isTablet(context)) {
      return EdgeInsets.symmetric(horizontal: 20, vertical: 14);
    } else {
      return EdgeInsets.symmetric(horizontal: 24, vertical: 16);
    }
  }

  // ==================== Responsive Grid ====================

  /// Get number of columns for grid based on screen size
  static int gridColumns(BuildContext context) {
    if (isMobile(context)) {
      return 2;
    } else if (isTablet(context)) {
      return 3;
    } else {
      return 4;
    }
  }

  /// Get responsive grid spacing
  static double gridSpacing(BuildContext context) {
    if (isMobile(context)) {
      return 8;
    } else if (isTablet(context)) {
      return 12;
    } else {
      return 16;
    }
  }

  // ==================== Responsive Widget Builders ====================

  /// Get responsive max width for content
  static double maxContentWidth(BuildContext context) {
    if (isMobile(context)) {
      return screenWidth(context);
    } else if (isTablet(context)) {
      return screenWidth(context) * 0.9;
    } else {
      return 1200; // Desktop max width
    }
  }

  /// Get responsive container width for flex layouts
  static double containerWidth(BuildContext context, {required int flex}) {
    final width = screenWidth(context);
    if (isMobile(context)) {
      return width; // Full width on mobile
    } else if (isTablet(context)) {
      return width * 0.8;
    } else {
      return width * 0.7;
    }
  }

  /// Create a responsive SafeArea padding
  static Widget responsiveSafeArea({
    required Widget child,
    bool top = true,
    bool bottom = true,
    bool left = true,
    bool right = true,
  }) {
    return SafeArea(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: child,
    );
  }
}

/// Responsive Column Widget - Adapts to screen size
class ResponsiveColumn extends StatelessWidget {
  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisAlignment mainAxisAlignment;
  final MainAxisSize mainAxisSize;

  const ResponsiveColumn({
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.max,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      mainAxisAlignment: mainAxisAlignment,
      mainAxisSize: mainAxisSize,
      children: children,
    );
  }
}

/// Responsive Row Widget - Adapts to screen size
class ResponsiveRow extends StatelessWidget {
  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisAlignment mainAxisAlignment;
  final MainAxisSize mainAxisSize;

  const ResponsiveRow({
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.max,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: crossAxisAlignment,
      mainAxisAlignment: mainAxisAlignment,
      mainAxisSize: mainAxisSize,
      children: children,
    );
  }
}

/// Responsive Grid Widget - Adapts columns based on screen size
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double spacing;

  const ResponsiveGrid({
    required this.children,
    this.spacing = 8,
  });

  @override
  Widget build(BuildContext context) {
    final columns = ResponsiveHelper.gridColumns(context);
    return GridView.count(
      crossAxisCount: columns,
      crossAxisSpacing: spacing,
      mainAxisSpacing: spacing,
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      children: children,
    );
  }
}

















