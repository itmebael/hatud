import 'package:flutter/material.dart';
import 'package:hatud_tricycle_app/common/my_colors.dart';

class MyRadioText extends StatefulWidget {
  final String text;
  final int myVal;
  final int myGroupVal;
  final ValueChanged<int?> myOnChanged;

  const MyRadioText({
    Key? key,
    required this.text,
    required this.myVal,
    required this.myGroupVal,
    required this.myOnChanged,
  }) : super(key: key);

  @override
  _MyRadioTextState createState() => _MyRadioTextState();
}

class _MyRadioTextState extends State<MyRadioText> {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: <Widget>[
        Radio<int>(
          value: widget.myVal,
          activeColor: kPrimaryColor,
          groupValue: widget.myGroupVal,
          onChanged: widget.myOnChanged,
        ),
        Text(
          widget.text,
          style: Theme.of(context).textTheme.caption.copyWith(
                color: kPrimaryColor,
                fontSize: 17,
              ),
        )
      ],
    );
  }
}
