import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hatud_tricycle_app/common/my_colors.dart';
import 'package:hatud_tricycle_app/common/responsive_helper.dart';
import 'package:hatud_tricycle_app/features/language/bloc/language_bloc.dart';
import 'package:hatud_tricycle_app/features/language/bloc/language_event.dart';
import 'package:hatud_tricycle_app/features/language/bloc/language_state.dart';
import 'package:hatud_tricycle_app/features/onboard/onboard_screen.dart';
import 'package:hatud_tricycle_app/widgets/language_button.dart';
import 'package:hatud_tricycle_app/l10n/app_localizations.dart';

class LanguageScreen extends StatelessWidget {
  static const String routeName = "/language";

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => LanguageBloc(),
      child: Language(),
    );
  }
}

class Language extends StatefulWidget {
  @override
  _LanguageState createState() => _LanguageState();
}

class _LanguageState extends State<Language> {
  late LanguageBloc languageBloc;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (mounted) {
      languageBloc = BlocProvider.of<LanguageBloc>(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: kPrimaryColor,
        body: BlocListener<LanguageBloc, LanguageState>(
          listener: (context, languageState) {
            if (languageState is GoToOnBoardState) {
              Navigator.of(context).pushReplacementNamed(
                OnBoardScreen.routeName,
              );
            }
          },
          child: BlocBuilder<LanguageBloc, LanguageState>(
            builder: (context, languageState) {
              if (languageState is InitialLanguageState) {
                return _buildInitialState();
              } else {
                return Center(
                  child: CircularProgressIndicator(),
                );
              }
            },
          ),
        ),
      ),
    );
  }

  _buildInitialState() {
    return Stack(
      children: <Widget>[
        Align(
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                height: ResponsiveHelper.responsiveHeight(context, mobile: 145, tablet: 180, desktop: 200),
              ),
              Builder(builder: (context) {
                final headlineStyle = Theme.of(context).textTheme.headline;
                final baseFontSize = headlineStyle.fontSize ?? 28;
                final adjustedFontSize =
                    (baseFontSize - 1).clamp(0, double.infinity).toDouble();
                return Text(
                  AppLocalizations.of(context)!.selectLanguage,
                  style: headlineStyle.copyWith(
                    fontSize: ResponsiveHelper.headlineSize(context),
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                );
              }),
              SizedBox(
                height: ResponsiveHelper.responsiveHeight(context, mobile: 32, tablet: 40, desktop: 48),
              ),
              LanguageButton(
                btnTxt: AppLocalizations.of(context)!.english,
                isShowIcon: true,
                btnOnTap: () {
                  // Update locale to English
                  languageBloc.add(
                    SelectLanEvent("en", "English"),
                  );
                },
              ),
              SizedBox(
                height: 16,
              ),
              LanguageButton(
                btnTxt: AppLocalizations.of(context)!.tagalog,
                isShowIcon: true,
                btnOnTap: () {
                  // Update locale to Tagalog
                  languageBloc.add(SelectLanEvent("tl", "Tagalog"));
                },
              ),
              SizedBox(
                height: 16,
              ),
              LanguageButton(
                btnTxt: AppLocalizations.of(context)!.waray,
                isShowIcon: true,
                btnOnTap: () {
                  // Update locale to Waray-Waray
                  languageBloc.add(SelectLanEvent("war", "Waray-Waray"));
                },
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Image.asset(
            "assets/cloud_shape_bg.png",
            width: MediaQuery.of(context).size.width,
          ),
        ),
      ],
    );
  }
}
