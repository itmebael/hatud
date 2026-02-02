import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hatud_tricycle_app/common/my_colors.dart';
import 'package:hatud_tricycle_app/common/responsive_helper.dart';

class PasswordFormField extends StatefulWidget {
  final TextEditingController myController;
  final FocusNode myFocusNode;
  final String hintText;
  final TextInputAction inputAction;
  final EdgeInsetsGeometry myMargin;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmited;

  const PasswordFormField({
    Key? key,
    required this.myController,
    required this.myFocusNode,
    this.myMargin = const EdgeInsets.all(0),
    required this.hintText,
    this.inputAction = TextInputAction.done,
    required this.onChanged,
    required this.onSubmited,
  });

  @override
  _PasswordFormFieldState createState() => _PasswordFormFieldState();
}

class _PasswordFormFieldState extends State<PasswordFormField> {
  bool _showPassword = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(
        left: 8,
        right: 8,
        bottom: 2,
      ),
      margin: widget.myMargin,
      height: ResponsiveHelper.responsiveHeight(context, mobile: 48, tablet: 56, desktop: 64),
      decoration: BoxDecoration(
        color: kShareCodeBg,
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
          controller: widget.myController,
          focusNode: widget.myFocusNode,
          obscureText: _showPassword,
          keyboardType: TextInputType.text,
          textInputAction: widget.inputAction,
          decoration: InputDecoration(
            focusColor: Colors.green,
            border: InputBorder.none,
            hintText: widget.hintText,
            hintStyle: Theme.of(context).textTheme.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: ResponsiveHelper.bodySize(context),
                  color: Colors.black45,
                ),
            fillColor: Colors.red,
            suffixIcon: GestureDetector(
              onTap: () {
                setState(() {
                  _showPassword = !_showPassword;
                });
              },
              child: Icon(
                _showPassword ? CupertinoIcons.eye : CupertinoIcons.eye_solid,
                size: ResponsiveHelper.responsiveWidth(context, mobile: 30, tablet: 35, desktop: 40),
              ),
            ),
          ),
          onChanged: (str) {
            widget.onChanged(str);
          },
          onSubmitted: (str) {
            widget.onSubmited(str);
          },
        ),
      ),
    );
  }
}
