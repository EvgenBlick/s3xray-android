import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vless_vpn_app/features/cabinet_api/domain/cabinet_session.dart';
import 'package:vless_vpn_app/features/support/application/support_controller.dart';
import 'package:vless_vpn_app/features/support/application/support_realtime_client.dart';
import 'package:vless_vpn_app/features/support/application/support_repository.dart';
import 'package:vless_vpn_app/features/support/domain/support_ticket.dart';
import 'package:vless_vpn_app/features/support/domain/support_ticket_list_response.dart';
import 'package:vless_vpn_app/features/support/domain/support_ticket_message.dart';
import 'package:vless_vpn_app/features/support/domain/support_ws_event.dart';

void main() {
  final CabinetSession session = CabinetSession(
    accessToken: 'access',
    refreshToken: 'refresh',
    tokenType: 'bearer',
    expiresAt: DateTime.utc(2030, 1, 1),
  );

  test('loads tickets and selected detail on initialize', () async {
    final _FakeSupportRepository repository = _FakeSupportRepository();
    final SupportController controller = SupportController(
      repository: repository,
      realtimeClientFactory: _FakeRealtimeClient.new,
    );
    addTearDown(controller.dispose);

    await controller.initialize(session);

    expect(controller.tickets, hasLength(2));
    expect(controller.selectedTicket, isNull);
    await controller.selectTicket(101);
    expect(controller.selectedTicket?.id, 101);
    expect(controller.selectedTicket?.messages, isNotEmpty);
  });

  test('notifies when support replies even if dialog is hidden', () async {
    final _FakeSupportRepository repository = _FakeSupportRepository();
    final _FakeRealtimeClient realtimeClient = _FakeRealtimeClient();
    final List<int> notifiedTickets = <int>[];
    final SupportController controller = SupportController(
      repository: repository,
      realtimeClientFactory: () => realtimeClient,
      onSupportReply: (SupportTicket ticket) async {
        notifiedTickets.add(ticket.id);
      },
    );
    addTearDown(controller.dispose);

    await controller.initialize(session);
    controller.clearSelectedTicket();

    repository.injectAdminReply(
      101,
      SupportTicketMessage(
        id: 5,
        messageText: 'Есть новый ответ',
        isFromAdmin: true,
        hasMedia: false,
        mediaType: null,
        mediaFileId: null,
        mediaCaption: null,
        createdAt: DateTime.utc(2026, 4, 12, 12, 45),
      ),
    );
    realtimeClient.emit(
      const SupportWsEvent(type: 'ticket.admin_reply', ticketId: 101),
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(notifiedTickets, <int>[101]);
    expect(controller.selectedTicket, isNull);
  });

  test('refreshes ticket thread after websocket admin reply event', () async {
    final _FakeSupportRepository repository = _FakeSupportRepository();
    final _FakeRealtimeClient realtimeClient = _FakeRealtimeClient();
    final SupportController controller = SupportController(
      repository: repository,
      realtimeClientFactory: () => realtimeClient,
    );
    addTearDown(controller.dispose);

    await controller.initialize(session);
    await controller.selectTicket(101);
    repository.injectAdminReply(
      101,
      SupportTicketMessage(
        id: 3,
        messageText: 'Поддержка уже отвечает',
        isFromAdmin: true,
        hasMedia: false,
        mediaType: null,
        mediaFileId: null,
        mediaCaption: null,
        createdAt: DateTime.utc(2026, 4, 12, 12, 30),
      ),
    );
    realtimeClient.emit(
      const SupportWsEvent(type: 'ticket.admin_reply', ticketId: 101),
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(
      controller.selectedTicket?.messages.last.messageText,
      'Поддержка уже отвечает',
    );
    expect(
      controller.tickets.first.lastMessage?.messageText,
      'Поддержка уже отвечает',
    );
  });
}

class _FakeSupportRepository implements SupportRepository {
  final Map<int, SupportTicket> _details = <int, SupportTicket>{
    101: _ticket(
      id: 101,
      title: 'Проблема с оплатой',
      status: 'open',
      messages: <SupportTicketMessage>[
        SupportTicketMessage(
          id: 1,
          messageText: 'Не проходит оплата',
          isFromAdmin: false,
          hasMedia: false,
          mediaType: null,
          mediaFileId: null,
          mediaCaption: null,
          createdAt: DateTime.utc(2026, 4, 12, 12, 0),
        ),
        SupportTicketMessage(
          id: 2,
          messageText: 'Проверяем ваш запрос',
          isFromAdmin: true,
          hasMedia: false,
          mediaType: null,
          mediaFileId: null,
          mediaCaption: null,
          createdAt: DateTime.utc(2026, 4, 12, 12, 5),
        ),
      ],
    ),
    102: _ticket(
      id: 102,
      title: 'Проблема с профилем',
      status: 'closed',
      messages: <SupportTicketMessage>[
        SupportTicketMessage(
          id: 4,
          messageText: 'Профиль не открывается',
          isFromAdmin: false,
          hasMedia: false,
          mediaType: null,
          mediaFileId: null,
          mediaCaption: null,
          createdAt: DateTime.utc(2026, 4, 11, 18, 0),
        ),
      ],
    ),
  };

  @override
  Future<SupportTicketMessage> addMessage(
    CabinetSession session, {
    required int ticketId,
    required String message,
  }) async {
    final SupportTicket current = _details[ticketId]!;
    final SupportTicketMessage nextMessage = SupportTicketMessage(
      id: current.messages.length + 10,
      messageText: message,
      isFromAdmin: false,
      hasMedia: false,
      mediaType: null,
      mediaFileId: null,
      mediaCaption: null,
      createdAt: DateTime.utc(2026, 4, 12, 13, 0),
    );
    _details[ticketId] = current.copyWith(
      messages: <SupportTicketMessage>[...current.messages, nextMessage],
      messagesCount: current.messages.length + 1,
      lastMessage: nextMessage,
      updatedAt: nextMessage.createdAt,
    );
    return nextMessage;
  }

  @override
  Future<SupportTicket> closeTicket(
    CabinetSession session,
    int ticketId,
  ) async {
    final SupportTicket current = _details[ticketId]!;
    final SupportTicket updated = current.copyWith(
      status: 'closed',
      closedAt: DateTime.utc(2026, 4, 12, 13, 5),
    );
    _details[ticketId] = updated;
    return updated;
  }

  @override
  Future<SupportTicket> createTicket(
    CabinetSession session, {
    required String title,
    required String message,
  }) async {
    final SupportTicket ticket = _ticket(
      id: 103,
      title: title,
      status: 'open',
      messages: <SupportTicketMessage>[
        SupportTicketMessage(
          id: 20,
          messageText: message,
          isFromAdmin: false,
          hasMedia: false,
          mediaType: null,
          mediaFileId: null,
          mediaCaption: null,
          createdAt: DateTime.utc(2026, 4, 12, 14, 0),
        ),
      ],
    );
    _details[103] = ticket;
    return ticket;
  }

  @override
  Future<SupportTicket> getTicket(CabinetSession session, int ticketId) async =>
      _details[ticketId]!;

  @override
  Future<SupportTicketListResponse> listTickets(
    CabinetSession session, {
    int page = 1,
    int perPage = 50,
    String? status,
  }) async {
    final List<SupportTicket> tickets =
        _details.values
            .map(
              (SupportTicket ticket) =>
                  ticket.copyWith(messages: const <SupportTicketMessage>[]),
            )
            .toList()
          ..sort(
            (SupportTicket a, SupportTicket b) =>
                b.updatedAt.compareTo(a.updatedAt),
          );
    return SupportTicketListResponse(
      items: tickets,
      total: tickets.length,
      page: page,
      perPage: perPage,
      pages: 1,
    );
  }

  void injectAdminReply(int ticketId, SupportTicketMessage message) {
    final SupportTicket current = _details[ticketId]!;
    _details[ticketId] = current.copyWith(
      messages: <SupportTicketMessage>[...current.messages, message],
      messagesCount: current.messages.length + 1,
      lastMessage: message,
      updatedAt: message.createdAt,
      status: 'answered',
    );
  }

  static SupportTicket _ticket({
    required int id,
    required String title,
    required String status,
    required List<SupportTicketMessage> messages,
  }) {
    final SupportTicketMessage? last = messages.isEmpty ? null : messages.last;
    return SupportTicket(
      id: id,
      title: title,
      status: status,
      priority: 'normal',
      createdAt: messages.first.createdAt,
      updatedAt: messages.last.createdAt,
      closedAt: status == 'closed' ? messages.last.createdAt : null,
      messagesCount: messages.length,
      lastMessage: last,
      isReplyBlocked: false,
      messages: messages,
    );
  }
}

class _FakeRealtimeClient extends SupportRealtimeClient {
  _FakeRealtimeClient() : super(baseUri: Uri.parse('https://api.pedzeo.ru'));

  final StreamController<SupportWsEvent> _controller =
      StreamController<SupportWsEvent>.broadcast();

  @override
  Stream<SupportWsEvent> connect(String accessToken) => _controller.stream;

  void emit(SupportWsEvent event) {
    _controller.add(event);
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }
}
