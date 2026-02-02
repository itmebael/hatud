import 'dart:async';
import 'dart:math';

import 'package:bloc/bloc.dart';
import 'package:hatud_tricycle_app/repo/repo_provider.dart';
import 'package:get_it/get_it.dart';

import 'bloc.dart';

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  final RepoProvider _repo = GetIt.instance.get<RepoProvider>();

  LoginBloc() : super(InitialLoginState()) {
    on<SubmitLoginEvent>(_onSubmitLogin);
    on<LoginWithFaceidEvent>(_onLoginWithFaceid);
    on<ForgotPassEvent>(_onForgotPass);
  }

  Future<void> _onSubmitLogin(
    SubmitLoginEvent event,
    Emitter<LoginState> emit,
  ) async {
    if (await _repo.networkInfo.isConnected) {
      emit(GotoHomeState());
    } else {
      emit(ErrorLoginState(errorMsg: "Connect with working internet..."));
    }
  }

  Future<void> _onLoginWithFaceid(
    LoginWithFaceidEvent event,
    Emitter<LoginState> emit,
  ) async {
    if (await _repo.networkInfo.isConnected) {
      try {
        var random = Random();
        if (random.nextBool()) {
          emit(GotoFaceIDLoginState());
        } else {
          emit(FacenotRecognizedLoginState());
        }
      } on Error {
        emit(ErrorLoginState(errorMsg: "Something went wrong"));
      }
    } else {
      emit(ErrorLoginState(errorMsg: "Connect with working internet..."));
    }
  }

  Future<void> _onForgotPass(
    ForgotPassEvent event,
    Emitter<LoginState> emit,
  ) async {
    if (await _repo.networkInfo.isConnected) {
      try {
        emit(GotoForgotPassState());
      } on Error {
        emit(ErrorLoginState(errorMsg: "Something went wrong"));
      }
    } else {
      emit(ErrorLoginState(errorMsg: "Connect with working internet..."));
    }
  }
}
