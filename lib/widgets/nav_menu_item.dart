import 'package:flutter/material.dart';
import 'package:hatud_tricycle_app/common/my_colors.dart';
import 'package:hatud_tricycle_app/common/responsive_helper.dart';

class NavMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final double? iconSize;
  final BuildContext context;
  final GestureTapCallback myOnTap;
  final NavItemDecorationType navDecorationType;

  const NavMenuItem({
    Key? key,
    required this.context,
    required this.icon,
    required this.title,
    required this.myOnTap,
    this.iconSize,
    this.navDecorationType = NavItemDecorationType.NONE,
  }) : super(key: key);

  EdgeInsets buildMargin() {
    final spacing = ResponsiveHelper.responsiveWidth(
      context,
      mobile: 8,
      tablet: 10,
      desktop: 12,
    );
    switch (navDecorationType) {
      case NavItemDecorationType.SELECTED:
      case NavItemDecorationType.NONE:
        return EdgeInsets.only(
          left: 0,
          top: spacing,
          right: ResponsiveHelper.responsiveWidth(
            context,
            mobile: 16,
            tablet: 20,
            desktop: 24,
          ),
        );
      default:
        return EdgeInsets.all(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final responsiveIconSize = iconSize ?? ResponsiveHelper.iconSize(context);
    final responsiveHeight = ResponsiveHelper.responsiveHeight(
      context,
      mobile: 42,
      tablet: 48,
      desktop: 52,
    );
    final responsivePadding = ResponsiveHelper.responsiveWidth(
      context,
      mobile: 20,
      tablet: 24,
      desktop: 28,
    );
    final responsiveSpacing = ResponsiveHelper.responsiveWidth(
      context,
      mobile: 10,
      tablet: 12,
      desktop: 16,
    );
    final responsiveFontSize = ResponsiveHelper.bodySize(context);
    final responsiveLetterSpacing = ResponsiveHelper.isMobile(context) ? 0.5 : 0.8;

    return GestureDetector(
      onTap: myOnTap,
      child: Container(
        height: responsiveHeight,
        decoration: buildDecoration(),
        margin: buildMargin(),
        padding: EdgeInsets.only(left: responsivePadding),
        child: Row(
          children: <Widget>[
            Icon(
              icon,
              size: responsiveIconSize * 0.9,
              color: navDecorationType == NavItemDecorationType.HIGHLIGHTED
                  ? Colors.white
                  : kLoginBlack,
            ),
            Padding(
              padding: EdgeInsets.only(left: responsiveSpacing),
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium!.copyWith(
                      color:
                          navDecorationType == NavItemDecorationType.HIGHLIGHTED
                              ? Colors.white
                              : kLoginBlack,
                      fontWeight: FontWeight.normal,
                      fontSize: responsiveFontSize,
                      letterSpacing: responsiveLetterSpacing,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration? buildDecoration() {
    switch (navDecorationType) {
      case NavItemDecorationType.SELECTED:
        return BoxDecoration(
          color: kNavItemSelected,
          borderRadius: BorderRadius.horizontal(
            left: Radius.zero,
            right: Radius.circular(32.0),
          ),
        );
      case NavItemDecorationType.HIGHLIGHTED:
        return BoxDecoration(
          color: kPrimaryColor,
        );
      default:
        return null;
    }
  }
}

enum NavItemDecorationType { NONE, SELECTED, HIGHLIGHTED }
