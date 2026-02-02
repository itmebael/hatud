import 'package:equatable/equatable.dart';

abstract class OnboardEvent extends Equatable {
  const OnboardEvent();
}

class NextEvent extends OnboardEvent {
  @override
  List<Object> get props => [];
}

class GoToLoginEvent extends OnboardEvent {
  @override
  List<Object> get props => [];
}
