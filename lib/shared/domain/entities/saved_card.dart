import 'package:equatable/equatable.dart';

class SavedCard extends Equatable {
  const SavedCard({
    required this.id,
    required this.label,
    required this.lastFour,
    required this.holderName,
    required this.expiry,
    this.isDefault = false,
  });

  final String id;
  final String label;
  final String lastFour;
  final String holderName;
  final String expiry;
  final bool isDefault;

  SavedCard copyWith({
    String? label,
    String? lastFour,
    String? holderName,
    String? expiry,
    bool? isDefault,
  }) {
    return SavedCard(
      id: id,
      label: label ?? this.label,
      lastFour: lastFour ?? this.lastFour,
      holderName: holderName ?? this.holderName,
      expiry: expiry ?? this.expiry,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'last_four': lastFour,
        'holder_name': holderName,
        'expiry': expiry,
        'is_default': isDefault,
      };

  factory SavedCard.fromJson(Map<String, dynamic> json) {
    return SavedCard(
      id: json['id'] as String,
      label: json['label'] as String,
      lastFour: json['last_four'] as String,
      holderName: json['holder_name'] as String,
      expiry: json['expiry'] as String,
      isDefault: json['is_default'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [id, label, lastFour, holderName, expiry, isDefault];
}
