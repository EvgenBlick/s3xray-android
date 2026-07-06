class SupportTicketMessage {
  const SupportTicketMessage({
    required this.id,
    required this.messageText,
    required this.isFromAdmin,
    required this.hasMedia,
    required this.mediaType,
    required this.mediaFileId,
    required this.mediaCaption,
    required this.createdAt,
  });

  final int id;
  final String messageText;
  final bool isFromAdmin;
  final bool hasMedia;
  final String? mediaType;
  final String? mediaFileId;
  final String? mediaCaption;
  final DateTime createdAt;

  factory SupportTicketMessage.fromJson(Map<String, Object?> json) {
    return SupportTicketMessage(
      id: (json['id'] as num?)?.toInt() ?? 0,
      messageText: (json['message_text'] as String? ?? '').trim(),
      isFromAdmin: json['is_from_admin'] as bool? ?? false,
      hasMedia: json['has_media'] as bool? ?? false,
      mediaType: json['media_type'] as String?,
      mediaFileId: json['media_file_id'] as String?,
      mediaCaption: json['media_caption'] as String?,
      createdAt: DateTime.parse(
        (json['created_at'] as String?) ??
            DateTime.now().toUtc().toIso8601String(),
      ).toUtc(),
    );
  }
}
