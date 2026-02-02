import 'package:flutter/material.dart';

class SelectedVehicelTypeWidget extends StatelessWidget {
  final bool isSelected;
  final GestureTapCallback myOnTap;
  final String icon;

  const SelectedVehicelTypeWidget({
    Key? key,
    required this.isSelected,
    required this.myOnTap,
    required this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: myOnTap,
      child: Container(
        height: 56,
        width: 56,
        decoration: BoxDecoration(
          color: isSelected ? Color(0XFF275687) : Colors.grey,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: isSelected
              ? Image.asset(
                  icon,
                  height: 30,
                  width: 30,
                  color: Colors.white,
                )
              : Image.asset(
                  icon,
                  height: 30,
                  width: 30,
                ),
        ),
      ),
    );
  }
}
