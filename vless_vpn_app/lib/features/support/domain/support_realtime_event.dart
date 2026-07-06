class SupportRealtimeEvent {
  const SupportRealtimeEvent({required this.type, this.ticketId, this.message});

  final String type;
  final int? ticketId;
  final String? message;
}
