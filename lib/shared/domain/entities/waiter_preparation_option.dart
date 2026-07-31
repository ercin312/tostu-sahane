import 'package:equatable/equatable.dart';

class WaiterPreparationOption extends Equatable {
  const WaiterPreparationOption({
    required this.id,
    required this.labelTr,
    required this.labelEn,
    this.enabled = true,
    this.sortOrder = 0,
  });

  final String id;
  final String labelTr;
  final String labelEn;
  final bool enabled;
  final int sortOrder;

  WaiterPreparationOption copyWith({
    String? id,
    String? labelTr,
    String? labelEn,
    bool? enabled,
    int? sortOrder,
  }) {
    return WaiterPreparationOption(
      id: id ?? this.id,
      labelTr: labelTr ?? this.labelTr,
      labelEn: labelEn ?? this.labelEn,
      enabled: enabled ?? this.enabled,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label_tr': labelTr,
        'label_en': labelEn,
        'enabled': enabled,
        'sort_order': sortOrder,
      };

  factory WaiterPreparationOption.fromJson(Map<String, dynamic> json) {
    return WaiterPreparationOption(
      id: json['id'] as String,
      labelTr: json['label_tr'] as String? ?? json['id'] as String,
      labelEn: json['label_en'] as String? ?? json['id'] as String,
      enabled: json['enabled'] as bool? ?? true,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props => [id, labelTr, labelEn, enabled, sortOrder];
}
