sealed class Failure implements Exception {
  const Failure();
}

final class NoSignal extends Failure {
  const NoSignal();
}

final class FieldErrors extends Failure {
  const FieldErrors(this.errors);
  final Map<String, List<String>> errors;
  String? first(String field) {
    final list = errors[field];
    return (list == null || list.isEmpty) ? null : list.first;
  }
}

final class SignedOut extends Failure {
  const SignedOut();
}

final class NotFound extends Failure {
  const NotFound();
}
