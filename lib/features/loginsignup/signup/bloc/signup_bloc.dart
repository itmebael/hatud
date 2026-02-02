import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:hatud_tricycle_app/repo/repo_provider.dart';
import 'package:get_it/get_it.dart';

import './bloc.dart';

class SignupBloc extends Bloc<SignupEvent, SignupState> {
  final RepoProvider _repo = GetIt.instance.get<RepoProvider>();

  SignupBloc() : super(InitialSignupState()) {
    on<SubmitSignupEvent>(_onSubmitSignup);
  }

  Future<void> _onSubmitSignup(
    SubmitSignupEvent event,
    Emitter<SignupState> emit,
  ) async {
    emit(LoadingSignupState());

    if (await _repo.networkInfo.isConnected) {
      try {
        emit(SignupSuccessState());
      } on Error {
        emit(ErrorState(errorMsg: "Something went wrong"));
      }
    } else {
      emit(ErrorState(errorMsg: "Connect with working internet..."));
    }
  }
}
