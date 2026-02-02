import 'package:flutter/material.dart';
import 'package:hatud_tricycle_app/common/my_colors.dart';
import 'package:hatud_tricycle_app/common/responsive_helper.dart';

class LanguageButton extends StatelessWidget {
  final Color btnColor;
  final Color btnBorderColor;
  final String btnTxt;
  final VoidCallback? btnOnTap;
  final bool isShowIcon;

  const LanguageButton({
    Key? key,
    this.btnColor = kPrimaryColor,
    this.btnBorderColor = Colors.white,
    required this.btnTxt,
    this.btnOnTap,
    this.isShowIcon = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Calculate responsive dimensions
    final screenWidth = MediaQuery.of(context).size.width;
    final minButtonWidth = ResponsiveHelper.responsiveWidth(
      context,
      mobile: 280,
      tablet: 320,
      desktop: 360,
    );
    final buttonHeight = ResponsiveHelper.responsiveHeight(
      context,
      mobile: 52,
      tablet: 56,
      desktop: 60,
    );
    final iconSize = ResponsiveHelper.responsiveWidth(
      context,
      mobile: 28,
      tablet: 30,
      desktop: 32,
    );
    final iconContainerSize = ResponsiveHelper.responsiveWidth(
      context,
      mobile: 28,
      tablet: 30,
      desktop: 32,
    );
    final horizontalPadding = ResponsiveHelper.responsiveWidth(
      context,
      mobile: 20,
      tablet: 24,
      desktop: 28,
    );
    final iconRightPadding = ResponsiveHelper.responsiveWidth(
      context,
      mobile: 12,
      tablet: 14,
      desktop: 16,
    );
    
    // Calculate button width: use screen width with margins, but ensure minimum width
    final calculatedWidth = screenWidth * 0.85;
    final buttonWidth = ResponsiveHelper.isDesktop(context)
        ? 400.0
        : calculatedWidth.clamp(minButtonWidth, 500.0);

    return Stack(
      children: <Widget>[
        SizedBox(
          width: buttonWidth,
          height: buttonHeight,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24.0),
                side: const BorderSide(color: Colors.white, width: 2),
              ),
              backgroundColor: btnColor,
              padding: EdgeInsets.zero, // Remove default padding
            ),
            onPressed: btnOnTap,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Builder(
                      builder: (context) {
                        final captionStyle = Theme.of(context).textTheme.caption;
                        return Text(
                          btnTxt,
                          style: captionStyle.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: ResponsiveHelper.bodySize(context),
                            color: Colors.white,
                            letterSpacing: 0.4,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        );
                      },
                    ),
                  ),
                  if (isShowIcon) SizedBox(width: iconContainerSize + 4), // Space for icon
                ],
              ),
            ),
          ),
        ),
        if (isShowIcon)
          Positioned(
            right: iconRightPadding,
            top: (buttonHeight - iconContainerSize) / 2,
            child: Container(
              height: iconContainerSize,
              width: iconContainerSize,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(iconContainerSize / 2),
                color: Colors.white,
              ),
              child: Icon(
                Icons.chevron_right,
                color: Color(0XFF275687),
                size: iconSize * 0.6,
              ),
            ),
          ),
      ],
    );
  }
}
