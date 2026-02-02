import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  const Failure();
}

class GeneralMsgError extends Failure {
  final String errorMsg;

  const GeneralMsgError(this.errorMsg);

  @override
  List<Object?> get props => [errorMsg];
}
