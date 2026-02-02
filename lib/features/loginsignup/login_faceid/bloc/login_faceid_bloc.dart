import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:hatud_tricycle_app/repo/repo_provider.dart';
import 'package:get_it/get_it.dart';

import './bloc.dart';

class LoginFaceidBloc extends Bloc<LoginFaceidEvent, LoginFaceidState> {
  final RepoProvider _repo = GetIt.instance.get<RepoProvider>();

  LoginFaceidBloc() : super(InitialLoginFaceidState()) {
    on<UserFaceidEvent>(_onUserFaceid);
  }

  Future<void> _onUserFaceid(
    UserFaceidEvent event,
    Emitter<LoginFaceidState> emit,
  ) async {
    if (await _repo.networkInfo.isConnected) {
      try {
        emit(LoadingInfoLoginFaceidState());

        await Future.delayed(
          const Duration(seconds: 3),
        );

        emit(AllowFaceidLoginFaceidState());
      } on Error {
        emit(ErrorState(errorMsg: "Something went wrong"));
      }
    } else {
      emit(ErrorState(errorMsg: "Connect with working internet..."));
    }
  }
}
