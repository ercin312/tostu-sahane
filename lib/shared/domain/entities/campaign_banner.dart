import 'package:equatable/equatable.dart';

class CampaignBanner extends Equatable {
  const CampaignBanner({
    required this.id,
    this.title = '',
    this.imageUrl,
    this.sortOrder = 0,
    this.isActive = true,
    this.actionUrl,
    this.actionLabel,
  });

  final String id;
  final String title;
  final String? imageUrl;
  final int sortOrder;
  final bool isActive;
  final String? actionUrl;
  final String? actionLabel;

  CampaignBanner copyWith({
    String? id,
    String? title,
    String? imageUrl,
    int? sortOrder,
    bool? isActive,
    String? actionUrl,
    String? actionLabel,
  }) {
    return CampaignBanner(
      id: id ?? this.id,
      title: title ?? this.title,
      imageUrl: imageUrl ?? this.imageUrl,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      actionUrl: actionUrl ?? this.actionUrl,
      actionLabel: actionLabel ?? this.actionLabel,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'image_url': imageUrl,
        'sort_order': sortOrder,
        'is_active': isActive,
        'action_url': actionUrl,
        'action_label': actionLabel,
      };

  factory CampaignBanner.fromJson(Map<String, dynamic> json) {
    return CampaignBanner(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      actionUrl: json['action_url'] as String?,
      actionLabel: json['action_label'] as String?,
    );
  }

  @override
  List<Object?> get props =>
      [id, title, imageUrl, sortOrder, isActive, actionUrl, actionLabel];
}
