import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../cabinet_api/domain/cabinet_session.dart';
import '../domain/support_ticket.dart';
import '../domain/support_ticket_list_response.dart';
import '../domain/support_ticket_message.dart';
import '../domain/support_ws_event.dart';
import 'support_realtime_client.dart';
import 'support_repository.dart';

typedef SupportRealtimeClientFactory = SupportRealtimeClient Function();
typedef SupportReplyCallback = Future<void> Function(SupportTicket ticket);

class SupportController extends ChangeNotifier {
  SupportController({
    required SupportRepository repository,
    SupportRealtimeClientFactory? realtimeClientFactory,
    SupportReplyCallback? onSupportReply,
  }) : _repository = repository,
       _realtimeClientFactory =
           realtimeClientFactory ?? (() => SupportRealtimeClient()),
       _onSupportReply = onSupportReply;

  final SupportRepository _repository;
  final SupportRealtimeClientFactory _realtimeClientFactory;
  final SupportReplyCallback? _onSupportReply;

  SupportRealtimeClient? _realtimeClient;
  StreamSubscription<SupportWsEvent>? _realtimeSubscription;
  CabinetSession? _session;
  List<SupportTicket> _tickets = const <SupportTicket>[];
  SupportTicket? _selectedTicket;
  final Map<int, SupportTicket> _ticketCache = <int, SupportTicket>{};
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _listenedAccessToken;
  final Map<int, int> _lastSeenAdminReplyIds = <int, int>{};

  List<SupportTicket> get tickets => _tickets;
  SupportTicket? get selectedTicket => _selectedTicket;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  bool get hasSession => _session != null;

  Future<void> initialize(CabinetSession session) async {
    final bool sessionChanged =
        _session?.accessToken != session.accessToken ||
        _session?.expiresAt != session.expiresAt;
    _session = session;
    if (_tickets.isEmpty || sessionChanged) {
      await refresh(preserveSelection: true);
    }
    _ensureRealtime(session);
  }

