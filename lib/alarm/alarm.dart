/// What must be done to stop a ringing alarm.
enum ChallengeType {
  none('None', 'Tap to dismiss'),
  math('Math', 'Solve math problems'),
  shake('Shake', 'Shake the phone'),
  qr('Scan', 'Scan your registered code'),
  sentence('Retype', 'Retype a sentence');

  const ChallengeType(this.label, this.description);

  final String label;
  final String description;

  static ChallengeType parse(Object? name) =>
      ChallengeType.values.firstWhere((c) => c.name == name, orElse: () => ChallengeType.math);
}

enum Difficulty {
  easy('Easy'),
  medium('Medium'),
  hard('Hard');

  const Difficulty(this.label);

  final String label;

  static Difficulty parse(Object? name) =>
      Difficulty.values.firstWhere((d) => d.name == name, orElse: () => Difficulty.medium);
}

const weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// One alarm. The JSON is shared with Kotlin (`Alarm.fromJson` in AlarmStore.kt reads id, hour, minute, days,
/// label, sound, vibrate, gradual, enabled and maxSnoozes); the rest is for the ring screen.
class Alarm {
  const Alarm({
    required this.id,
    required this.hour,
    required this.minute,
    this.days = const {},
    this.label = '',
    this.sound,
    this.soundTitle,
    this.vibrate = true,
    this.gradual = true,
    this.enabled = true,
    this.maxSnoozes = 2,
    this.challenge = ChallengeType.math,
    this.difficulty = Difficulty.medium,
    this.count = 3,
    this.qrCode,
  });

  factory Alarm.create({DateTime? now}) {
    final t = now ?? DateTime.now();
    return Alarm(id: t.millisecondsSinceEpoch, hour: 7, minute: 0);
  }

  factory Alarm.fromJson(Map<String, Object?> json) => Alarm(
    id: (json['id'] as num).toInt(),
    hour: (json['hour'] as num?)?.toInt() ?? 7,
    minute: (json['minute'] as num?)?.toInt() ?? 0,
    days: {for (final d in (json['days'] as List<Object?>? ?? const [])) (d as num).toInt()},
    label: json['label'] as String? ?? '',
    sound: (json['sound'] as String?)?.isEmpty ?? true ? null : json['sound'] as String,
    soundTitle: json['soundTitle'] as String?,
    vibrate: json['vibrate'] as bool? ?? true,
    gradual: json['gradual'] as bool? ?? true,
    enabled: json['enabled'] as bool? ?? true,
    maxSnoozes: (json['maxSnoozes'] as num?)?.toInt() ?? 2,
    challenge: ChallengeType.parse(json['challenge']),
    difficulty: Difficulty.parse(json['difficulty']),
    count: (json['count'] as num?)?.toInt() ?? 3,
    qrCode: (json['qrCode'] as String?)?.isEmpty ?? true ? null : json['qrCode'] as String,
  );

  final int id;
  final int hour;
  final int minute;

  /// ISO weekdays, Monday = 1 ... Sunday = 7. Empty: rings once.
  final Set<int> days;
  final String label;

  /// Ringtone URI, or null for the system default alarm sound.
  final String? sound;
  final String? soundTitle;
  final bool vibrate;
  final bool gradual;
  final bool enabled;

  /// How many times the alarm may be snoozed (5 minutes each). 0: never.
  final int maxSnoozes;
  final ChallengeType challenge;
  final Difficulty difficulty;

  /// Math problems, or shakes (x10), depending on [challenge].
  final int count;

  /// The registered barcode text for [ChallengeType.qr].
  final String? qrCode;

  /// The challenge that will really be asked: a scan alarm without a registered code falls back to math.
  ChallengeType get effectiveChallenge =>
      challenge == ChallengeType.qr && qrCode == null ? ChallengeType.math : challenge;

  Alarm copyWith({
    int? hour,
    int? minute,
    Set<int>? days,
    String? label,
    Object? sound = _keep,
    Object? soundTitle = _keep,
    bool? vibrate,
    bool? gradual,
    bool? enabled,
    int? maxSnoozes,
    ChallengeType? challenge,
    Difficulty? difficulty,
    int? count,
    Object? qrCode = _keep,
  }) => Alarm(
    id: id,
    hour: hour ?? this.hour,
    minute: minute ?? this.minute,
    days: days ?? this.days,
    label: label ?? this.label,
    sound: identical(sound, _keep) ? this.sound : sound as String?,
    soundTitle: identical(soundTitle, _keep) ? this.soundTitle : soundTitle as String?,
    vibrate: vibrate ?? this.vibrate,
    gradual: gradual ?? this.gradual,
    enabled: enabled ?? this.enabled,
    maxSnoozes: maxSnoozes ?? this.maxSnoozes,
    challenge: challenge ?? this.challenge,
    difficulty: difficulty ?? this.difficulty,
    count: count ?? this.count,
    qrCode: identical(qrCode, _keep) ? this.qrCode : qrCode as String?,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'hour': hour,
    'minute': minute,
    'days': (days.toList()..sort()),
    'label': label,
    'sound': sound,
    'soundTitle': soundTitle,
    'vibrate': vibrate,
    'gradual': gradual,
    'enabled': enabled,
    'maxSnoozes': maxSnoozes,
    'challenge': challenge.name,
    'difficulty': difficulty.name,
    'count': count,
    'qrCode': qrCode,
  };

  static const _keep = Object();

  /// "Weekdays", "Every day", "Mon, Wed" or "Once".
  String get repeatLabel {
    if (days.isEmpty) return 'Once';
    if (days.length == 7) return 'Every day';
    if (days.length == 5 && !days.contains(6) && !days.contains(7)) return 'Weekdays';
    if (days.length == 2 && days.containsAll({6, 7})) return 'Weekends';
    return [for (final d in (days.toList()..sort())) weekdayShort[d - 1]].join(', ');
  }
}
