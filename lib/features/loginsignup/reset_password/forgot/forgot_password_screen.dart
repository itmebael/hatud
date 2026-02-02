import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hatud_tricycle_app/common/my_colors.dart';
import 'package:hatud_tricycle_app/common/viiticons_icons.dart';
import 'package:hatud_tricycle_app/features/loginsignup/reset_password/otp/otp_screen.dart';
import 'package:hatud_tricycle_app/widgets/square_textfield_widget.dart';
import 'package:hatud_tricycle_app/widgets/fab_button.dart';
import 'package:hatud_tricycle_app/widgets/wavy_header_widget.dart';
import 'package:hatud_tricycle_app/common/responsive_helper.dart';

import 'bloc/bloc.dart';

class ForgotPasswordScreen extends StatelessWidget {
  static const String routeName = "forgotpassword";

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      child: Forgot(),
      create: (context) => ForgotPasswordBloc(),
    );
  }
}

class Forgot extends StatefulWidget {
  @override
  _ForgotState createState() => _ForgotState();
}

class _ForgotState extends State<Forgot> {
  late ForgotPasswordBloc forgotPasswordBloc;

  @override
  void initState() {
    super.initState();
    forgotPasswordBloc = BlocProvider.of<ForgotPasswordBloc>(context);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    super.dispose();
    forgotPasswordBloc.close();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: BlocListener<ForgotPasswordBloc, ForgotPasswordState>(
          listener: (context, state) {
            if (state is GotoOTPSendState) {
              Navigator.of(context).pushNamed(OTPScreen.routeName);
            }
          },
          child: BlocBuilder<ForgotPasswordBloc, ForgotPasswordState>(
            builder: (context, state) {
              if (state is InitialForgotPasswordState) {
                return _buildInitialState();
              } else if (state is LoadingForgotState) {
                return _buildLoadingState();
              } else if (state is ErrorState) {
                return _buildErrorState(state.errorMsg);
              } else {
                return _buildInitialState();
              }
            },
          ),
        ),
      ),
    );
  }

  _buildInitialState() {
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: ResponsiveHelper.maxContentWidth(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              WavyHeader(
                isBack: true,
                onBackTap: () {
                  Navigator.of(context).pop();
                },
              ),
              SizedBox(
                height: ResponsiveHelper.responsiveHeight(context, mobile: 42, tablet: 56, desktop: 64),
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveHelper.responsiveWidth(context,
                        mobile: 46, tablet: 80, desktop: 120)),
                child: Text(
                  "Forgot Password",
                  style: Theme.of(context).textTheme.headline.copyWith(
                        color: kLoginBlack,
                        fontSize: ResponsiveHelper.headlineSize(context),
                      ),
                ),
              ),
              SizedBox(
                height: ResponsiveHelper.responsiveHeight(context, mobile: 21, tablet: 28, desktop: 32),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: ResponsiveHelper.responsiveWidth(context, mobile: 46, tablet: 80, desktop: 120)),
                child: SquareTextFieldWidget(
                  myController: TextEditingController(),
                  hintText: "Enter mobile number",
                  inputType: TextInputType.phone,
                  onChanged: (str) {},
                  onSubmited: (str) {},
                ),
              ),
              SizedBox(
                height: ResponsiveHelper.responsiveHeight(context, mobile: 12, tablet: 16, desktop: 20),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: ResponsiveHelper.responsiveWidth(context, mobile: 46, tablet: 80, desktop: 120)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    FABButton(
                      bgColor: kAccentColor,
                      icon: Icon(
                        Viiticons.next_arrow,
                        color: Colors.white,
                        size: 18,
                      ),
                      onTap: () {
                        forgotPasswordBloc.add(
                          SendOTPEvent(""),
                        );
                      },
                    )
                  ],
                ),
              ),
              SizedBox(
                height: ResponsiveHelper.responsiveHeight(context, mobile: 64, tablet: 80, desktop: 100),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: ResponsiveHelper.responsiveWidth(context, mobile: 46, tablet: 80, desktop: 120)),
                child: Center(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      "Back to Sign In",
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.subhead.copyWith(
                            color: kAccentColor,
                            fontSize: ResponsiveHelper.bodySize(context),
                          ),
                    ),
                  ),
                ),
              ),
        ],
          ),
        ),
      ),
    );
  }

  _buildLoadingState() {
    return Container();
  }

  _buildErrorState(errorMsg) {
    return Center(
      child: Icon(Icons.sync_problem),
    );
  }
}
