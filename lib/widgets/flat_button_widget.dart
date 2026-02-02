import 'package:flutter/material.dart';

class FlatButtonWidget extends StatelessWidget {
  final Color btnColor;
  final String btnTxt;
  final VoidCallback btnOnTap;
  final double height;

  const FlatButtonWidget({
    Key? key,
    required this.btnColor,
    required this.btnTxt,
    required this.btnOnTap,
    this.height = 50,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      child: TextButton(
        style: TextButton.styleFrom(
          backgroundColor: btnColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28.0),
          ),
        ),
        onPressed: btnOnTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 0,
            horizontal: 12,
          ),
          child: Text(
            btnTxt,
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
                  fontSize: 18,
                  color: Colors.white,
                ),
          ),
        ),
      ),
    );
  }
}
