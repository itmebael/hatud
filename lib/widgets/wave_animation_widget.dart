import 'dart:math';

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math.dart' as Vector;

class ColorCurveBodyTop extends StatefulWidget {
  final Size size;
  final int xOffset;
  final int yOffset;
  final Color color;
  const ColorCurveBodyTop({
    Key? key,
    required this.size,
    required this.xOffset,
    required this.yOffset,
    required this.color,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return new _ColorCurveBodyState();
  }
}

class _ColorCurveBodyState extends State<ColorCurveBodyTop>
    with TickerProviderStateMixin {
  late final AnimationController animationController;
  List<Offset> animList1 = [];

  @override
  void initState() {
    super.initState();
    animationController =
        AnimationController(vsync: this, duration: const Duration(seconds: 4));
    animationController.addListener(() {
      animList1.clear();
      for (int i = -2 - widget.xOffset;
          i <= widget.size.width.toInt() + 2;
          i++) {
        animList1.add(Offset(
            i.toDouble() + widget.xOffset,
            sin((animationController.value * 360 - i) %
                        360 *
                        Vector.degrees2Radians) *
                    20 +
                50 +
                widget.yOffset));
      }
    });
    animationController.repeat();
  }

  @override
  void dispose() {
    animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Container(
          height: widget.size.height,
          alignment: Alignment.center,
          child: AnimatedBuilder(
            animation: CurvedAnimation(
              parent: animationController,
              curve: Curves.easeInOut,
            ),
            builder: (context, child) => ClipPath(
              child: Container(
                width: widget.size.width,
                height: widget.size.height,
                color: widget.color,
              ),
              clipper: WaveClipper(animationController.value, animList1),
            ),
          ),
        )
      ],
    );
  }
}

class ColorCurveBodyBottom extends StatefulWidget {
  final Size size;
  final int xOffset;
  final int yOffset;
  final Color color;
  const ColorCurveBodyBottom({
    Key? key,
    required this.size,
    required this.xOffset,
    required this.yOffset,
    required this.color,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return new _ColorCurveBodyStateBottom();
  }
}

class _ColorCurveBodyStateBottom extends State<ColorCurveBodyBottom>
    with TickerProviderStateMixin {
  late final AnimationController animationController;
  List<Offset> animList1 = [];

  @override
  void initState() {
    super.initState();
    animationController =
        AnimationController(vsync: this, duration: const Duration(seconds: 3));
    animationController.addListener(() {
      animList1.clear();
      for (int i = -2 - widget.xOffset;
          i <= widget.size.width.toInt() + 2;
          i++) {
        animList1.add(Offset(
            i.toDouble() + widget.xOffset,
            cos((animationController.value * 360 - i) %
                        360 *
                        Vector.degrees2Radians) *
                    20 +
                widget.yOffset));
      }
    });
    animationController.repeat();
  }

  @override
  void dispose() {
    animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Container(
          height: widget.size.height,
          alignment: Alignment.center,
          child: AnimatedBuilder(
            animation: CurvedAnimation(
              parent: animationController,
              curve: Curves.easeInOut,
            ),
            builder: (context, child) => ClipPath(
              child: Container(
                width: widget.size.width,
                height: widget.size.height,
                color: Colors.orange,
              ),
              clipper: WaveClipper(animationController.value, animList1),
            ),
          ),
        )
      ],
    );
  }
}

class WaveClipper extends CustomClipper<Path> {
  final double animation;

  List<Offset> waveList1 = [];

  WaveClipper(this.animation, this.waveList1);

  @override
  Path getClip(Size size) {
    Path path = Path();

    path.addPolygon(waveList1, false);

    path.lineTo(size.width, size.height);
    path.lineTo(0.0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(WaveClipper oldClipper) =>
      animation != oldClipper.animation;
}
