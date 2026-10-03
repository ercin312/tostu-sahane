/// Yönetici duyurusu. Tüm kullanıcılara gider; ayrıntı bildirime tıklanınca açılır.
enum BroadcastKind { announcement, campaign }

class AppBroadcast {
  const AppBroadcast({
    required this.id,
    required this.title,
    required this.body,
    required this.kind,
    this.campaignId,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final BroadcastKind kind;
  final String? campaignId;
  final DateTime createdAt;

  bool get isCampaign => kind == BroadcastKind.campaign;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'kind': kind.name,
        if (campaignId != null && campaignId!.isNotEmpty)
          'campaign_id': campaignId,
        'created_at': createdAt.toIso8601String(),
      };

  factory AppBroadcast.fromJson(Map<String, dynamic> json) {
    final kindName = json['kind'] as String? ?? BroadcastKind.announcement.name;
    return AppBroadcast(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      kind: BroadcastKind.values.asNameMap()[kindName] ??
          BroadcastKind.announcement,
      campaignId: json['campaign_id'] as String?,
      createdAt: DateTime.tryParse('${json['created_at'] ?? ''}') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
