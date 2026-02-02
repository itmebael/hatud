import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:hatud_tricycle_app/repo/repo_provider.dart';
import 'package:get_it/get_it.dart';

import './bloc.dart';

class ForgotPasswordBloc
    extends Bloc<ForgotPasswordEvent, ForgotPasswordState> {
  final RepoProvider _repo = GetIt.instance.get<RepoProvider>();

  ForgotPasswordBloc() : super(InitialForgotPasswordState()) {
    on<SendOTPEvent>(_onSendOTP);
  }

  Future<void> _onSendOTP(
    SendOTPEvent event,
    Emitter<ForgotPasswordState> emit,
  ) async {
    if (await _repo.networkInfo.isConnected) {
      try {
        emit(GotoOTPSendState(event.mobileNo));
      } on Error {
        emit(ErrorState(errorMsg: "Something went wrong"));
      }
    } else {
      emit(ErrorState(errorMsg: "Connect with working internet..."));
    }
  }
}
