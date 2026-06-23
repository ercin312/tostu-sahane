import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/router/route_paths.dart';
import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/format_utils.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../core/widgets/role_logout_action.dart';
import '../../../../../shared/data/repositories/courier_cash_remittance_repository.dart';
import '../../../../../shared/data/repositories/courier_wallet_repository.dart';
import '../../../../../shared/domain/entities/courier_cash_remittance.dart';
import '../../../../../shared/domain/entities/courier_wallet.dart';
import '../../../../../shared/domain/usecases/courier/courier_wallet_use_cases.dart';
import '../../../../../shared/presentation/providers/cash_remittance_providers.dart';
import '../../../../auth/presentation/providers/auth_provider.dart';
import '../providers/courier_wallet_provider.dart';

class CourierWalletPage extends ConsumerStatefulWidget {
  const CourierWalletPage({super.key});

  @override
  ConsumerState<CourierWalletPage> createState() => _CourierWalletPageState();
}

class _CourierWalletPageState extends ConsumerState<CourierWalletPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _payoutAmountController = TextEditingController();
  final _noteController = TextEditingController();
  var _payoutLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _payoutAmountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _requestRemittance(double maxAmount) async {
    final auth = ref.read(authProvider);
    if (auth == null) return;

    final amount =
        double.tryParse(_payoutAmountController.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      _showSnack(LocaleKeys.courierPayoutInvalidAmount);
      return;
    }

    setState(() => _payoutLoading = true);
    try {
      await ref.read(requestCourierRemittanceUseCaseProvider).call(
            RequestCourierRemittanceParams(
              courierId: auth.user.id,
              courierName: auth.user.name,
              amount: amount,
              courierNote: _noteController.text.trim().isEmpty
                  ? null
                  : _noteController.text.trim(),
            ),
          );
      _payoutAmountController.clear();
      _noteController.clear();
      ref.invalidate(courierWalletSummaryProvider);
      ref.invalidate(courierWalletHistoryProvider);
      if (mounted) _showSnack(LocaleKeys.courierPayoutSuccess);
    } on CourierPayoutException catch (e) {
      if (mounted) _showSnack(e.messageKey);
    } on CourierRemittanceException catch (e) {
      if (mounted) _showSnack(e.messageKey);
    } finally {
      if (mounted) setState(() => _payoutLoading = false);
    }
  }

  void _showSnack(String key) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(key.tr())),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(courierWalletSummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(LocaleKeys.courierWalletTitle.tr()),
        actions: const [RoleLogoutAction()],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: LocaleKeys.courierWalletTabOverview.tr()),
            Tab(text: LocaleKeys.courierWalletTabHistory.tr()),
            Tab(text: LocaleKeys.courierWalletTabPayout.tr()),
          ],
        ),
      ),
      body: summaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(LocaleKeys.commonError.tr())),
        data: (CourierWalletSummary summary) => TabBarView(
          controller: _tabController,
          children: [
            _OverviewTab(
              summary: summary,
              onLogout: () async {
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) context.go(RoutePaths.authLogin);
              },
            ),
            const _HistoryTab(),
            _PayoutTab(
              summary: summary,
              amountController: _payoutAmountController,
              noteController: _noteController,
              loading: _payoutLoading,
              onRequest: () => _requestRemittance(summary.availableBalance),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.summary,
    required this.onLogout,
  });

  final CourierWalletSummary summary;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _WalletCard(
          icon: Icons.account_balance_wallet_outlined,
          title: LocaleKeys.courierAvailableBalance,
          value: FormatUtils.currency(summary.availableBalance),
          color: AppColors.primary,
        ),
        const SizedBox(height: AppSpacing.md),
        _WalletCard(
          icon: Icons.delivery_dining,
          title: LocaleKeys.courierTodayDeliveries,
          value: '${summary.todayDeliveries}',
          color: AppColors.primary,
        ),
        const SizedBox(height: AppSpacing.md),
        _WalletCard(
          icon: Icons.payments,
          title: LocaleKeys.courierCashCollected,
          value: FormatUtils.currency(summary.todayCash),
          color: AppColors.success,
        ),
        const SizedBox(height: AppSpacing.md),
        _WalletCard(
          icon: Icons.credit_card,
          title: LocaleKeys.courierCardCollected,
          value: FormatUtils.currency(summary.todayCard),
          color: AppColors.warning,
        ),
        const SizedBox(height: AppSpacing.md),
        _WalletCard(
          icon: Icons.hourglass_top,
          title: LocaleKeys.courierPendingPayout,
          value: FormatUtils.currency(summary.pendingPayout),
          color: AppColors.textSecondary,
        ),
        const SizedBox(height: AppSpacing.md),
        _WalletCard(
          icon: Icons.account_balance,
          title: LocaleKeys.courierApprovedRemitted,
          value: FormatUtils.currency(summary.approvedRemitted),
          color: AppColors.success,
        ),
        const SizedBox(height: AppSpacing.md),
        _WalletCard(
          icon: Icons.trending_up,
          title: LocaleKeys.courierTotalEarned,
          value: FormatUtils.currency(summary.totalEarned),
          color: AppColors.success,
        ),
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          labelKey: LocaleKeys.authLogout,
          onPressed: onLogout,
        ),
      ],
    );
  }
}