  Future<void> refresh({bool preserveSelection = true}) async {
    final CabinetSession? session = _session;
    if (session == null) {
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final SupportTicketListResponse response = await _repository.listTickets(
        session,
      );
      _tickets = response.items;
      _seedSeenAdminReplies(_tickets);
      final int? selectedTicketId = preserveSelection
          ? _selectedTicket?.id
          : null;
      SupportTicket? matchedSummary;
      if (selectedTicketId != null) {
        for (final SupportTicket ticket in _tickets) {
          if (ticket.id == selectedTicketId) {
            matchedSummary = ticket;
            break;
          }
        }
      }
      if (matchedSummary != null) {
        _selectedTicket = await _repository.getTicket(
          session,
          matchedSummary.id,
        );
        _ticketCache[matchedSummary.id] = _selectedTicket!;
        _mergeSelectedTicketIntoList();
        _markSeenAdminReply(_selectedTicket);
      } else if (!preserveSelection) {
        _selectedTicket = null;
      }
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectTicket(int ticketId) async {
    final CabinetSession? session = _session;
    if (session == null) {
      return;
    }
    if (_selectedTicket?.id == ticketId &&
        _selectedTicket!.messages.isNotEmpty) {
      return;
    }

    final SupportTicket? cachedTicket = _ticketCache[ticketId];
    if (cachedTicket != null) {
      _selectedTicket = cachedTicket;
      _mergeSelectedTicketIntoList();
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _selectedTicket = await _repository.getTicket(session, ticketId);
      _ticketCache[ticketId] = _selectedTicket!;
      _mergeSelectedTicketIntoList();
      _markSeenAdminReply(_selectedTicket);
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createTicket({
    required String title,
    required String message,
  }) async {
    final CabinetSession? session = _session;
    if (session == null) {
      return;
    }
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final SupportTicket ticket = await _repository.createTicket(
        session,
        title: title,
        message: message,
      );
      _selectedTicket = ticket;
      _ticketCache[ticket.id] = ticket;
      _tickets = <SupportTicket>[
        ticket,
        ..._tickets.where((SupportTicket item) => item.id != ticket.id),
      ];
      _markSeenAdminReply(ticket);
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> sendMessage(String message) async {
    final CabinetSession? session = _session;
    final SupportTicket? selectedTicket = _selectedTicket;
    if (session == null || selectedTicket == null) {
      return;
    }

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final SupportTicketMessage sent = await _repository.addMessage(
        session,
        ticketId: selectedTicket.id,
        message: message,
      );
      final List<SupportTicketMessage> messages = <SupportTicketMessage>[
        ...selectedTicket.messages,
        sent,
      ];
      _selectedTicket = selectedTicket.copyWith(
        status: selectedTicket.status == 'answered'
            ? 'pending'
            : selectedTicket.status,
        updatedAt: sent.createdAt,
        messagesCount: messages.length,
        lastMessage: sent,
        messages: messages,
      );
      _ticketCache[selectedTicket.id] = _selectedTicket!;
      _mergeSelectedTicketIntoList();
      _markSeenAdminReply(_selectedTicket);
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> closeSelectedTicket() async {
    final CabinetSession? session = _session;
    final SupportTicket? selectedTicket = _selectedTicket;
    if (session == null || selectedTicket == null) {
      return;
    }

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _selectedTicket = await _repository.closeTicket(
        session,
        selectedTicket.id,
      );
      _ticketCache[selectedTicket.id] = _selectedTicket!;
      _mergeSelectedTicketIntoList();
      _markSeenAdminReply(_selectedTicket);
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  void clearSelectedTicket() {
    _selectedTicket = null;
    notifyListeners();
  }

  void reset() {
    _session = null;
    _tickets = const <SupportTicket>[];
    _selectedTicket = null;
    _errorMessage = null;
    _isLoading = false;
    _isSubmitting = false;
    _listenedAccessToken = null;
    _realtimeSubscription?.cancel();
    _realtimeSubscription = null;
    _realtimeClient?.dispose();
    _realtimeClient = null;
    _lastSeenAdminReplyIds.clear();
    _ticketCache.clear();
    notifyListeners();
  }

  void _ensureRealtime(CabinetSession session) {
    if (_listenedAccessToken == session.accessToken) {
      return;
    }
    _listenedAccessToken = session.accessToken;
    _realtimeSubscription?.cancel();
    _realtimeClient?.dispose();
    final SupportRealtimeClient realtimeClient = _realtimeClientFactory();
    _realtimeClient = realtimeClient;
    _realtimeSubscription = realtimeClient.connect(session.accessToken).listen((
      SupportWsEvent event,
    ) {
      if (!event.affectsTickets) {
        return;
      }
      unawaited(_handleRealtimeEvent(event));
    });
  }

  Future<void> _handleRealtimeEvent(SupportWsEvent event) async {
    final CabinetSession? session = _session;
    if (session == null) {
      return;
    }

    try {
      final SupportTicketListResponse response = await _repository.listTickets(
        session,
      );
      _tickets = response.items;
      _seedSeenAdminReplies(_tickets);
      final int? selectedTicketId = _selectedTicket?.id;
      if (selectedTicketId != null) {
        _selectedTicket = await _repository.getTicket(
          session,
          selectedTicketId,
        );
        _ticketCache[selectedTicketId] = _selectedTicket!;
        _mergeSelectedTicketIntoList();
        await _maybeNotifySupportReply(_selectedTicket);
      } else if (event.ticketId != null) {
        final SupportTicket eventTicket = await _repository.getTicket(
          session,
          event.ticketId!,
        );
        _ticketCache[event.ticketId!] = eventTicket;
        await _maybeNotifySupportReply(eventTicket, notifyIfUnknown: true);
      }
      notifyListeners();
    } catch (_) {
      return;
    }
  }

  void _mergeSelectedTicketIntoList() {
    final SupportTicket? selectedTicket = _selectedTicket;
    if (selectedTicket == null) {
      return;
    }
    final List<SupportTicket> next = <SupportTicket>[selectedTicket];
    for (final SupportTicket ticket in _tickets) {
      if (ticket.id != selectedTicket.id) {
        next.add(ticket);
      }
    }
    _tickets = next;
  }

  void _seedSeenAdminReplies(List<SupportTicket> tickets) {
    for (final SupportTicket ticket in tickets) {
      final SupportTicketMessage? lastMessage = ticket.lastMessage;
      if (lastMessage != null && lastMessage.isFromAdmin) {
        _lastSeenAdminReplyIds.putIfAbsent(ticket.id, () => lastMessage.id);
      }
    }
  }

  void _markSeenAdminReply(SupportTicket? ticket) {
    if (ticket == null) {
      return;
    }
    SupportTicketMessage? lastAdminMessage;
    for (final SupportTicketMessage message in ticket.messages) {
      if (message.isFromAdmin) {
        lastAdminMessage = message;
      }
    }
    if (lastAdminMessage != null) {
      _lastSeenAdminReplyIds[ticket.id] = lastAdminMessage.id;
    }
  }

  Future<void> _maybeNotifySupportReply(
    SupportTicket? ticket, {
    bool notifyIfUnknown = false,
  }) async {
    if (ticket == null || _onSupportReply == null) {
      return;
    }
    SupportTicketMessage? lastAdminMessage;
    for (final SupportTicketMessage message in ticket.messages) {
      if (message.isFromAdmin) {
        lastAdminMessage = message;
      }
    }
    if (lastAdminMessage == null) {
      return;
    }
    final int? previousSeenId = _lastSeenAdminReplyIds[ticket.id];
    _lastSeenAdminReplyIds[ticket.id] = lastAdminMessage.id;
    if (previousSeenId == lastAdminMessage.id) {
      return;
    }
    if (previousSeenId == null && !notifyIfUnknown) {
      return;
    }
    await _onSupportReply(ticket);
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    _realtimeClient?.dispose();
    super.dispose();
  }
}
