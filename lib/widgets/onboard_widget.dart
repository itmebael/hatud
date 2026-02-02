import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hatud_tricycle_app/common/my_colors.dart';
import 'package:hatud_tricycle_app/common/viiticons_icons.dart';
import 'package:hatud_tricycle_app/features/loginsignup/login/login_screen.dart';
import 'package:hatud_tricycle_app/widgets/fab_button.dart';
import 'package:hatud_tricycle_app/widgets/wave_animation_widget.dart';

import 'package:hatud_tricycle_app/common/responsive_helper.dart';

class OnboardWidget extends StatefulWidget {
  final List<String> images;
  final List<String> titles;
  final List<String> subtitles;
  final VoidCallback myOnSkipPressed;
  final VoidCallback myOnNextPressed;
  final int onTapImageIndex;

  const OnboardWidget({
    Key? key,
    required this.onTapImageIndex,
    required this.images,
    required this.titles,
    required this.subtitles,
    required this.myOnNextPressed,
    required this.myOnSkipPressed,
  }) : super(key: key);

  @override
  _OnboardWidgetState createState() => _OnboardWidgetState();
}

class _OnboardWidgetState extends State<OnboardWidget> {
  late final PageController _controller;
  late final PageController _controllerTitle;
  late int currentPageValue;

