import 'dart:ui';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hatud_tricycle_app/common/my_colors.dart';
import 'package:hatud_tricycle_app/common/viiticons_icons.dart';
import 'package:hatud_tricycle_app/widgets/square_textfield_widget.dart';
import 'package:hatud_tricycle_app/widgets/date_picker_widget.dart';
import 'package:hatud_tricycle_app/widgets/password_textfield.dart';
import 'package:hatud_tricycle_app/widgets/role_selection_widget.dart';
import 'package:hatud_tricycle_app/common/responsive_helper.dart';

import 'bloc/bloc.dart';

class SignupScreen extends StatelessWidget {
  static const String routeName = "signup";

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      child: Signup(),
      create: (context) => SignupBloc(),
    );
  }
}

class Signup extends StatefulWidget {
  @override
  _SignupState createState() => _SignupState();
}

class _SignupState extends State<Signup> {
  var _isCheckedTerms = false;
  var selectGender;
  late DateTime selectedDate;
  String? selectedRole;

  @override
  void initState() {
    super.initState();
    selectedDate = DateTime.now(); // Initialize selectedDate
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              kPrimaryColor.withValues(alpha: 0.9),
              kAccentColor.withValues(alpha: 0.9),
              Colors.purple.withValues(alpha: 0.9),
            ],
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back,
                color: Colors.white,
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            title: Text(
              "Sign Up",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    offset: Offset(0, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
            ),
          ),
          body: BlocBuilder<SignupBloc, SignupState>(
            builder: (context, state) {
              if (state is InitialSignupState) {
                return buildInitialState();
              } else if (state is LoadingSignupState) {
                return buildLoadingState();
              } else if (state is ErrorState) {
                return buildErrorState(state.errorMsg);
              } else {
                return Center(
                  child: Text("Unhandled state"),
                );
              }
            },
          ),
        ),
      ),
    );
  }

  Future<Null> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2015, 8),
        lastDate: DateTime(2101));
    if (picked != null && picked != selectedDate)
      setState(() {
        selectedDate = picked;
      });
  }

  buildInitialState() {
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: ResponsiveHelper.maxContentWidth(context),
          ),
          child: Column(
            children: <Widget>[
              SizedBox(height: 20),
              // Glassmorphism container for signup form
              Container(
                margin: ResponsiveHelper.responsiveHorizontalPadding(context)
                    .copyWith(bottom: 20),
                padding: ResponsiveHelper.responsivePadding(context),
                decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Column(
                    children: <Widget>[
                      SizedBox(height: 10),
                      Stack(
                        children: <Widget>[
                          Container(
                            height: 128,
                            width: 135,
                          ),
                          DottedBorder(
                            color: Colors.white.withValues(alpha: 0.5),
                            borderType: BorderType.RRect,
                            radius: Radius.circular(120 / 2),
                            padding: EdgeInsets.all(6),
                            dashPattern: [8, 8],
                            strokeWidth: 2,
                            child: Container(
                              height: 100,
                              width: 100,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(100 / 2),
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                              child: Center(
                                child: Icon(
                                  Viiticons.profile_pic,
                                  color: Colors.white,
                                  size: 48,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 10,
                            top: 15,
                            child: Container(
                              height: 40,
                              width: 40,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(40 / 2),
                                color: Colors.white.withValues(alpha: 1.0),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 1.0),
                                  width: 1,
                                ),
                              ),
                              child: Center(
                                child: Icon(
                                  Viiticons.plus,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                            ),
                          )
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Upload your photo",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 16,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              offset: Offset(0, 1),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 15,
                      ),
                      SquareTextFieldWidget(
                        hintText: "First Name",
                        inputAction: TextInputAction.next,
                        inputType: TextInputType.text,
                      ),
                      SizedBox(
                        height: 15,
                      ),
                      SquareTextFieldWidget(
                        hintText: "Last Name",
                        inputAction: TextInputAction.next,
                        inputType: TextInputType.text,
                      ),
                      SizedBox(
                        height: 15,
                      ),
                      SquareTextFieldWidget(
                        hintText: "Nick Name",
                        inputAction: TextInputAction.next,
                        inputType: TextInputType.text,
                      ),
                      SizedBox(
                        height: 15,
                      ),
                      RoleSelectionWidget(
                        selectedRole: selectedRole,
                        onRoleChanged: (role) {
                          setState(() {
                            selectedRole = role;
                          });
                        },
                      ),
                      SizedBox(
                        height: 15,
                      ),
                      SquareTextFieldWidget(
                        myController: TextEditingController(),
                        inputType: TextInputType.phone,
                        inputAction: TextInputAction.next,
                        hintText: "Enter mobile number",
                        onChanged: (str) {},
                        onSubmited: (str) {},
                      ),
                      SizedBox(
                        height: 15,
                      ),
                      SquareTextFieldWidget(
                        hintText: "Email Address",
                        inputType: TextInputType.emailAddress,
                        inputAction: TextInputAction.next,
                      ),
                      SizedBox(
                        height: 15,
                      ),
                      DatePickerContainer(
                        selectDate: () => _selectDate(context),
                        date: "Date of Birth",
                        icon: Viiticons.calendar,
                      ),
                      SizedBox(
                        height: 15,
                      ),
                      PasswordFormField(
                        myController: TextEditingController(),
                        myFocusNode: FocusNode(),
                        hintText: "Password",
                        onChanged: (value) {},
                        onSubmited: (value) {},
                      ),
                      SizedBox(
                        height: 15,
                      ),
                      PasswordFormField(
                        myController: TextEditingController(),
                        myFocusNode: FocusNode(),
                        hintText: "Confirm password",
                        onChanged: (value) {},
                        onSubmited: (value) {},
                      ),
                      SizedBox(
                        height: 15,
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Opacity(
                            opacity: 0.64,
                            child: Text(
                              "Are You Interested in Child Ride ?",
                              style:
                                  Theme.of(context).textTheme.caption.copyWith(
                                        color: kLoginBlack,
                                        fontSize: 17,
                                      ),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: <Widget>[
                          Radio(
                            value: 1,
                            activeColor: kPrimaryColor,
                            groupValue: selectGender,
                            onChanged: (val) {
                              setState(() {
                                selectGender = val;
                              });
                            },
                          ),
                          Text(
                            "Yes",
                            style: Theme.of(context).textTheme.caption.copyWith(
                                  color: kTextLoginfaceid,
                                  fontSize: 17,
                                ),
                          ),
                          Radio(
                            value: 2,
                            activeColor: kPrimaryColor,
                            groupValue: selectGender,
                            onChanged: (val) {
                              setState(() {
                                selectGender = val;
                              });
                            },
                          ),
                          Text(
                            "No",
                            style: Theme.of(context).textTheme.caption.copyWith(
                                  color: Colors.grey,
                                  fontSize: 17,
                                ),
                          ),
                        ],
                      ),
                      SizedBox(
                        height: 6,
                      ),
                      Row(
                        children: <Widget>[
                          Checkbox(
                            value: _isCheckedTerms,
                            activeColor: Colors.grey,
                            onChanged: (bool? value) {
                              setState(() {
                                _isCheckedTerms = value ?? false;
                              });
                            },
                            checkColor: Color(0xFFFFFFFF),
                            tristate: false,
                          ),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  fontSize: 16.0,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                  height: 1.2,
                                ),
                                children: <TextSpan>[
                                  TextSpan(
                                    text: 'I agree with ',
                                    style: Theme.of(context)
                                        .textTheme
                                        .caption
                                        .copyWith(
                                          fontSize: 16,
                                        ),
                                  ),
                                  TextSpan(
                                    text: 'Terms of Condition ',
                                    style: Theme.of(context)
                                        .textTheme
                                        .caption
                                        .copyWith(
                                          fontSize: 16,
                                          color: kPrimaryColor,
                                        ),
                                  ),
                                  TextSpan(
                                      text: 'as well as ',
                                      style: Theme.of(context)
                                          .textTheme
                                          .caption
                                          .copyWith(
                                            fontSize: 16,
                                          )),
                                  TextSpan(
                                    text: 'Privacy Policy.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .caption
                                        .copyWith(
                                          fontSize: 16,
                                          color: kPrimaryColor,
                                        ),
                                  )
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                        height: 15,
                      ),
                      Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.2),
                              Colors.white.withValues(alpha: 0.1),
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 10,
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            "Sign Up",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  offset: Offset(0, 1),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 40),
        ],
          ),
        ),
      ),
    );
  }

  buildLoadingState() {
    return Container();
  }

  buildErrorState(errorMsg) {
    return Center(
      child: Icon(Icons.sync_problem),
    );
  }
}