class _HistoryTab extends ConsumerWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(courierWalletHistoryProvider);

    return historyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(child: Text(LocaleKeys.commonError.tr())),
      data: (entries) {
        if (entries.isEmpty) {
          return Center(child: Text(LocaleKeys.courierWalletHistoryEmpty.tr()));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: entries.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            return _HistoryTile(entry: entries[index]);
          },
        );
      },
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry});

  final CourierWalletEntry entry;

  @override
  Widget build(BuildContext context) {
    final isPayout = entry.type == CourierWalletEntryType.payout;
    final title = isPayout
        ? LocaleKeys.courierWalletEntryPayout.tr()
        : LocaleKeys.orderNumber.tr(
            namedArgs: {'number': '${entry.orderNumber ?? '-'}'},
          );

    final subtitleParts = <String>[
      DateFormat('dd.MM.yyyy HH:mm').format(entry.createdAt),
    ];
    if (isPayout && entry.remittanceStatus != null) {
      subtitleParts.add(_remittanceStatusLabel(entry.remittanceStatus!));
    }
    if (entry.note != null && entry.note!.isNotEmpty) {
      subtitleParts.add(entry.note!);
    }

    final amountColor = isPayout ? AppColors.error : AppColors.success;
    final prefix = isPayout ? '-' : '+';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: amountColor.withValues(alpha: 0.12),
        child: Icon(
          isPayout ? Icons.account_balance : Icons.delivery_dining,
          color: amountColor,
        ),
      ),
      title: Text(title),
      subtitle: Text(subtitleParts.join(' · ')),
      trailing: Text(
        '$prefix${FormatUtils.currency(entry.amount)}',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: amountColor,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  String _remittanceStatusLabel(CourierCashRemittanceStatus status) {
    return switch (status) {
      CourierCashRemittanceStatus.pending =>
        LocaleKeys.cashRemittanceStatusPending.tr(),
      CourierCashRemittanceStatus.approved =>
        LocaleKeys.cashRemittanceStatusApproved.tr(),
      CourierCashRemittanceStatus.rejected =>
        LocaleKeys.cashRemittanceStatusRejected.tr(),
    };
  }
}

class _PayoutTab extends ConsumerWidget {
  const _PayoutTab({
    required this.summary,
    required this.amountController,
    required this.noteController,
    required this.loading,
    required this.onRequest,
  });

  final CourierWalletSummary summary;
  final TextEditingController amountController;
  final TextEditingController noteController;
  final bool loading;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remittancesAsync = ref.watch(courierCashRemittancesProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            LocaleKeys.courierPayoutDescription.tr(),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            LocaleKeys.courierAvailableBalance.tr(),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            FormatUtils.currency(summary.availableBalance),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: LocaleKeys.courierPayoutAmount.tr(),
              prefixText: '₺ ',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: noteController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: LocaleKeys.courierRemittanceNoteHint.tr(),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            labelKey: LocaleKeys.courierPayoutRequest,
            onPressed: loading || summary.availableBalance <= 0 ? null : onRequest,
          ),
          if (loading)
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.md),
              child: Center(child: CircularProgressIndicator()),
            ),
          const SizedBox(height: AppSpacing.xl),
          remittancesAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (remittances) {
              if (remittances.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    LocaleKeys.courierWalletTabPayout.tr(),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ...remittances.map(
                    (r) => Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: ListTile(
                        leading: Icon(
                          Icons.receipt_long,
                          color: _statusColor(r.status),
                        ),
                        title: Text(FormatUtils.currency(r.amount)),
                        subtitle: Text(
                          '${DateFormat('dd.MM.yyyy HH:mm').format(r.requestedAt)} · ${_statusLabel(r.status)}',
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Color _statusColor(CourierCashRemittanceStatus status) {
    return switch (status) {
      CourierCashRemittanceStatus.pending => AppColors.warning,
      CourierCashRemittanceStatus.approved => AppColors.success,
      CourierCashRemittanceStatus.rejected => AppColors.error,
    };
  }

  String _statusLabel(CourierCashRemittanceStatus status) {
    return switch (status) {
      CourierCashRemittanceStatus.pending =>
        LocaleKeys.cashRemittanceStatusPending.tr(),
      CourierCashRemittanceStatus.approved =>
        LocaleKeys.cashRemittanceStatusApproved.tr(),
      CourierCashRemittanceStatus.rejected =>
        LocaleKeys.cashRemittanceStatusRejected.tr(),
    };
  }
}

class _WalletCard extends StatelessWidget {
  const _WalletCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 36),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title.tr(), style: Theme.of(context).textTheme.bodySmall),
                Text(value, style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
