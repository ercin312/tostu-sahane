import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/widgets/role_logout_action.dart';
import '../../../../../firebase_options.dart';

class _TrainingExample {
  _TrainingExample({
    required this.id,
    required this.whenController,
    required this.thenController,
  });

  final String id;
  final TextEditingController whenController;
  final TextEditingController thenController;

  void dispose() {
    whenController.dispose();
    thenController.dispose();
  }

  Map<String, String> toJson() => {
        'id': id,
        'whenCustomerSays': whenController.text.trim(),
        'assistantShould': thenController.text.trim(),
      };
}

class _DayHours {
  _DayHours({
    required this.key,
    required this.labelKey,
    this.open = const TimeOfDay(hour: 10, minute: 0),
    this.close = const TimeOfDay(hour: 23, minute: 0),
    this.closed = false,
  });

  final String key;
  final String labelKey;
  TimeOfDay open;
  TimeOfDay close;
  bool closed;

  Map<String, dynamic> toJson() => {
        'open': _fmt(open),
        'close': _fmt(close),
        'closed': closed,
      };

  static String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static TimeOfDay _parse(String? raw, TimeOfDay fallback) {
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch((raw ?? '').trim());
    if (m == null) return fallback;
    final h = int.tryParse(m.group(1)!) ?? fallback.hour;
    final min = int.tryParse(m.group(2)!) ?? fallback.minute;
    if (h < 0 || h > 23 || min < 0 || min > 59) return fallback;
    return TimeOfDay(hour: h, minute: min);
  }

  factory _DayHours.fromJson(String key, String labelKey, Map? raw) {
    final map = raw == null ? <String, dynamic>{} : Map<String, dynamic>.from(raw);
    return _DayHours(
      key: key,
      labelKey: labelKey,
      open: _parse(map['open']?.toString(), const TimeOfDay(hour: 10, minute: 0)),
      close: _parse(map['close']?.toString(), const TimeOfDay(hour: 23, minute: 0)),
      closed: map['closed'] == true,
    );
  }
}

/// Yönetici: telefon AI için “müşteri X derse → asistan Y desin” eğitimi.
class AdminPhoneAiTrainingPage extends ConsumerStatefulWidget {
  const AdminPhoneAiTrainingPage({super.key});

  @override
  ConsumerState<AdminPhoneAiTrainingPage> createState() =>
      _AdminPhoneAiTrainingPageState();
}

