import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hatud_tricycle_app/common/my_colors.dart';
import 'package:hatud_tricycle_app/common/responsive_helper.dart';
import 'package:hatud_tricycle_app/common/viiticons_icons.dart';
import 'package:hatud_tricycle_app/widgets/fab_button.dart';
import 'package:hatud_tricycle_app/widgets/password_textfield.dart';
import 'package:hatud_tricycle_app/widgets/wavy_header_widget.dart';

import 'bloc/bloc.dart';

class ResetPassScreen extends StatelessWidget {
  static const String routeName = "resetpass";

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      child: ResetPass(),
      create: (context) => ResetPassBloc(),
    );
  }
}

class ResetPass extends StatefulWidget {
  @override
  _ResetPassState createState() => _ResetPassState();
}

class _ResetPassState extends State<ResetPass> {
  late ResetPassBloc reserPassBloc;

  @override
  void initState() {
    super.initState();
    reserPassBloc = BlocProvider.of<ResetPassBloc>(context);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    super.dispose();
    reserPassBloc.close();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: BlocListener<ResetPassBloc, ResetPassState>(
          listener: (context, state) {},
          child: BlocBuilder<ResetPassBloc, ResetPassState>(
            builder: (context, state) {
              if (state is InitialResetPassState) {
                return _buildInitialState();
              } else if (state is LoadingResetPassState) {
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

  _buildLoadingState() {
    return Container();
  }

  _buildErrorState(errorMsg) {
    return Center(
      child: Icon(Icons.sync_problem),
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
              "Reset Password",
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
            child: PasswordFormField(
              myController: TextEditingController(),
              myFocusNode: FocusNode(),
              hintText: "Enter New Password",
              onChanged: (value) {},
              onSubmited: (value) {},
            ),
          ),
          SizedBox(
            height: ResponsiveHelper.responsiveHeight(context, mobile: 21, tablet: 28, desktop: 32),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: ResponsiveHelper.responsiveWidth(context, mobile: 46, tablet: 80, desktop: 120)),
            child: PasswordFormField(
              myController: TextEditingController(),
              myFocusNode: FocusNode(),
              hintText: "Confirm Password",
              onChanged: (value) {},
              onSubmited: (value) {},
            ),
          ),
          SizedBox(
            height: ResponsiveHelper.responsiveHeight(context, mobile: 16, tablet: 20, desktop: 24),
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
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
