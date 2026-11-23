sealed class Failure implements Exception {
  const Failure({this.reference});
  final String? reference;
}

final class NoSignalFailure extends Failure {
  const NoSignalFailure();
}

final class ValidationFailure extends Failure {
  const ValidationFailure(this.errors, {super.reference});
  final Map<String, List<String>> errors;
}

final class SignedOutFailure extends Failure {
  const SignedOutFailure({super.reference});
}

final class NotFoundFailure extends Failure {
  const NotFoundFailure({super.reference});
}

final class ServerFailure extends Failure {
  const ServerFailure({super.reference});
}

final class UnexpectedFailure extends Failure {
  const UnexpectedFailure({super.reference});
}
