import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../shared/domain/entities/saved_card.dart';

/// null = yeni kart, SavedCard = kayıtlı kart seçili
final selectedCheckoutCardProvider = StateProvider<SavedCard?>((ref) => null);
