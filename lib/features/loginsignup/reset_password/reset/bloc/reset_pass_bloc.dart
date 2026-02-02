
import 'package:bloc/bloc.dart';

import './bloc.dart';

class ResetPassBloc extends Bloc<ResetPassEvent, ResetPassState> {
  ResetPassBloc() : super(InitialResetPassState()) {
    on<ResetPasswordPressed>((event, emit) async {
      emit(LoadingResetPassState());
      try {
        // TODO: Implement password reset logic
        await Future.delayed(Duration(seconds: 2)); // Simulate network request
        emit(SuccessResetPassState());
      } catch (e) {
        emit(ErrorState(errorMsg: e.toString()));
      }
    });
  }
}
