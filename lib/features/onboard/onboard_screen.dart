import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hatud_tricycle_app/common/my_colors.dart';
import 'package:hatud_tricycle_app/features/loginsignup/login/login_screen.dart';
import 'package:hatud_tricycle_app/widgets/onboard_widget.dart';
import 'package:hatud_tricycle_app/l10n/app_localizations.dart';
import 'package:get_it/get_it.dart';

import 'bloc/bloc.dart';

class OnBoardScreen extends StatelessWidget {
  static const String routeName = "onboard";
  final getIt = GetIt.instance;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => OnboardBloc(),
      child: OnBoard(),
    );
  }
}

class OnBoard extends StatefulWidget {
  @override
  _OnBoardState createState() => _OnBoardState();
}

class _OnBoardState extends State<OnBoard> {
  late OnboardBloc onBoardBloc;
  late int currentPageValue;
  var images = ["assets/google.png", "assets/india.png", "assets/facebook.png"];

  @override
  void initState() {
    super.initState();
    onBoardBloc = BlocProvider.of<OnboardBloc>(context);
    onBoardBloc.add(
      NextEvent(),
    );
    if (!kIsWeb && Platform.isAndroid) {
      SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.white,
          statusBarIconBrightness: Brightness.dark, //Android
        ),
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext buildContext) {
    return Scaffold(
      body: SafeArea(
        child: BlocListener<OnboardBloc, OnboardState>(
          listener: (blcontext, state) {
            if (state is GotoLoginOnboardState) {
              Navigator.of(blcontext).pushReplacementNamed(
                LoginScreen.routeName,
              );
            }
          },
          child: BlocBuilder<OnboardBloc, OnboardState>(
            builder: (blocContext, state) {
              if (state is InitialOnboardState) {
                return buildInitialState();
              } else if (state is LoadingOnboardState) {
                return buildLoadingState();
              } else if (state is CurrentOnboardState) {
                return OnboardWidget(
                  onTapImageIndex: state.currentIndex,
                  images: [
                    "assets/onboarding_0.png",
                    "assets/onboarding_1.png",
                    "assets/onboarding_2.png",
                  ],
                  titles: [
                    AppLocalizations.of(context)!.bookRide,
                    AppLocalizations.of(context)!.meetYourDriver,
                    AppLocalizations.of(context)!.trackYourTrip
                  ],
                  subtitles: [
                    AppLocalizations.of(context)!.bookTricycleSubtitle,
                    AppLocalizations.of(context)!.meetDriverSubtitle,
                    AppLocalizations.of(context)!.trackTripSubtitle
                  ],
                  myOnSkipPressed: () {
                    onBoardBloc.add(
                      GoToLoginEvent(),
                    );
                  },
                  myOnNextPressed: () {
                    onBoardBloc.add(
                      NextEvent(),
                    );
                  },
                );
              } else if (state is ErrorState) {
                return _buildErrorState(state.errorMsg);
              } else {
                return _buildErrorState("Something went wrong");
              }
            },
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    if (!kIsWeb && Platform.isAndroid) {
      SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle.light.copyWith(
          statusBarColor: kPrimaryColor,
          statusBarIconBrightness: Brightness.light,
        ),
      );
    }
  }

  Widget buildInitialState() {
    return Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget buildLoadingState() {
    return Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildErrorState(String errorMsg) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            errorMsg,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              onBoardBloc.add(NextEvent());
            },
            child: const Text("Retry"),
          ),
        ],
      ),
    );
  }
}
