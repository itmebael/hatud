import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:hatud_tricycle_app/repo/repo_provider.dart';
import 'package:get_it/get_it.dart';

import 'bloc.dart';

class OptBloc extends Bloc<OptEvent, OptState> {
  final RepoProvider _repo = GetIt.instance.get<RepoProvider>();

  OptBloc() : super(InitialOptState()) {
    on<VerifyOTPEvent>(_onVerifyOTP);
  }

  Future<void> _onVerifyOTP(
    VerifyOTPEvent event,
    Emitter<OptState> emit,
  ) async {
    if (await _repo.networkInfo.isConnected) {
      try {
        emit(GotoResetPassState());
      } on Error {
        emit(ErrorState(errorMsg: "Something went wrong"));
      }
    } else {
      emit(ErrorState(errorMsg: "Connect with working internet..."));
    }
  }
}
