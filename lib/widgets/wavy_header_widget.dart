import 'package:flutter/material.dart';
import 'package:hatud_tricycle_app/common/my_colors.dart';
import 'package:hatud_tricycle_app/widgets/viit_appbar.dart';
import 'package:hatud_tricycle_app/common/responsive_helper.dart';

class WavyHeader extends StatelessWidget {
  final bool isBack;
  final VoidCallback? onBackTap;

  const WavyHeader({
    Key? key,
    this.isBack = false,
    this.onBackTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        ClipPath(
          child: Container(
            height: ResponsiveHelper.responsiveHeight(context, mobile: 200, tablet: 250, desktop: 300),
            decoration: BoxDecoration(
              color: kPrimaryColor,
            ),
          ),
          clipper: BottomWaveClipper(),
        ),
        Positioned(
          top: ResponsiveHelper.responsiveHeight(context, mobile: 70, tablet: 90, desktop: 110),
          left: 0,
          right: 0,
          child: Center(
            child: Column(
              children: <Widget>[
                Container(
                  height: ResponsiveHelper.responsiveWidth(context, mobile: 130, tablet: 150, desktop: 170),
                  width: ResponsiveHelper.responsiveWidth(context, mobile: 130, tablet: 150, desktop: 170),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(ResponsiveHelper.responsiveWidth(context, mobile: 130, tablet: 150, desktop: 170) / 2),
                    border: Border.all(
                      width: 5,
                      color: kPrimaryColor,
                    ),
                    color: Colors.white,
                  ),
                  child: Center(
                    child: Image.asset(
                      "assets/logo_small.png",
                      height: ResponsiveHelper.responsiveWidth(context, mobile: 72, tablet: 90, desktop: 110),
                      width: ResponsiveHelper.responsiveWidth(context, mobile: 72, tablet: 90, desktop: 110),
                    ),
                  ))],
            ),
          ),
        ),
        isBack
            ? GestureDetector(
                onTap: onBackTap,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: ViitAppBarIconWidget(
                      viitAppBarIconType: ViitAppBarIconTypes.BACK,
                    ),
                  ),
                ),
              )
            : SizedBox(),
      ],
    );
  }
}

class BottomWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = new Path();
    path.lineTo(0.0, size.height);
    var secondControlPoint =
        Offset(size.width - (size.width / 2), size.height * 0.4);
    var secondEndPoint = Offset(size.width, size.height);
    path.quadraticBezierTo(secondControlPoint.dx, secondControlPoint.dy,
        secondEndPoint.dx, secondEndPoint.dy);
    path.lineTo(size.width, size.height - 5);
    path.lineTo(size.width, 0.0);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
