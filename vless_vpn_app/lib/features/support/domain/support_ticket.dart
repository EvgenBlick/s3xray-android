import 'support_ticket_message.dart';

class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.title,
    required this.status,
    required this.priority,
    required this.createdAt,
    required this.updatedAt,
    required this.closedAt,
    required this.messagesCount,
    required this.lastMessage,
    required this.isReplyBlocked,
    required this.messages,
  });

  final int id;
  final String title;
  final String status;
  final String priority;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? closedAt;
  final int messagesCount;
  final SupportTicketMessage? lastMessage;
  final bool isReplyBlocked;
  final List<SupportTicketMessage> messages;

  bool get isClosed => status.trim().toLowerCase() == 'closed';

  factory SupportTicket.fromSummaryJson(Map<String, Object?> json) {
    return SupportTicket(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: (json['title'] as String? ?? '').trim(),
      status: (json['status'] as String? ?? 'open').trim(),
      priority: (json['priority'] as String? ?? 'normal').trim(),
      createdAt: DateTime.parse(
        (json['created_at'] as String?) ??
            DateTime.now().toUtc().toIso8601String(),
      ).toUtc(),
      updatedAt: DateTime.parse(
        (json['updated_at'] as String?) ??
            DateTime.now().toUtc().toIso8601String(),
      ).toUtc(),
      closedAt: (json['closed_at'] as String?) == null
          ? null
          : DateTime.parse((json['closed_at'] as String)).toUtc(),
      messagesCount: (json['messages_count'] as num?)?.toInt() ?? 0,
      lastMessage: json['last_message'] is Map<Object?, Object?>
          ? SupportTicketMessage.fromJson(
              (json['last_message'] as Map<Object?, Object?>)
                  .cast<String, Object?>(),
            )
          : null,
      isReplyBlocked: false,
      messages: const <SupportTicketMessage>[],
    );
  }

  factory SupportTicket.fromDetailJson(Map<String, Object?> json) {
    final List<Object?> rawMessages =
        (json['messages'] as List<Object?>?) ?? const <Object?>[];
    final List<SupportTicketMessage> messages =
        rawMessages
            .whereType<Map<Object?, Object?>>()
            .map(
              (Map<Object?, Object?> item) =>
                  SupportTicketMessage.fromJson(item.cast<String, Object?>()),
            )
            .toList()
          ..sort(
            (SupportTicketMessage a, SupportTicketMessage b) =>
                a.createdAt.compareTo(b.createdAt),
          );

    return SupportTicket(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: (json['title'] as String? ?? '').trim(),
      status: (json['status'] as String? ?? 'open').trim(),
      priority: (json['priority'] as String? ?? 'normal').trim(),
      createdAt: DateTime.parse(
        (json['created_at'] as String?) ??
            DateTime.now().toUtc().toIso8601String(),
      ).toUtc(),
      updatedAt: DateTime.parse(
        (json['updated_at'] as String?) ??
            DateTime.now().toUtc().toIso8601String(),
      ).toUtc(),
      closedAt: (json['closed_at'] as String?) == null
          ? null
          : DateTime.parse((json['closed_at'] as String)).toUtc(),
      messagesCount: messages.length,
      lastMessage: messages.isEmpty ? null : messages.last,
      isReplyBlocked: json['is_reply_blocked'] as bool? ?? false,
      messages: messages,
    );
  }

  SupportTicket copyWith({
    String? status,
    DateTime? updatedAt,
    DateTime? closedAt,
    int? messagesCount,
    SupportTicketMessage? lastMessage,
    bool? isReplyBlocked,
    List<SupportTicketMessage>? messages,
  }) {
    return SupportTicket(
      id: id,
      title: title,
      status: status ?? this.status,
      priority: priority,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      closedAt: closedAt ?? this.closedAt,
      messagesCount: messagesCount ?? this.messagesCount,
      lastMessage: lastMessage ?? this.lastMessage,
      isReplyBlocked: isReplyBlocked ?? this.isReplyBlocked,
      messages: messages ?? this.messages,
    );
  }
}
