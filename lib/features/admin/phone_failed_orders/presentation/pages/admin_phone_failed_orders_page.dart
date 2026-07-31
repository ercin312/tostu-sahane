import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../../core/localization/locale_keys.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/app_spacing.dart';
import '../../../../../../core/widgets/role_logout_action.dart';
import '../../../../../../firebase_options.dart';

/// Tamamlanmayan telefon görüşmeleri + tüm arama konuşma logları.
class AdminPhoneFailedOrdersPage extends ConsumerStatefulWidget {
  const AdminPhoneFailedOrdersPage({super.key});

  @override
  ConsumerState<AdminPhoneFailedOrdersPage> createState() =>
      _AdminPhoneFailedOrdersPageState();
}

class _AdminPhoneFailedOrdersPageState
    extends ConsumerState<AdminPhoneFailedOrdersPage>
    with SingleTickerProviderStateMixin {
  final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 90),
    ),
  );
  late final TabController _tabs;
  var _loading = false;
  String? _error;
  List<Map<String, dynamic>> _orders = const [];
  List<Map<String, dynamic>> _logs = const [];
  var _statusFilter = 'pending';
  var _logOutcome = '';

  static String get _projectId =>
      DefaultFirebaseOptions.currentPlatform.projectId;

  String _fn(String name) =>
      'https://us-central1-$_projectId.cloudfunctions.net/$name';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() {
      if (_tabs.indexIsChanging) return;
      if (_tabs.index == 0) {
        _loadFailed(sync: false);
      } else {
        _loadLogs();
      }
    });
    _loadFailed(sync: true);
    _loadLogs();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadFailed({bool sync = true}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        _fn('listFailedPhoneOrders'),
        queryParameters: {
          'sync': sync ? 'true' : 'false',
          if (_statusFilter.isNotEmpty) 'status': _statusFilter,
        },
      );
      final list = (res.data?['orders'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (!mounted) return;
      setState(() {
        _orders = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadLogs() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        _fn('listPhoneCallLogs'),
        queryParameters: {
          if (_logOutcome.isNotEmpty) 'outcome': _logOutcome,
        },
      );
      final list = (res.data?['logs'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (!mounted) return;
      setState(() {
        _logs = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  String _asString(dynamic value, [String fallback = '']) {
    if (value == null) return fallback;
    final s = value.toString();
    return s.isEmpty ? fallback : s;
  }

  Future<void> _setStatus(Map<String, dynamic> order, String status) async {
    final id = _asString(order['id'] ?? order['conversation_id']);
    if (id.isEmpty) return;
    try {
      await _dio.post(
        _fn('updateFailedPhoneOrder'),
        data: {'id': id, 'status': status},
        options: Options(contentType: 'application/json'),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LocaleKeys.adminPhoneFailedOrdersUpdated.tr()),
        ),
      );
      await _loadFailed(sync: false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _callback(Map<String, dynamic> order) async {
    final digits = _asString(order['phone_digits']).replaceAll(RegExp(r'\D'), '');
    final display = _asString(order['phone_display']);
    if (digits.isNotEmpty) {
      final uri = Uri(scheme: 'tel', path: digits.length == 10 ? '0$digits' : digits);
      try {
        await launchUrl(uri);
      } catch (_) {
        await Clipboard.setData(
          ClipboardData(text: display.isNotEmpty ? display : digits),
        );
      }
    } else if (display.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: display));
    }
    await _setStatus(order, 'called_back');
  }

  String _formatWhen(dynamic raw) {
    if (raw == null) return '';
    final s = raw.toString();
    final dt = DateTime.tryParse(s)?.toLocal();
    if (dt == null) return s;
    return DateFormat('dd.MM.yyyy HH:mm').format(dt);
  }

  String _transcriptText(Map<String, dynamic> log) {
    final turns = log['transcript'];
    if (turns is List && turns.isNotEmpty) {
      return turns
          .whereType<Map>()
          .map((t) {
            final role = _asString(t['role']);
            final msg = _asString(t['message']);
            final who = role == 'agent' ? 'Asistan' : 'Müşteri';
            return '$who: $msg';
          })
          .where((s) => s.trim().isNotEmpty)
          .join('\n');
    }
    return _asString(log['notes'] ?? log['transcript_summary']);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(LocaleKeys.adminPhoneFailedOrdersTitle.tr()),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: LocaleKeys.adminPhoneCallLogsFailedTab.tr()),
            Tab(text: LocaleKeys.adminPhoneCallLogsTab.tr()),
          ],
        ),
        actions: [
          IconButton(
            tooltip: LocaleKeys.adminPhoneFailedOrdersRefresh.tr(),
            onPressed: _loading
                ? null
                : () {
                    if (_tabs.index == 0) {
                      _loadFailed(sync: true);
                    } else {
                      _loadLogs();
                    }
                  },
            icon: const Icon(Icons.refresh),
          ),
          const RoleLogoutAction(),
        ],
      ),
      body: Column(
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _buildFailedTab(context),
                _buildLogsTab(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFailedTab(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                LocaleKeys.adminPhoneFailedOrdersHint.tr(),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'pending',
                    label: Text(LocaleKeys.adminPhoneFailedOrdersPending.tr()),
                  ),
                  ButtonSegment(
                    value: 'called_back',
                    label: Text(LocaleKeys.adminPhoneFailedOrdersCalled.tr()),
                  ),
                  ButtonSegment(
                    value: '',
                    label: Text(LocaleKeys.adminPhoneFailedOrdersAll.tr()),
                  ),
                ],
                selected: {_statusFilter},
                onSelectionChanged: (s) {
                  setState(() => _statusFilter = s.first);
                  _loadFailed(sync: false);
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: _orders.isEmpty && !_loading
              ? Center(
                  child: Text(LocaleKeys.adminPhoneFailedOrdersEmpty.tr()),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: _orders.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final o = _orders[index];
                    final phone = _asString(
                      o['phone_display'] ?? o['phone_digits'],
                    );
                    final name = _asString(o['customer_name']);
                    final notes = _asString(
                      o['notes'] ?? o['transcript_summary'],
                    );
                    final status = _asString(o['status'], 'pending');
                    final when = _formatWhen(o['created_at']);
                    final duration = o['call_duration_secs'];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    name.isNotEmpty ? '$name · $phone' : phone,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                Chip(
                                  label: Text(status),
                                  visualDensity: VisualDensity.compact,
                                  backgroundColor: status == 'pending'
                                      ? AppColors.primary.withValues(alpha: 0.12)
                                      : null,
                                ),
                              ],
                            ),
                            if (when.isNotEmpty || duration != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                [
                                  if (when.isNotEmpty) when,
                                  if (duration != null) '${duration}s',
                                ].join(' · '),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                            if (notes.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                notes,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                            const SizedBox(height: AppSpacing.sm),
                            Wrap(
                              spacing: AppSpacing.sm,
                              runSpacing: AppSpacing.sm,
                              children: [
                                FilledButton.icon(
                                  onPressed: () => _callback(o),
                                  icon: const Icon(Icons.phone_callback),
                                  label: Text(
                                    LocaleKeys.adminPhoneFailedOrdersCallback
                                        .tr(),
                                  ),
                                ),
                                OutlinedButton(
                                  onPressed: () => _setStatus(o, 'dismissed'),
                                  child: Text(
                                    LocaleKeys.adminPhoneFailedOrdersDismiss
                                        .tr(),
                                  ),
                                ),
                                if (status != 'pending')
                                  TextButton(
                                    onPressed: () => _setStatus(o, 'pending'),
                                    child: Text(
                                      LocaleKeys.adminPhoneFailedOrdersReopen
                                          .tr(),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildLogsTab(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: SegmentedButton<String>(
            segments: [
              ButtonSegment(
                value: '',
                label: Text(LocaleKeys.adminPhoneFailedOrdersAll.tr()),
              ),
              ButtonSegment(
                value: 'success',
                label: Text(LocaleKeys.adminPhoneCallLogsSuccess.tr()),
              ),
              ButtonSegment(
                value: 'failed',
                label: Text(LocaleKeys.adminPhoneCallLogsFailed.tr()),
              ),
            ],
            selected: {_logOutcome},
            onSelectionChanged: (s) {
              setState(() => _logOutcome = s.first);
              _loadLogs();
            },
          ),
        ),
        Expanded(
          child: _logs.isEmpty && !_loading
              ? Center(child: Text(LocaleKeys.adminPhoneCallLogsEmpty.tr()))
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: _logs.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    final phone = _asString(
                      log['phone_display'] ?? log['phone_digits'],
                    );
                    final outcome = _asString(log['outcome'], 'failed');
                    final when = _formatWhen(
                      log['started_at'] ?? log['updated_at'],
                    );
                    final transcript = _transcriptText(log);
                    final success = outcome == 'success';
                    return Card(
                      child: ExpansionTile(
                        title: Text(
                          phone.isEmpty ? log['id']?.toString() ?? '-' : phone,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          [
                            success
                                ? LocaleKeys.adminPhoneCallLogsSuccess.tr()
                                : LocaleKeys.adminPhoneCallLogsFailed.tr(),
                            if (when.isNotEmpty) when,
                            if (log['call_duration_secs'] != null)
                              '${log['call_duration_secs']}s',
                          ].join(' · '),
                        ),
                        children: [
                          if (transcript.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.md,
                                0,
                                AppSpacing.md,
                                AppSpacing.md,
                              ),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: SelectableText(
                                  '${LocaleKeys.adminPhoneCallLogsTranscript.tr()}\n\n$transcript',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
