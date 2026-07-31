import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../../core/localization/locale_keys.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/app_spacing.dart';
import '../../../../../../core/widgets/role_logout_action.dart';
import '../../../../../../firebase_options.dart';

/// Telefon sipariş müşteri defteri — CSV/Excel içe aktarma + liste/düzenle/sil.
class AdminPhoneCustomersPage extends ConsumerStatefulWidget {
  const AdminPhoneCustomersPage({super.key});

  @override
  ConsumerState<AdminPhoneCustomersPage> createState() =>
      _AdminPhoneCustomersPageState();
}

class _AdminPhoneCustomersPageState
    extends ConsumerState<AdminPhoneCustomersPage> {
  final _csvController = TextEditingController();
  final _dio = Dio();
  var _loading = false;
  var _importing = false;
  String? _error;
  List<Map<String, dynamic>> _customers = const [];

  static String get _projectId =>
      DefaultFirebaseOptions.currentPlatform.projectId;

  String _fn(String name) =>
      'https://us-central1-$_projectId.cloudfunctions.net/$name';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _csvController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res =
          await _dio.get<Map<String, dynamic>>(_fn('listPhoneCustomers'));
      final list = (res.data?['customers'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (!mounted) return;
      setState(() {
        _customers = list;
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

  List<Map<String, String>> _parseCsv(String raw) {
    final lines = raw
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.length < 2) return const [];
    final sep = lines.first.contains(';') ? ';' : ',';
    final headers = lines.first
        .split(sep)
        .map((h) => h.trim().replaceAll('"', '').toLowerCase())
        .toList();
    final rows = <Map<String, String>>[];
    for (final line in lines.skip(1)) {
      final cols =
          line.split(sep).map((c) => c.trim().replaceAll('"', '')).toList();
      final row = <String, String>{};
      for (var i = 0; i < headers.length; i++) {
        row[headers[i]] = i < cols.length ? cols[i] : '';
      }
      rows.add(row);
    }
    return rows;
  }

  Future<void> _import() async {
    final rows = _parseCsv(_csvController.text);
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleKeys.adminPhoneCustomersCsvEmpty.tr())),
      );
      return;
    }
    setState(() => _importing = true);
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        _fn('importPhoneCustomers'),
        data: {'rows': rows},
        options: Options(contentType: 'application/json'),
      );
      final imported = res.data?['imported'] ?? 0;
      final skipped = res.data?['skipped'] ?? 0;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LocaleKeys.adminPhoneCustomersImportResult.tr(
              namedArgs: {
                'imported': '$imported',
                'skipped': '$skipped',
              },
            ),
          ),
        ),
      );
      _csvController.clear();
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  void _pasteTemplate() {
    const template =
        'telefon;isim;firma;adres;tarif\n'
        '05321234567;Ahmet Yılmaz;Yılmaz Ltd;Oba Mah. Atatürk Cad. No:12;Kapı 1234\n';
    _csvController.text = template;
    Clipboard.setData(const ClipboardData(text: template));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(LocaleKeys.adminPhoneCustomersTemplateCopied.tr()),
      ),
    );
  }

  Future<void> _editCustomer(Map<String, dynamic> customer) async {
    final originalId =
        '${customer['id'] ?? customer['phone_digits'] ?? ''}'.trim();
    final phoneCtrl = TextEditingController(
      text: '${customer['phone_display'] ?? customer['phone_digits'] ?? ''}',
    );
    final nameCtrl =
        TextEditingController(text: '${customer['name'] ?? ''}');
    final companyCtrl =
        TextEditingController(text: '${customer['company'] ?? ''}');
    final addressCtrl =
        TextEditingController(text: '${customer['address'] ?? ''}');
    final directionsCtrl = TextEditingController(
      text:
          '${customer['delivery_directions'] ?? customer['directions'] ?? ''}',
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(LocaleKeys.adminPhoneCustomersEdit.tr()),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: phoneCtrl,
                    decoration: InputDecoration(
                      labelText: LocaleKeys.adminPhoneCustomersPhone.tr(),
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: LocaleKeys.adminPhoneCustomersName.tr(),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: companyCtrl,
                    decoration: InputDecoration(
                      labelText: LocaleKeys.adminPhoneCustomersCompany.tr(),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: addressCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: LocaleKeys.adminPhoneCustomersAddress.tr(),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: directionsCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText:
                          LocaleKeys.adminPhoneCustomersDirections.tr(),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(LocaleKeys.adminPhoneCustomersSave.tr()),
            ),
          ],
        );
      },
    );

    final phone = phoneCtrl.text;
    final name = nameCtrl.text;
    final company = companyCtrl.text;
    final address = addressCtrl.text;
    final directions = directionsCtrl.text;
    phoneCtrl.dispose();
    nameCtrl.dispose();
    companyCtrl.dispose();
    addressCtrl.dispose();
    directionsCtrl.dispose();

    if (saved != true || !mounted) return;

    try {
      await _dio.post(
        _fn('updatePhoneCustomer'),
        data: {
          'id': originalId,
          'phone': phone.trim(),
          'name': name.trim(),
          'company': company.trim(),
          'address': address.trim(),
          'deliveryDirections': directions.trim(),
        },
        options: Options(contentType: 'application/json'),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleKeys.adminPhoneCustomersSaved.tr())),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _deleteCustomer(Map<String, dynamic> customer) async {
    final phone =
        '${customer['phone_display'] ?? customer['phone_digits'] ?? customer['id'] ?? ''}';
    final id = '${customer['id'] ?? customer['phone_digits'] ?? ''}'.trim();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(LocaleKeys.adminPhoneCustomersDelete.tr()),
        content: Text(
          LocaleKeys.adminPhoneCustomersDeleteConfirm.tr(
            namedArgs: {'phone': phone},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(LocaleKeys.adminPhoneCustomersDelete.tr()),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _dio.post(
        _fn('deletePhoneCustomer'),
        data: {'id': id},
        options: Options(contentType: 'application/json'),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleKeys.adminPhoneCustomersDeleted.tr())),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(LocaleKeys.adminPhoneCustomersTitle.tr()),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          const RoleLogoutAction(),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(
            LocaleKeys.adminPhoneCustomersHint.tr(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: _pasteTemplate,
            icon: const Icon(Icons.copy_all_outlined),
            label: Text(LocaleKeys.adminPhoneCustomersTemplate.tr()),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _csvController,
            maxLines: 10,
            decoration: InputDecoration(
              labelText: LocaleKeys.adminPhoneCustomersCsvLabel.tr(),
              alignLabelWithHint: true,
              border: const OutlineInputBorder(),
              hintText:
                  'telefon;isim;firma;adres;tarif\n0532...;Ali;Firma;Adres;Tarif',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _importing ? null : _import,
              icon: _importing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(LocaleKeys.adminPhoneCustomersSavePaste.tr()),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            LocaleKeys.adminPhoneCustomersListTitle.tr(
              namedArgs: {'count': '${_customers.length}'},
            ),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Text(_error!, style: const TextStyle(color: AppColors.error))
          else if (_customers.isEmpty)
            Text(LocaleKeys.adminPhoneCustomersEmpty.tr())
          else
            ..._customers.map((c) {
              final phone = c['phone_display'] ?? c['phone_digits'] ?? '';
              final name = c['name'] ?? '';
              final company = c['company'] ?? '';
              final address = c['address'] ?? '';
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.phone_in_talk_outlined),
                  title: Text(
                    () {
                      final parts = <String>[
                        if (company.toString().trim().isNotEmpty)
                          company.toString(),
                        if (name.toString().trim().isNotEmpty) name.toString(),
                      ];
                      if (parts.isEmpty) return phone.toString();
                      return parts.join(' · ');
                    }(),
                  ),
                  subtitle: Text(
                    [
                      phone.toString(),
                      if (address.toString().isNotEmpty) address.toString(),
                    ].join('\n'),
                  ),
                  isThreeLine: address.toString().isNotEmpty,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: LocaleKeys.adminPhoneCustomersEdit.tr(),
                        onPressed: () => _editCustomer(c),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: LocaleKeys.adminPhoneCustomersDelete.tr(),
                        onPressed: () => _deleteCustomer(c),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
