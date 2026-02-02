import 'dart:async';

import 'package:bloc/bloc.dart';
import './bloc.dart';

class OnboardBloc extends Bloc<OnboardEvent, OnboardState> {
  int currentIndex = -1;
  int maxOnBoard = 2;

  OnboardBloc() : super(InitialOnboardState()) {
    on<NextEvent>(_onNext);
    on<GoToLoginEvent>(_onGoToLogin);
  }

  Future<void> _onNext(
    NextEvent event,
    Emitter<OnboardState> emit,
  ) async {
    // Onboarding should not depend on network; advance locally.
    try {
      if (currentIndex >= maxOnBoard) {
        emit(GotoLoginOnboardState());
      } else {
        ++currentIndex;
        emit(CurrentOnboardState(currentIndex: currentIndex));
      }
    } catch (_) {
      emit(ErrorState(errorMsg: "Something went wrong"));
    }
  }

  Future<void> _onGoToLogin(
    GoToLoginEvent event,
    Emitter<OnboardState> emit,
  ) async {
    emit(GotoLoginOnboardState());
  }
}
