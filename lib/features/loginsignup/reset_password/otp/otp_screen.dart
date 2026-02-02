import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hatud_tricycle_app/common/my_colors.dart';
import 'package:hatud_tricycle_app/common/responsive_helper.dart';
import 'package:hatud_tricycle_app/common/viiticons_icons.dart';
import 'package:hatud_tricycle_app/features/loginsignup/reset_password/reset/reset_screen.dart';
import 'package:hatud_tricycle_app/widgets/fab_button.dart';
import 'package:hatud_tricycle_app/widgets/pin_entry_text_fild_widget.dart';
import 'package:hatud_tricycle_app/widgets/wavy_header_widget.dart';

import 'bloc/bloc.dart';

class OTPScreen extends StatelessWidget {
  static const String routeName = "otp";

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      child: OTP(),
      create: (context) => OptBloc(),
    );
  }
}

class OTP extends StatefulWidget {
  @override
  _OTPState createState() => _OTPState();
}

class _OTPState extends State<OTP> {
  late final OptBloc otpBloc;

  @override
  void initState() {
    super.initState();
    otpBloc = BlocProvider.of<OptBloc>(context);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    super.dispose();
    otpBloc.close();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: BlocListener<OptBloc, OptState>(
          listener: (context, state) {
            if (state is GotoResetPassState) {
              Navigator.of(context).pushNamed(ResetPassScreen.routeName);
            }
          },
          child: BlocBuilder<OptBloc, OptState>(
            builder: (context, state) {
              if (state is InitialOptState) {
                return _buildInitialState();
              } else if (state is LoadingOptState) {
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
            padding: EdgeInsets.symmetric(horizontal: ResponsiveHelper.responsiveWidth(context, mobile: 46, tablet: 80, desktop: 120)),
            child: Text(
              "OTP Verification",
              style: Theme.of(context).textTheme.headline.copyWith(
                    color: kLoginBlack,
                    fontSize: ResponsiveHelper.headlineSize(context),
                  ),
            ),
          ),
          SizedBox(
            height: ResponsiveHelper.responsiveHeight(context, mobile: 21, tablet: 28, desktop: 32),
          ),
          PinEntryTextField(
            lastPin: "",
            fields: 4,
            fontSize: ResponsiveHelper.responsiveWidth(context, mobile: 24, tablet: 32, desktop: 36),
            onSubmit: (pin) {
              // Handle OTP submission
            },
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
                    otpBloc.add(
                      VerifyOTPEvent(),
                    );
                  },
                )
              ],
            ),
          ),
          SizedBox(
            height: ResponsiveHelper.responsiveHeight(context, mobile: 12, tablet: 16, desktop: 20),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: ResponsiveHelper.responsiveWidth(context, mobile: 46, tablet: 80, desktop: 120)),
            child: Center(
              child: GestureDetector(
                onTap: () {
                  Navigator.of(context).pop();
                },
                child: Text(
                  "I didn’t receive a code!",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.subhead.copyWith(
                        color: kTextLoginfaceid,
                        fontSize: ResponsiveHelper.bodySize(context),
                      ),
                ),
              ),
            ),
          ),
          SizedBox(
            height: ResponsiveHelper.responsiveHeight(context, mobile: 12, tablet: 16, desktop: 20),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: ResponsiveHelper.responsiveWidth(context, mobile: 46, tablet: 80, desktop: 120)),
            child: Center(
              child: GestureDetector(
                onTap: () {
                  Navigator.of(context).pop();
                },
                child: Text(
                  "Resend",
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