class _AdminPhoneAiTrainingPageState
    extends ConsumerState<AdminPhoneAiTrainingPage> {
  static const _dayDefs = [
    ('mon', LocaleKeys.adminPhoneAiHoursMon),
    ('tue', LocaleKeys.adminPhoneAiHoursTue),
    ('wed', LocaleKeys.adminPhoneAiHoursWed),
    ('thu', LocaleKeys.adminPhoneAiHoursThu),
    ('fri', LocaleKeys.adminPhoneAiHoursFri),
    ('sat', LocaleKeys.adminPhoneAiHoursSat),
    ('sun', LocaleKeys.adminPhoneAiHoursSun),
  ];

  final _dio = Dio();
  final _styleController = TextEditingController();
  final _closedMessageController = TextEditingController();
  final _examples = <_TrainingExample>[];
  late final List<_DayHours> _days;
  var _hoursEnabled = false;
  var _loading = true;
  var _saving = false;
  String? _error;
  String? _status;

  static String get _projectId =>
      DefaultFirebaseOptions.currentPlatform.projectId;

  String _fn(String name) =>
      'https://us-central1-$_projectId.cloudfunctions.net/$name';

  @override
  void initState() {
    super.initState();
    _days = [
      for (final d in _dayDefs) _DayHours(key: d.$1, labelKey: d.$2),
    ];
    _closedMessageController.text =
        'Şu an kapalıyız, sipariş alamıyoruz. Mesai saatlerimiz içinde tekrar arayın. İyi günler dilerim.';
    _load();
  }

  @override
  void dispose() {
    _styleController.dispose();
    _closedMessageController.dispose();
    for (final e in _examples) {
      e.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _dio.get<Map<String, dynamic>>(_fn('getPhoneAiTraining'));
      final list = (res.data?['examples'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (!mounted) return;
      for (final e in _examples) {
        e.dispose();
      }
      _examples
        ..clear()
        ..addAll(
          list.map(
            (e) => _TrainingExample(
              id: '${e['id'] ?? UniqueKey()}',
              whenController: TextEditingController(
                text: '${e['whenCustomerSays'] ?? ''}',
              ),
              thenController: TextEditingController(
                text: '${e['assistantShould'] ?? ''}',
              ),
            ),
          ),
        );
      if (_examples.isEmpty) {
        _addExample(
          when: 'Menüde neler var?',
          then:
              'Karışık tost, kavurmalı tost, kaşarlı tost gibi seçeneklerimiz var. Hangisini istersiniz?',
        );
      }
      _styleController.text = '${res.data?['styleNotes'] ?? ''}';
      final hours = res.data?['businessHours'] is Map
          ? Map<String, dynamic>.from(res.data!['businessHours'] as Map)
          : <String, dynamic>{};
      _hoursEnabled = hours['enabled'] == true;
      final msg = '${hours['closedMessage'] ?? ''}'.trim();
      if (msg.isNotEmpty) _closedMessageController.text = msg;
      final schedule = hours['schedule'] is Map
          ? Map<String, dynamic>.from(hours['schedule'] as Map)
          : <String, dynamic>{};
      for (var i = 0; i < _days.length; i++) {
        final key = _days[i].key;
        _days[i] = _DayHours.fromJson(
          key,
          _days[i].labelKey,
          schedule[key] is Map ? schedule[key] as Map : null,
        );
      }
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _addExample({String when = '', String then = ''}) {
    setState(() {
      _examples.add(
        _TrainingExample(
          id: 'ex_${DateTime.now().microsecondsSinceEpoch}',
          whenController: TextEditingController(text: when),
          thenController: TextEditingController(text: then),
        ),
      );
    });
  }

  void _removeExample(int index) {
    setState(() {
      _examples.removeAt(index).dispose();
    });
  }

  Future<void> _pickTime({
    required _DayHours day,
    required bool isOpen,
  }) async {
    final initial = isOpen ? day.open : day.close;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: LocaleKeys.adminPhoneAiHoursTurkey.tr(),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isOpen) {
        day.open = picked;
      } else {
        day.close = picked;
      }
    });
  }

  String _labelTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
      _status = null;
    });
    try {
      final examples = _examples
          .map((e) => e.toJson())
          .where(
            (e) =>
                e['whenCustomerSays']!.isNotEmpty &&
                e['assistantShould']!.isNotEmpty,
          )
          .toList();
      final schedule = <String, dynamic>{
        for (final d in _days) d.key: d.toJson(),
      };
      final res = await _dio.post<Map<String, dynamic>>(
        _fn('savePhoneAiTraining'),
        data: {
          'examples': examples,
          'styleNotes': _styleController.text.trim(),
          'businessHours': {
            'enabled': _hoursEnabled,
            'timezone': 'Europe/Istanbul',
            'closedMessage': _closedMessageController.text.trim(),
            'schedule': schedule,
          },
        },
      );
      if (!mounted) return;
      final synced = res.data?['synced'] == true;
      final syncError = res.data?['syncError'];
      setState(() {
        _saving = false;
        _status = synced
            ? LocaleKeys.adminPhoneAiTrainingSavedSynced.tr()
            : LocaleKeys.adminPhoneAiTrainingSavedNotSynced.tr(
                namedArgs: {'error': '${syncError ?? ''}'},
              );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: synced ? AppColors.success : AppColors.warning,
          content: Text(_status!),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(LocaleKeys.adminPhoneAiTrainingTitle.tr()),
        actions: const [RoleLogoutAction()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : _save,
        icon: _saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.save_outlined),
        label: Text(LocaleKeys.adminPhoneAiTrainingSave.tr()),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Text(
                  LocaleKeys.adminPhoneAiTrainingSubtitle.tr(),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  LocaleKeys.adminPhoneAiHoursTitle.tr(),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  LocaleKeys.adminPhoneAiHoursSubtitle.tr(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(LocaleKeys.adminPhoneAiHoursEnabled.tr()),
                  subtitle: Text(LocaleKeys.adminPhoneAiHoursTurkey.tr()),
                  value: _hoursEnabled,
                  onChanged: (v) => setState(() => _hoursEnabled = v),
                ),
                if (_hoursEnabled) ...[
                  TextField(
                    controller: _closedMessageController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: LocaleKeys.adminPhoneAiHoursClosedMessage.tr(),
                      hintText:
                          LocaleKeys.adminPhoneAiHoursClosedMessageHint.tr(),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    LocaleKeys.adminPhoneAiHoursOpenDays.tr(),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    LocaleKeys.adminPhoneAiHoursOpenDaysHint.tr(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final day in _days)
                        FilterChip(
                          label: Text(day.labelKey.tr()),
                          selected: !day.closed,
                          onSelected: (open) =>
                              setState(() => day.closed = !open),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  for (final day in _days)
                    Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                day.labelKey.tr(),
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            SegmentedButton<bool>(
                              segments: [
                                ButtonSegment(
                                  value: true,
                                  label: Text(
                                    LocaleKeys.adminPhoneAiHoursOpen.tr(),
                                  ),
                                ),
                                ButtonSegment(
                                  value: false,
                                  label: Text(
                                    LocaleKeys.adminPhoneAiHoursClosed.tr(),
                                  ),
                                ),
                              ],
                              selected: {!day.closed},
                              onSelectionChanged: (s) {
                                setState(() => day.closed = !s.first);
                              },
                              style: const ButtonStyle(
                                visualDensity: VisualDensity.compact,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            TextButton(
                              onPressed: day.closed
                                  ? null
                                  : () => _pickTime(day: day, isOpen: true),
                              child: Text(_labelTime(day.open)),
                            ),
                            const Text('–'),
                            TextButton(
                              onPressed: day.closed
                                  ? null
                                  : () => _pickTime(day: day, isOpen: false),
                              child: Text(_labelTime(day.close)),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: _styleController,
                  maxLines: 12,
                  minLines: 4,
                  decoration: InputDecoration(
                    labelText: LocaleKeys.adminPhoneAiTrainingStyle.tr(),
                    hintText: LocaleKeys.adminPhoneAiTrainingStyleHint.tr(),
                    border: const OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        LocaleKeys.adminPhoneAiTrainingExamples.tr(),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _addExample(),
                      icon: const Icon(Icons.add),
                      label: Text(LocaleKeys.adminPhoneAiTrainingAdd.tr()),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                for (var i = 0; i < _examples.length; i++)
                  Card(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Text(
                                LocaleKeys.adminPhoneAiTrainingExampleN.tr(
                                  namedArgs: {'n': '${i + 1}'},
                                ),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const Spacer(),
                              IconButton(
                                onPressed: () => _removeExample(i),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                          TextField(
                            controller: _examples[i].whenController,
                            decoration: InputDecoration(
                              labelText:
                                  LocaleKeys.adminPhoneAiTrainingWhen.tr(),
                              hintText:
                                  LocaleKeys.adminPhoneAiTrainingWhenHint.tr(),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          TextField(
                            controller: _examples[i].thenController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText:
                                  LocaleKeys.adminPhoneAiTrainingThen.tr(),
                              hintText:
                                  LocaleKeys.adminPhoneAiTrainingThenHint.tr(),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(_error!, style: const TextStyle(color: AppColors.error)),
                ],
                const SizedBox(height: 80),
              ],
            ),
    );
  }
}
