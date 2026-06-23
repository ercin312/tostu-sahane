import 'package:equatable/equatable.dart';

enum MediaAssetKind { network, local }

class MediaAsset extends Equatable {
  const MediaAsset({
    required this.id,
    required this.source,
    required this.kind,
    required this.createdAt,
  });

  final String id;
  final String source;
  final MediaAssetKind kind;
  final DateTime createdAt;

  MediaAsset copyWith({String? source}) {
    return MediaAsset(
      id: id,
      source: source ?? this.source,
      kind: kind,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'source': source,
        'kind': kind.name,
        'created_at': createdAt.toIso8601String(),
      };

  factory MediaAsset.fromJson(Map<String, dynamic> json) {
    return MediaAsset(
      id: json['id'] as String,
      source: json['source'] as String,
      kind: MediaAssetKind.values.byName(json['kind'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  @override
  List<Object?> get props => [id, source, kind, createdAt];
}
