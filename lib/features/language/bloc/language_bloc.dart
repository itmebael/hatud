import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import 'package:hatud_tricycle_app/repo/pref_manager.dart';
import 'package:hatud_tricycle_app/application.dart';

import './bloc.dart';

class LanguageBloc extends Bloc<LanguageEvent, LanguageState> {
  PrefManager? _pref;

  LanguageBloc() : super(InitialLanguageState()) {
    initPref();
    on<SelectLanEvent>(_onSelectLan);
  }

  initPref() async {
    _pref = await PrefManager.getInstance();
  }

  Future<void> _ensurePrefInitialized() async {
    if (_pref == null) {
      _pref = await PrefManager.getInstance();
    }
  }

  Future<void> _onSelectLan(
    SelectLanEvent event,
    Emitter<LanguageState> emit,
  ) async {
    emit(LoadingLanState());

    try {
      await _ensurePrefInitialized();

      if (_pref != null) {
        _pref!.defaultLan = event.lan;
        _pref!.defaultLanCode = event.lanCode;

        // Trigger locale change callback immediately
        if (application.onLocaleChanged != null) {
          final newLocale = Locale(event.lanCode, '');
          print('Language changed to: ${event.lanCode} (${event.lan})');
          application.onLocaleChanged!(newLocale);
        }
      }
      
      // Add a small delay to ensure locale is updated before navigation
      await Future.delayed(Duration(milliseconds: 100));
      emit(GoToOnBoardState());
    } catch (e) {
      emit(ErrorState(errorMsg: "Something went wrong"));
    }
  }
}
