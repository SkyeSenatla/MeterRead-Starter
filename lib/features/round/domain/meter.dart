/// Where a meter is in this month's reading cycle, as the server says.
enum MeterStatus {
  /// Not read yet this cycle.
  due('Due'),

  /// Read once this cycle.
  read('Read'),

  /// Read more than once this cycle: the billing office will query it.
  query('Query'),

  /// A status this app doesn't know yet.
  unknown('');

  new(this.wireName);

  /// The server's exact word for it.
  final String wireName;

  /// The status the server sent, or [unknown].
  static MeterStatus fromWire(Object? value) => values.firstWhere(
    (status) => status != unknown && status.wireName == value,
    orElse: () => unknown,
  );
}

/// One meter on the round, as the round list shows it.
final class MeterSummary {
  /// Creates the summary.
  const new({
    required this.id,
    required this.address,
    required this.meterNumber,
    required this.status,
  });

  /// From the round's wire form.
  factory fromJson(Map<String, Object?> json) => MeterSummary(
    id: json['id']! as String,
    address: json['address']! as String,
    meterNumber: json['meterNumber']! as String,
    status: MeterStatus.fromWire(json['status']),
  );

  /// `M-1001`.
  final String id;

  /// `2 Lwandle Street`.
  final String address;

  /// The number printed on the meter: `KW-58210431`.
  final String meterNumber;

  /// Due, read or queried.
  final MeterStatus status;
}

/// Today's round: the meters one reader visits.
final class Round {
  /// Creates the round.
  const new({
    required this.name,
    required this.totalMeters,
    required this.metersLeft,
    required this.meters,
  });

  /// `Round 7 · Kwanele Ext 4`.
  final String name;

  /// How many meters are on the round, as the server counts them.
  final int totalMeters;

  /// How many are still due, as the server counts them.
  final int metersLeft;

  /// The meters, in the order the reader walks them.
  final List<MeterSummary> meters;
}

/// A reading the server accepted.
final class AcceptedReading {
  /// Creates the reading.
  const new({
    required this.value,
    required this.consumption,
    required this.flagged,
  });

  /// From the wire form.
  factory fromJson(Map<String, Object?> json) => AcceptedReading(
    value: json['value']! as int,
    consumption: json['consumption']! as int,
    flagged: json['flagged']! as bool,
  );

  /// The reading, in whole kWh.
  final int value;

  /// kWh used since the last reading, as the server works it out.
  final int consumption;

  /// The server thinks it's unusually high, and the office will check it.
  final bool flagged;
}

/// An earlier month's reading.
typedef PastReading = ({int value, DateTime readOn});

/// One meter, with everything its screen shows.
final class Meter {
  /// Creates the meter.
  const new({
    required this.id,
    required this.address,
    required this.meterNumber,
    required this.accountNumber,
    required this.status,
    required this.lastReading,
    required this.lastReadOn,
    required this.thisCycle,
    required this.history,
  });

  /// `M-1001`.
  final String id;

  /// `2 Lwandle Street`.
  final String address;

  /// The number printed on the meter.
  final String meterNumber;

  /// The municipal account it bills.
  final String accountNumber;

  /// Due, read or queried.
  final MeterStatus status;

  /// Last month's reading, in whole kWh.
  final int lastReading;

  /// The day it was read: a calendar day, not an instant.
  final DateTime lastReadOn;

  /// This cycle's reading, once the server has one.
  final AcceptedReading? thisCycle;

  /// The last three months, newest first.
  final List<PastReading> history;
}

/// A reading on the phone that the server hasn't accepted yet.
typedef WaitingReading = ({
  String meterId,
  int value,
  bool meterReplaced,
  String? idempotencyKey,
  String? lastError,
});
