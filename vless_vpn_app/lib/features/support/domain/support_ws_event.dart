class SupportWsEvent {
  const SupportWsEvent({required this.type, this.ticketId, this.message});

  final String type;
  final int? ticketId;
  final String? message;

  bool get affectsTickets =>
      type == 'ticket.admin_reply' ||
      type == 'ticket.new' ||
      type == 'ticket.user_reply';

  factory SupportWsEvent.fromJson(Map<String, Object?> json) {
    return SupportWsEvent(
      type: (json['type'] as String? ?? '').trim(),
      ticketId: (json['ticket_id'] as num?)?.toInt(),
      message: json['message'] as String?,
    );
  }
}
