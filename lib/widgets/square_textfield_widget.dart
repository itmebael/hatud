import 'package:flutter/material.dart';
import 'package:hatud_tricycle_app/common/my_colors.dart';
import 'package:hatud_tricycle_app/common/responsive_helper.dart';

class SquareTextFieldWidget extends StatelessWidget {
  final double? myHeight;
  final TextEditingController? myController;
  final String? hintText;
  final TextInputType inputType;
  final TextInputAction inputAction;
  final EdgeInsetsGeometry myMargin;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmited;

  const SquareTextFieldWidget({
    Key? key,
    this.myHeight,
    this.myController,
    this.myMargin = const EdgeInsets.all(0),
    this.hintText,
    this.inputType = TextInputType.text,
    this.inputAction = TextInputAction.done,
    this.onChanged,
    this.onSubmited,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(
        left: 8,
        right: 8,
        bottom: 2,
      ),
      margin: myMargin,
      height: myHeight ?? ResponsiveHelper.responsiveHeight(context, mobile: 48, tablet: 56, desktop: 64),
      decoration: BoxDecoration(
        color: Color(0XFFF2F2F4),
        borderRadius: BorderRadius.circular(6.0),
      ),
      child: Opacity(
        opacity: 0.64,
        child: TextField(
          style: Theme.of(context).textTheme.caption.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: ResponsiveHelper.bodySize(context),
                color: kLoginBlack,
              ),
          controller: myController,
          keyboardType: inputType,
          textInputAction: inputAction,
          decoration: InputDecoration(
            focusColor: Colors.green,
            border: InputBorder.none,
            hintText: hintText,
            hintStyle: Theme.of(context).textTheme.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: ResponsiveHelper.bodySize(context),
                  color: Colors.black45,
                ),
            fillColor: Colors.red,
          ),
          onChanged: (str) {
            onChanged!(str);
          },
          onSubmitted: (str) {
            onSubmited!(str);
          },
        ),
      ),
    );
  }
}
