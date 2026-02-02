import 'package:equatable/equatable.dart';

abstract class ResetPassEvent extends Equatable {
  const ResetPassEvent();

  @override
  List<Object> get props => [];
}

class ResetPasswordPressed extends ResetPassEvent {
  final String email;

  const ResetPasswordPressed({required this.email});

  @override
  List<Object> get props => [email];
}
