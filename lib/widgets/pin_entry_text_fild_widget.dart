import 'package:flutter/material.dart';
import 'package:hatud_tricycle_app/common/responsive_helper.dart';

class PinEntryTextField extends StatefulWidget {
  final String lastPin;
  final int fields;
  final ValueChanged<String> onSubmit;
  final double fontSize;
  final bool isTextObscure;
  final bool showFieldAsBox;

  const PinEntryTextField({
    Key? key,
    required this.lastPin,
    this.fields = 4,
    required this.onSubmit,
    this.fontSize = 36.0,
    this.isTextObscure = false,
    this.showFieldAsBox = false,
  })  : assert(fields > 0),
        super(key: key);

  @override
  State createState() {
    return PinEntryTextFieldState();
  }
}

class PinEntryTextFieldState extends State<PinEntryTextField> {
  late final List<String?> _pin;
  late final List<FocusNode> _focusNodes;
  late final List<TextEditingController> _textControllers;

  Widget textfields = Container();

  @override
  void initState() {
    super.initState();
    _pin = List<String?>.filled(widget.fields, null);
    _focusNodes =
        List<FocusNode>.generate(widget.fields, (index) => FocusNode());
    _textControllers = List<TextEditingController>.generate(
        widget.fields, (index) => TextEditingController());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        for (var i = 0; i < widget.lastPin.length && i < widget.fields; i++) {
          _pin[i] = widget.lastPin[i];
        }
        textfields = generateTextFields(context);
      });
    });
  }

  @override
  void dispose() {
    _textControllers.forEach((TextEditingController t) => t.dispose());
    super.dispose();
  }

  Widget generateTextFields(BuildContext context) {
    List<Widget> textFields = List.generate(widget.fields, (int i) {
      return buildTextField(i, context);
    });

    FocusScope.of(context).requestFocus(_focusNodes[0]);

    return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        verticalDirection: VerticalDirection.down,
        children: textFields);
  }

  void clearTextFields() {
    _textControllers.forEach(
        (TextEditingController tEditController) => tEditController.clear());
    for (int i = 0; i < _pin.length; i++) {
      _pin[i] = null;
    }
  }

  Widget buildTextField(int i, BuildContext context) {
    _focusNodes[i].addListener(() {
      if (_focusNodes[i].hasFocus) {}
    });

    return Container(
        width: ResponsiveHelper.responsiveWidth(context, mobile: 50, tablet: 60, desktop: 70),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Color(0XFFF1F3F7),
        ),
        margin: EdgeInsets.all(ResponsiveHelper.responsiveWidth(context, mobile: 5, tablet: 8, desktop: 10)),
        child: TextField(
          showCursor: false,
          controller: _textControllers[i],
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 1,
          obscureText: true,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
            fontSize: widget.fontSize,
          ),
          focusNode: _focusNodes[i],
          decoration: InputDecoration(
            border: InputBorder.none,
            counterText: "",
            hintText: "•",
            hintStyle: TextStyle(
              fontSize: widget.fontSize,
            ),
          ),
          onChanged: (String str) {
            setState(() {
              _pin[i] = str;
            });
            if (i + 1 != widget.fields) {
              _focusNodes[i].unfocus();
              if (_pin[i] == null || _pin[i] == '') {
                FocusScope.of(context).requestFocus(_focusNodes[i - 1]);
              } else {
                FocusScope.of(context).requestFocus(_focusNodes[i + 1]);
              }
            } else {
              _focusNodes[i].unfocus();
              if (_pin[i] == null || _pin[i] == '') {
                FocusScope.of(context).requestFocus(_focusNodes[i - 1]);
              }
            }
            if (_pin.every((String? digit) => digit != null && digit != '')) {
              widget.onSubmit(_pin.where((s) => s != null).join());
            }
          },
          onSubmitted: (String str) {
            if (_pin.every((String? digit) => digit != null && digit != '')) {
              widget.onSubmit(_pin.where((s) => s != null).join());
            }
          },
        ));
  }

  @override
  Widget build(BuildContext context) {
    return textfields;
  }
}
