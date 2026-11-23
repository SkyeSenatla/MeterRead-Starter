/// A value the phone kept, and when the server last said so.
final class Snapshot<T> {
  /// Creates the snapshot.
  const new(this.value, {required this.fetchedAt});

  /// What the server sent, as the app means it.
  final T value;

  /// When the server sent it, in UTC.
  final DateTime fetchedAt;
}