  @override
  void initState() {
    super.initState();
    currentPageValue = widget.onTapImageIndex;
    _controller = PageController(
      initialPage: widget.onTapImageIndex,
      viewportFraction: 1,
    );

    _controllerTitle = PageController(
      initialPage: widget.onTapImageIndex,
      viewportFraction: 1,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _controllerTitle.dispose();
    super.dispose();
  }

  int get _pageCount => [
        widget.images.length,
        widget.titles.length,
        widget.subtitles.length
      ].reduce(min);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        Size size = Size(constraints.maxWidth, 360.0);
        return Stack(
          children: <Widget>[
            //Static wave image
            /*Image.asset(
                "assets/onboarding_shape.png",
                width: constraints.maxWidth,
            )*/

            //Bottom wave animation
            Align(
              alignment: Alignment.bottomCenter,
              child: ColorCurveBodyBottom(
                size: size,
                xOffset: 20,
                yOffset: 86,
                color: kPrimaryColor,
              ),
            ),

            Align(
              alignment: Alignment.bottomCenter,
              child: ColorCurveBodyTop(
                size: size,
                xOffset: 10,
                yOffset: 50,
                color: kPrimaryColor,
              ),
            ),

            //Image slider
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                height: ResponsiveHelper.responsiveHeight(context,
                    mobile: 320, tablet: 400, desktop: 500),
                width: constraints.maxWidth,
                margin: EdgeInsets.only(
                    top: ResponsiveHelper.responsiveHeight(context,
                        mobile: 46, tablet: 60, desktop: 80)),
                child: PageView.builder(
                  physics: ClampingScrollPhysics(),
                  scrollDirection: Axis.horizontal,
                  itemCount: _pageCount,
                  onPageChanged: (int page) {
                    _controllerTitle.animateToPage(
                      page,
                      duration: const Duration(
                        milliseconds: 400,
                      ),
                      curve: Curves.easeInOut,
                    );
                    _getChangedPageAndMoveBar(page);
                  },
                  controller: _controller,
                  itemBuilder: (BuildContext ctxt, int index) {
                    return _buildImage(index, widget.images[index]);
                  },
                ),
              ),
            ),

            // Onboarding title and subtitles
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                constraints: BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    Container(
                      height: 150,
                      child: PageView.builder(
                        physics: ClampingScrollPhysics(),
                        scrollDirection: Axis.horizontal,
                        itemCount: _pageCount,
                        controller: _controllerTitle,
                        onPageChanged: (int page) {
                          _controller.animateToPage(
                            page,
                            duration: const Duration(
                              milliseconds: 400,
                            ),
                            curve: Curves.easeInOut,
                          );
                          _getChangedPageAndMoveBar(page);
                        },
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: EdgeInsets.only(
                              left: ResponsiveHelper.responsiveWidth(context,
                                  mobile: 28, tablet: 36, desktop: 48),
                              right: ResponsiveHelper.responsiveWidth(context,
                                  mobile: 18, tablet: 24, desktop: 32),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: <Widget>[
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    widget.titles[index],
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium!
                                        .copyWith(
                                          color: Colors.white,
                                          fontSize: ResponsiveHelper.headlineSize(
                                              context), // Responsive font size
                                          fontWeight: FontWeight.w500,
                                          letterSpacing: 0.8,
                                          wordSpacing: 0.3,
                                        ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                SizedBox(
                                  height: 6,
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Opacity(
                                    opacity: 0.8,
                                    child: Text(
                                      widget.subtitles[index],
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall!
                                          .copyWith(
                                            color: Colors.white,
                                            fontSize:
                                                ResponsiveHelper.bodySize(context),
                                            letterSpacing: 1.0,
                                            fontWeight: FontWeight.normal,
                                            height: 1.1,
                                          ),
                                      maxLines: 5,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(
                      height: 21,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 28,
                        right: 18,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          GestureDetector(
                            onTap: widget.myOnSkipPressed,
                            child: Text(
                              "Skip",
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium!
                                  .copyWith(
                                    color: kAccentColor,
                                  ),
                            ),
                          ),
                          Container(
                            margin: EdgeInsets.fromLTRB(8, 24, 8, 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: _getCircles(currentPageValue),
                            ),
                          ),
                          FABButton(
                              bgColor: Colors.white,
                              icon: Icon(
                                Viiticons.next_arrow,
                                color: kPrimaryColor,
                                size: 18,
                              ),
                              onTap: () {
                                final lastPageIndex = _pageCount - 1;
                                if (currentPageValue >= lastPageIndex) {
                                  Navigator.of(context).pushReplacementNamed(
                                      LoginScreen.routeName);
                                } else {
                                  ++currentPageValue;
                                  _controller.animateToPage(
                                    currentPageValue,
                                    duration: const Duration(milliseconds: 400),
                                    curve: Curves.easeInOut,
                                  );
                                  _getChangedPageAndMoveBar(currentPageValue);
                                }
                              })
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 21,
                    )
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  _buildImage(int index, String image) {
    return Padding(
      padding: const EdgeInsets.only(right: 0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.transparent,
          image: DecorationImage(
            fit: BoxFit.scaleDown,
            image: AssetImage("$image"),
          ),
        ),
      ),
    );
  }

  _getChangedPageAndMoveBar(int page) {
    currentPageValue = page;
    setState(() {});
  }

  _getCircles(int selectedIndex) {
    List<Widget> circleList = [];

    for (int i = 0; i < _pageCount; i++) {
      circleList.add(
        CircleBarWidget(selectedIndex == i, () {
          _controller.animateToPage(
            i,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
          );
          currentPageValue = i;
          setState(() {});
        }),
      );
    }

    return circleList;
  }

  Widget CircleBarWidget(bool isActive, var _myOnTap) {
    return GestureDetector(
      onTap: _myOnTap,
      child: AnimatedContainer(
        duration: const Duration(
          milliseconds: 400,
        ),
        margin: EdgeInsets.symmetric(horizontal: 8),
        height: isActive ? 14 : 12,
        width: isActive ? 14 : 12,
        decoration: BoxDecoration(
          color: isActive ? kAccentColor : Colors.white,
          borderRadius: BorderRadius.all(
            Radius.circular(12),
          ),
        ),
      ),
    );
    /* return Theme(
      data: isActive ? ThemeData.light() : ThemeData.dark(),
      child: Radio(
        value: isActive ? null : 1,
        activeColor: kAccentColor,
        onChanged: (int value) {
          print("");
        },
        groupValue: null,
      ),
    );*/
  }
}
