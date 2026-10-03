import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  const Failure(this.message);

  @override
  List<Object> get props => [message];
}

class CacheFailure extends Failure {
  const CacheFailure(String message) : super(message);
}

class AuthFailure extends Failure {
  const AuthFailure(String message) : super(message);
}

/// Lo que se buscó no existe (distinto de un error al leer los datos).
class NotFoundFailure extends Failure {
  const NotFoundFailure(String message) : super(message);
}
