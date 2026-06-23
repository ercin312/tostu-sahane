import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/promotion_utils.dart';
import '../../../features/customer/home/presentation/providers/branch_provider.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/promotion_campaign.dart';
import 'repository_providers.dart';

final promotionCampaignsProvider = StreamProvider<List<PromotionCampaign>>((ref) {
  return ref.watch(promotionRepositoryProvider).watchPromotionCampaigns();
});

final activePromotionCampaignsProvider = Provider<List<PromotionCampaign>>((ref) {
  final campaigns = ref.watch(promotionCampaignsProvider).value ?? [];
  return campaigns.where((campaign) => campaign.isActive).toList()
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
});

final productCategoryMapProvider = Provider<Map<String, ProductCategory>>((ref) {
  final products = ref.watch(productsProvider).value ?? [];
  return {for (final product in products) product.id: product.category};
});

Future<void> savePromotionCampaign(
  WidgetRef ref,
  PromotionCampaign campaign,
) async {
  final repo = ref.read(promotionRepositoryProvider);
  final existing = ref.read(promotionCampaignsProvider).valueOrNull ?? [];
  final isUpdate = existing.any((item) => item.id == campaign.id);
  if (isUpdate) {
    await repo.updatePromotionCampaign(campaign);
  } else {
    await repo.createPromotionCampaign(campaign);
  }
}

Future<void> deletePromotionCampaign(WidgetRef ref, String id) async {
  await ref.read(promotionRepositoryProvider).deletePromotionCampaign(id);
}
