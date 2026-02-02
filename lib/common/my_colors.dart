import 'package:flutter/material.dart';

const kPrimaryColor = Color(0xFFFF6B35); // Orange primary color
const kAccentColor = Color(0xFFFF8C42); // Lighter orange accent
const Color kBlack = Color(0xFF030303);
const Color kLoginBlack = Color(0xFF060518);
const Color kSocialBg = Color(0xFFFFF4F0); // Light orange background
const Color kTextLoginfaceid = Color(0xFF8F92A1);
const Color kDottedBorder = Color(0xFFFF6B35); // Orange dotted border
const Color kDottedBorderFab = Color(0xFFFF8C42); // Lighter orange for FAB
const Color kNavItemSelected =
    Color(0xFFFFE5D9); // Light orange for selected nav
const Color kSettingTopBg = Color(0xFFFFF4F0); // Light orange background
const Color kSettingFavAddAvtarBg =
    Color(0xFFFFE5D9); // Light orange for avatars
const Color kDanger = Color(0xFFDF2E21);
const Color kGrey = Color(0xFFE8E4E4);
const Color kShareCodeBg = Color(0xFFFFF4F0); // Light orange background
const Color kSettingDivider = Color(0xFFFFE5D9); // Light orange divider
const String kLoremText =
    "Lorem Ipsum is simply dummy text of the printing and typesetting. ";
const Color kGreen = Color(0xFF28B446);

// Additional orange theme colors
const Color kOrangeLight = Color(0xFFFFE5D9); // Very light orange
const Color kOrangeMedium = Color(0xFFFF8C42); // Medium orange
const Color kOrangeDark = Color(0xFFE55A2B); // Dark orange
const Color kOrangeGradientStart = Color(0xFFFF6B35); // Gradient start
const Color kOrangeGradientEnd = Color(0xFFFF8C42); // Gradient end

// TextTheme compatibility for older getters used across the app.
// Maps legacy Material 2 names to Material 3 equivalents so call sites keep working.
extension TextThemeCompat on TextTheme {
  TextStyle get caption => bodySmall ?? const TextStyle();
  TextStyle get subhead => titleMedium ?? const TextStyle();
  TextStyle get title => titleLarge ?? const TextStyle();
  TextStyle get headline => headlineSmall ?? const TextStyle();
  TextStyle get body1 => bodyLarge ?? const TextStyle();
  TextStyle get body2 => bodyMedium ?? const TextStyle();
  TextStyle get button => labelLarge ?? const TextStyle();
}
