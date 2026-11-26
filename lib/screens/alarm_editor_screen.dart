import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import '../alarm/alarm.dart';
import '../alarm/alarm_store.dart';
import 'qr_scan_page.dart';

/// Create or edit one alarm: time, repeat, label, sound, vibration, snoozes and the dismiss challenge.
class AlarmEditorScreen extends StatefulWidget {
  const AlarmEditorScreen({super.key, required this.store, required this.alarm, required this.isNew});

  final AlarmStore store;
  final Alarm alarm;
  final bool isNew;

  @override
  State<AlarmEditorScreen> createState() => _AlarmEditorScreenState();
}

class _AlarmEditorScreenState extends State<AlarmEditorScreen> {
  late Alarm _draft = widget.alarm;
  late final TextEditingController _label = TextEditingController(text: widget.alarm.label);
  String? _qrError;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  void _set(Alarm next) => setState(() => _draft = next);

  Future<void> _pickSound() async {
    final picked = await widget.store.platform.pickRingtone(current: _draft.sound);
    if (!mounted || picked == null) return;
    _set(_draft.copyWith(sound: picked.uri, soundTitle: picked.title));
  }

  Future<void> _registerCode() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const QrScanPage(title: 'Scan the code to register')),
    );
    if (!mounted || code == null) return;
    setState(() => _qrError = null);
    _set(_draft.copyWith(qrCode: code));
  }

  void _setChallenge(ChallengeType type) {
    // Each challenge has its own sensible amount.
    final count = switch (type) {
      ChallengeType.math => 3,
      ChallengeType.shake => 20,
      ChallengeType.sentence => 1,
      _ => _draft.count,
    };
    setState(() => _qrError = null);
    _set(_draft.copyWith(challenge: type, count: count));
  }

  Alarm get _current => _draft.copyWith(label: _label.text.trim());

  Future<void> _save() async {
    if (_draft.challenge == ChallengeType.qr && _draft.qrCode == null) {
      setState(() => _qrError = 'Register a code first, or pick another challenge.');
      return;
    }
    // Saving a new alarm switches it on.
    await widget.store.save(_current.copyWith(enabled: true));
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ok = await UiDialog.confirm(context, title: 'Delete alarm?', destructive: true, confirmLabel: 'Delete');
    if (!ok) return;
    await widget.store.delete(widget.alarm);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final a = _draft;
    return UiScaffold(
      appBar: UiAppBar(
        title: widget.isNew ? 'New alarm' : 'Edit alarm',
        actions: [
          if (!widget.isNew) UiIconButton(Icons.delete_outline_rounded, tooltip: 'Delete', onPressed: _delete),
        ],
      ),
      scrollable: true,
      bottomBar: UiBottomBar(
        children: [
          Expanded(
            child: UiButton(
              'Test alarm',
              variant: UiButtonVariant.outline,
              icon: Icons.notifications_active_rounded,
              expand: true,
              onPressed: () => widget.store.platform.testAlarm(_current),
            ),
          ),
          Expanded(child: UiButton('Save', expand: true, onPressed: _save)),
        ],
      ),
      body: UiColumn(
        gap: UiSpace.lg,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UiTimeField(
            label: 'Time',
            value: TimeOfDay(hour: a.hour, minute: a.minute),
            clearable: false,
            onChanged: (t) {
              if (t != null) _set(a.copyWith(hour: t.hour, minute: t.minute));
            },
          ),
          UiSection(
            title: 'Repeat',
            subtitle: a.repeatLabel,
            child: UiFilterChips<int>(
              options: [for (var i = 0; i < 7; i++) UiChoice(i + 1, weekdayShort[i])],
              values: a.days,
              onChanged: (s) => _set(a.copyWith(days: s)),
            ),
          ),
          UiTextField(
            label: 'Label',
            hint: 'Wake up',
            controller: _label,
            maxLength: 40,
            textCapitalization: TextCapitalization.sentences,
          ),
          UiListGroup(
            header: 'Sound',
            children: [
              UiListTile(
                'Alarm sound',
                icon: Icons.music_note_rounded,
                value: a.soundTitle ?? 'Default alarm',
                chevron: true,
                onTap: _pickSound,
              ),
              UiSwitchTile(
                'Vibrate',
                icon: Icons.vibration_rounded,
                value: a.vibrate,
                onChanged: (v) => _set(a.copyWith(vibrate: v)),
              ),
              UiSwitchTile(
                'Gradual volume',
                subtitle: 'Starts quiet and gets louder over 45 seconds.',
                icon: Icons.volume_up_rounded,
                value: a.gradual,
                onChanged: (v) => _set(a.copyWith(gradual: v)),
              ),
            ],
          ),
          UiSection(
            title: 'Snooze',
            subtitle: a.maxSnoozes == 0 ? 'No snooze' : 'Up to ${a.maxSnoozes} times, 5 minutes each',
            child: Align(
              alignment: Alignment.centerLeft,
              child: UiStepper<int>(
                value: a.maxSnoozes,
                min: 0,
                max: 5,
                onChanged: (v) => _set(a.copyWith(maxSnoozes: v)),
              ),
            ),
          ),
          UiSection(
            title: 'To dismiss the alarm',
            subtitle: a.challenge.description,
            child: UiColumn(
              gap: UiSpace.md,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                UiChoiceChips<ChallengeType>(
                  options: [for (final c in ChallengeType.values) UiChoice(c, c.label)],
                  value: a.challenge,
                  onChanged: _setChallenge,
                ),
                ..._challengeOptions(a),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _challengeOptions(Alarm a) => switch (a.challenge) {
    ChallengeType.none => const [],
    ChallengeType.math => [
      UiChoiceChips<Difficulty>(
        options: [for (final d in Difficulty.values) UiChoice(d, d.label)],
        value: a.difficulty,
        onChanged: (d) => _set(a.copyWith(difficulty: d)),
      ),
      _CountRow(
        label: 'Problems',
        value: a.count,
        min: 1,
        max: 10,
        onChanged: (v) => _set(a.copyWith(count: v)),
      ),
    ],
    ChallengeType.shake => [
      _CountRow(
        label: 'Shakes',
        value: a.count,
        min: 5,
        max: 100,
        step: 5,
        onChanged: (v) => _set(a.copyWith(count: v)),
      ),
    ],
    ChallengeType.sentence => [
      _CountRow(
        label: 'Sentences',
        value: a.count,
        min: 1,
        max: 3,
        onChanged: (v) => _set(a.copyWith(count: v)),
      ),
    ],
    ChallengeType.qr => [
      UiAlert(
        'Print or stick a QR code or barcode somewhere you must walk to, like the bathroom. '
        'Scan it once here to register it. Any code works.',
        status: UiStatus.info,
      ),
      UiListGroup(
        children: [
          UiListTile(
            a.qrCode == null ? 'Register a code' : 'Registered code',
            subtitle: a.qrCode,
            icon: Icons.qr_code_scanner_rounded,
            iconStatus: a.qrCode == null ? UiStatus.warning : UiStatus.success,
            chevron: true,
            onTap: _registerCode,
          ),
        ],
      ),
      if (_qrError != null) UiAlert(_qrError!, status: UiStatus.danger),
    ],
  };
}

class _CountRow extends StatelessWidget {
  const _CountRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step = 1,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: context.text.bodyLarge)),
        UiStepper<int>(value: value, min: min, max: max, step: step, onChanged: onChanged),
      ],
    );
  }
}
