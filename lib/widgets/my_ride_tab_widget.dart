import 'package:flutter/material.dart';
import 'package:hatud_tricycle_app/common/my_colors.dart';

class MyRideTabWidget extends StatelessWidget {
  final GestureTapCallback onTapUpcoming;
  final GestureTapCallback onTapComplet;
  final GestureTapCallback onTapCancele;
  final bool upcomingRideSelect;
  final bool completRideSelect;
  final bool canceledRideSelect;

  const MyRideTabWidget({
    Key? key,
    required this.onTapUpcoming,
    required this.onTapComplet,
    required this.onTapCancele,
    required this.upcomingRideSelect,
    required this.completRideSelect,
    required this.canceledRideSelect,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20),
      child: Column(
        children: [
          Container(
            height: 45,
            width: MediaQuery.of(context).size.width, // this will give you fle
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  width: 1,
                  color: kAccentColor,
                )), // flexible width not fixed width
            child: new Row(
              children: <Widget>[
                Expanded(
                    flex: 1,
                    child: GestureDetector(
                      onTap: onTapUpcoming,
                      child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(10),
                              bottomLeft: const Radius.circular(10),
                            ),
                            color: upcomingRideSelect
                                ? kAccentColor
                                : Colors.white,
                          ),
                          alignment: Alignment.topCenter,
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Text(
                                  'Upcoming',
                                  style: TextStyle(
                                    fontSize: 16.0,
                                    color: upcomingRideSelect
                                        ? Colors.white
                                        : kLoginBlack,
                                  ),
                                ),
                                //varaible above
                              ],
                            ),
                          )),
                    )),
                Expanded(
                    flex: 1,
                    child: GestureDetector(
                      onTap: onTapComplet,
                      child: Container(
                          alignment: Alignment.bottomCenter,
                          decoration: BoxDecoration(
                            border: Border(
                              left: BorderSide(
                                width: 1.0,
                                color: kAccentColor,
                              ),
                              right: BorderSide(
                                width: 1.0,
                                color: kAccentColor,
                              ),
                            ),
                            color:
                                completRideSelect ? kAccentColor : Colors.white,
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Text('Completed',
                                    style: TextStyle(
                                      fontSize: 16.0,
                                      color: completRideSelect
                                          ? Colors.white
                                          : kLoginBlack,
                                    )),
                                //varaible above
                              ],
                            ),
                          )),
                    )),
                Expanded(
                    flex: 1,
                    child: GestureDetector(
                      onTap: onTapCancele,
                      child: Container(
                          alignment: Alignment.bottomCenter,
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.only(
                                topRight: const Radius.circular(10),
                                bottomRight: const Radius.circular(10),
                              ),
                              color: canceledRideSelect
                                  ? Color(0xffF3AA05)
                                  : Colors.white),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Text("Canceled",
                                    style: TextStyle(
                                        fontSize: 16.0,
                                        color: canceledRideSelect
                                            ? Colors.white
                                            : kLoginBlack,
                                        fontWeight: FontWeight.w500)),
                                //varaible above
                              ],
                            ),
                          )),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
