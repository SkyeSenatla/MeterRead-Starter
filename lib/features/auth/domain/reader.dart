import 'package:meterread/core/failure/failure.dart';

final class Reader {
  const new({required this.name, required this.email});
  final String name;
  final String email;
}

sealed class AuthState {
  const new();
}

final class Restoring extends AuthState {
  const new();
}

final class SignedOut extends AuthState {
  const new();
}

final class SignedIn extends AuthState {
  const new(this.reader);
  final Reader reader;
}

final class RestoreFailed extends AuthState {
  const new(this.failure);
  final Failure failure;
}
