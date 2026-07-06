import 'support_ticket.dart';

class SupportTicketListResponse {
  const SupportTicketListResponse({
    required this.items,
    required this.total,
    required this.page,
    required this.perPage,
    required this.pages,
  });

  final List<SupportTicket> items;
  final int total;
  final int page;
  final int perPage;
  final int pages;

  factory SupportTicketListResponse.fromJson(Map<String, Object?> json) {
    final List<Object?> rawItems =
        (json['items'] as List<Object?>?) ?? const <Object?>[];
    return SupportTicketListResponse(
      items: rawItems
          .whereType<Map<Object?, Object?>>()
          .map(
            (Map<Object?, Object?> item) =>
                SupportTicket.fromSummaryJson(item.cast<String, Object?>()),
          )
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      perPage: (json['per_page'] as num?)?.toInt() ?? 20,
      pages: (json['pages'] as num?)?.toInt() ?? 1,
    );
  }
}
