import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../shared/domain/entities/saved_card.dart';
import '../providers/saved_cards_provider.dart';

class SavedCardsPage extends ConsumerWidget {
  const SavedCardsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardsAsync = ref.watch(savedCardsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(LocaleKeys.profileSavedCards.tr())),
      body: cardsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(LocaleKeys.commonError.tr())),
        data: (cards) => cards.isEmpty
            ? Center(child: Text(LocaleKeys.savedCardsEmpty.tr()))
            : ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: cards.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) =>
                    _SavedCardTile(card: cards[index]),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context, ref),
        icon: const Icon(Icons.add),
        label: Text(LocaleKeys.savedCardsAdd.tr()),
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final labelController = TextEditingController();
    final lastFourController = TextEditingController();
    final holderController = TextEditingController();
    final expiryController = TextEditingController();
    var setDefault = false;

    showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(LocaleKeys.savedCardsAdd.tr()),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: labelController,
                      decoration: InputDecoration(
                        labelText: LocaleKeys.savedCardsLabel.tr(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: lastFourController,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: LocaleKeys.savedCardsLastFour.tr(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: holderController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: LocaleKeys.paymentCardHolder.tr(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: expiryController,
                      keyboardType: TextInputType.datetime,
                      decoration: InputDecoration(
                        labelText: LocaleKeys.savedCardsExpiry.tr(),
                        hintText: 'MM/YY',
                      ),
                    ),
                    CheckboxListTile(
                      value: setDefault,
                      onChanged: (v) => setState(() => setDefault = v ?? false),
                      title: Text(LocaleKeys.savedCardsSetDefault.tr()),
                      activeColor: AppColors.primary,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(LocaleKeys.commonCancel.tr()),
                ),
                TextButton(
                  onPressed: () async {
                    if (lastFourController.text.length != 4 ||
                        holderController.text.trim().isEmpty) {
                      return;
                    }
                    await ref.read(savedCardsProvider.notifier).addCard(
                          label: labelController.text.trim().isEmpty
                              ? LocaleKeys.savedCardsDefaultLabel.tr()
                              : labelController.text.trim(),
                          lastFour: lastFourController.text,
                          holderName: holderController.text.trim(),
                          expiry: expiryController.text.trim(),
                          setDefault: setDefault,
                        );
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: Text(LocaleKeys.commonSave.tr()),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _SavedCardTile extends ConsumerWidget {
  const _SavedCardTile({required this.card});

  final SavedCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primaryDark,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  card.label,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.white,
                      ),
                ),
              ),
              if (card.isDefault)
                Chip(
                  label: Text(
                    LocaleKeys.addressDefaultBadge.tr(),
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '**** **** **** ${card.lastFour}',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.white,
                  letterSpacing: 2,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            card.holderName,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.white.withValues(alpha: 0.9),
                ),
          ),
          Text(
            card.expiry,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.white.withValues(alpha: 0.8),
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              if (!card.isDefault)
                TextButton(
                  onPressed: () =>
                      ref.read(savedCardsProvider.notifier).setDefault(card.id),
                  child: Text(
                    LocaleKeys.savedCardsSetDefault.tr(),
                    style: const TextStyle(color: AppColors.white),
                  ),
                ),
              TextButton(
                onPressed: () =>
                    ref.read(savedCardsProvider.notifier).removeCard(card.id),
                child: Text(
                  LocaleKeys.commonRemove.tr(),
                  style: TextStyle(color: AppColors.white.withValues(alpha: 0.9)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
