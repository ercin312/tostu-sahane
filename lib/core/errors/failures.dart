import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  const Failure(this.messageKey);

  final String messageKey;

  @override
  List<Object?> get props => [messageKey];
}

class ServerFailure extends Failure {
  const ServerFailure() : super('common_error');
}

class CacheFailure extends Failure {
  const CacheFailure() : super('common_error');
}

class NetworkFailure extends Failure {
  const NetworkFailure() : super('common_error');
}
