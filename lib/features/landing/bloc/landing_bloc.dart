import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:hatud_tricycle_app/repo/pref_manager.dart';
import 'package:hatud_tricycle_app/repo/repo_provider.dart';
import 'package:get_it/get_it.dart';

import 'bloc.dart';

class LandingBloc extends Bloc<LandingEvent, LandingState> {
  PrefManager? pref;
  RepoProvider repoProvider = GetIt.instance.get<RepoProvider>();

  LandingBloc() : super(LandingInitialState()) {
    initPref();
    on<LandingIsGuest>(_onLandingIsGuest);
  }

  initPref() async {
    pref = await PrefManager.getInstance();
  }

  Future<void> _onLandingIsGuest(
    LandingIsGuest event,
    Emitter<LandingState> emit,
  ) async {
    emit(LandingLoadingState());

    try {
      if (pref != null && pref!.isLogin) {
        emit(LandingGoToUser());
      } else {
        emit(LandingGoToGuest());
      }
    } on Error {
      emit(ErrorState(errorMsg: "Something went wrong"));
    }
  }
}
