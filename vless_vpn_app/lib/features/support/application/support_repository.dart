import '../../cabinet_api/domain/cabinet_session.dart';
import '../domain/support_ticket.dart';
import '../domain/support_ticket_list_response.dart';
import '../domain/support_ticket_message.dart';

abstract class SupportRepository {
  Future<SupportTicketListResponse> listTickets(
    CabinetSession session, {
    int page = 1,
    int perPage = 50,
    String? status,
  });

  Future<SupportTicket> getTicket(CabinetSession session, int ticketId);

  Future<SupportTicket> createTicket(
    CabinetSession session, {
    required String title,
    required String message,
  });

  Future<SupportTicketMessage> addMessage(
    CabinetSession session, {
    required int ticketId,
    required String message,
  });

  Future<SupportTicket> closeTicket(CabinetSession session, int ticketId);
}
