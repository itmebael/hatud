import 'package:flutter/material.dart';
import 'package:hatud_tricycle_app/common/responsive_helper.dart';

class FABButton extends StatelessWidget {
  final Color bgColor;
  final Icon icon;
  final VoidCallback onTap;
  final double? myHeight;
  final double? myWidth;

  const FABButton({
    Key? key,
    required this.bgColor,
    required this.icon,
    required this.onTap,
    this.myHeight,
    this.myWidth,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    /*return FloatingActionButton(
      elevation: 0,
      mini: false,
      onPressed: onTap,
      child: icon,
      backgroundColor: bgColor,
    );*/

    return GestureDetector(
      onTap: onTap,
      child: ClipOval(
        child: Container(
          child: icon,
          color: bgColor,
          width: myWidth ?? ResponsiveHelper.responsiveWidth(context, mobile: 50, tablet: 60, desktop: 70),
          height: myHeight ?? ResponsiveHelper.responsiveWidth(context, mobile: 50, tablet: 60, desktop: 70),
        ),
      ),
    );
  }
}
