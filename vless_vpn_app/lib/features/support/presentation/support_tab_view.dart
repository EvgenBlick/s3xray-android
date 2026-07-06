import 'package:flutter/material.dart';

import '../../../l10n/app_strings.dart';
import '../../cabinet_api/domain/cabinet_session.dart';
import '../../navigation/presentation/tab_surface.dart';
import '../application/support_controller.dart';
import '../domain/support_ticket.dart';
import '../domain/support_ticket_message.dart';

class SupportTabView extends StatelessWidget {
  const SupportTabView({
    required this.strings,
    required this.session,
    required this.controller,
    required this.onLogin,
    super.key,
  });

  final AppStrings strings;
  final CabinetSession? session;
  final SupportController controller;
  final Future<void> Function() onLogin;

  @override
  Widget build(BuildContext context) {
    if (session == null) {
      return TabSurface(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _SectionTitle(strings.supportTitle),
            const SizedBox(height: 12),
            _BlockTitle(strings.supportNeedLoginTitle),
            const SizedBox(height: 8),
            _BodyText(strings.supportNeedLoginBody),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onLogin,
                icon: const Icon(Icons.login_rounded),
                label: Text(strings.authLoginAction),
              ),
            ),
          ],
        ),
      );
    }

    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, _) {
        return TabSurface(
          padding: const EdgeInsets.all(18),
          child: RefreshIndicator(
            color: const Color(0xFF2DD4BF),
            onRefresh: controller.refresh,
            child: ListView(
              padding: EdgeInsets.zero,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _SectionTitle(strings.supportTitle),
                          const SizedBox(height: 6),
                          _BodyText(strings.supportBody),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (controller.tickets.isNotEmpty)
                      FilledButton.icon(
                        onPressed:
                            controller.isSubmitting || controller.isLoading
                            ? null
                            : () => _showCreateTicketSheet(context),
                        icon: const Icon(Icons.add_comment_rounded),
                        label: Text(strings.supportCreateAction),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                if (controller.errorMessage?.trim().isNotEmpty ==
                    true) ...<Widget>[
                  _SupportErrorBanner(message: controller.errorMessage!.trim()),
                  const SizedBox(height: 12),
                ],
                if (controller.isLoading &&
                    controller.tickets.isEmpty) ...<Widget>[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: Column(
                        children: <Widget>[
                          const CircularProgressIndicator(
                            color: Color(0xFF2DD4BF),
                          ),
                          const SizedBox(height: 14),
                          _BodyText(
                            strings.supportLoadingMessage,
                            align: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else if (controller.tickets.isEmpty) ...<Widget>[
                  _SupportEmptyState(
                    strings: strings,
                    onCreate: controller.isSubmitting
                        ? null
                        : () => _showCreateTicketSheet(context),
                  ),
                ] else ...<Widget>[
                  _TicketListSection(
                    strings: strings,
                    tickets: controller.tickets,
                    selectedTicketId: controller.selectedTicket?.id,
                    onSelect: controller.selectTicket,
                  ),
                  const SizedBox(height: 16),
                  if (controller.selectedTicket != null)
                    _TicketThreadSection(
                      strings: strings,
                      ticket: controller.selectedTicket!,
                      isSubmitting: controller.isSubmitting,
                      onSend: controller.sendMessage,
                      onClose: controller.closeSelectedTicket,
                      onHide: controller.clearSelectedTicket,
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showCreateTicketSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) =>
          _CreateTicketSheet(strings: strings, controller: controller),
    );
  }
}

class _TicketListSection extends StatelessWidget {
  const _TicketListSection({
    required this.strings,
    required this.tickets,
    required this.selectedTicketId,
    required this.onSelect,
  });

  final AppStrings strings;
  final List<SupportTicket> tickets;
  final int? selectedTicketId;
  final Future<void> Function(int ticketId) onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _BlockTitle(strings.supportOpenTicketTitle),
        const SizedBox(height: 12),
        ...tickets.map((SupportTicket ticket) {
          final bool selected = ticket.id == selectedTicketId;
          final String lastLine =
              ticket.lastMessage?.messageText.trim().isNotEmpty == true
              ? ticket.lastMessage!.messageText.trim()
              : ticket.title;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () => onSelect(ticket.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  color: selected
                      ? const Color(0x1A2DD4BF)
                      : Colors.white.withValues(alpha: 0.03),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFF2DD4BF)
                        : Colors.white.withValues(alpha: 0.08),
                    width: selected ? 1.8 : 1,
                  ),
                  boxShadow: selected
                      ? const <BoxShadow>[
                          BoxShadow(color: Color(0x222DD4BF), blurRadius: 18),
                        ]
                      : const <BoxShadow>[],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            ticket.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusPill(
                          label: strings.supportStatusLabel(ticket.status),
                          isClosed: ticket.isClosed,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      lastLine,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFFCBD5E1),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _formatDate(ticket.updatedAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _TicketThreadSection extends StatefulWidget {
  const _TicketThreadSection({
    required this.strings,
    required this.ticket,
    required this.isSubmitting,
    required this.onSend,
    required this.onClose,
    required this.onHide,
  });

  final AppStrings strings;
  final SupportTicket ticket;
  final bool isSubmitting;
  final Future<void> Function(String message) onSend;
  final Future<void> Function() onClose;
  final VoidCallback onHide;

  @override
  State<_TicketThreadSection> createState() => _TicketThreadSectionState();
}

class _TicketThreadSectionState extends State<_TicketThreadSection> {
  final TextEditingController _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool canReply =
        !widget.ticket.isClosed && !widget.ticket.isReplyBlocked;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white.withValues(alpha: 0.03),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _BlockTitle(widget.strings.supportThreadTitle),
              const SizedBox(height: 4),
              Text(
                widget.ticket.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  TextButton.icon(
                    onPressed: widget.onHide,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    label: Text(widget.strings.supportHideThreadAction),
                  ),
                  if (!widget.ticket.isClosed)
                    TextButton.icon(
                      onPressed: widget.isSubmitting ? null : widget.onClose,
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      label: Text(widget.strings.supportCloseAction),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...widget.ticket.messages.map(
            (SupportTicketMessage message) =>
                _MessageBubble(strings: widget.strings, message: message),
          ),
          const SizedBox(height: 14),
          if (!canReply)
            _SupportHintBanner(
              text: widget.ticket.isClosed
                  ? widget.strings.supportClosedTicketLabel
                  : widget.strings.supportBlockedReplyLabel,
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    minLines: 1,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: widget.strings.supportComposerHint,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: widget.isSubmitting ? null : _submit,
                  child: Text(widget.strings.supportSendAction),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final String message = _messageController.text.trim();
    if (message.isEmpty) {
      return;
    }
    await widget.onSend(message);
    _messageController.clear();
  }
}

class _CreateTicketSheet extends StatefulWidget {
  const _CreateTicketSheet({required this.strings, required this.controller});

  final AppStrings strings;
  final SupportController controller;

  @override
  State<_CreateTicketSheet> createState() => _CreateTicketSheetState();
}

class _CreateTicketSheetState extends State<_CreateTicketSheet> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final EdgeInsets viewInsets = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, viewInsets.bottom + 16),
      child: Material(
        color: const Color(0xFF0B1220),
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                widget.strings.supportCreateSheetTitle,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _titleController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: widget.strings.supportTicketTitleLabel,
                  hintText: widget.strings.supportTicketTitleHint,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _messageController,
                minLines: 4,
                maxLines: 8,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: widget.strings.supportTicketMessageLabel,
                  hintText: widget.strings.supportTicketMessageHint,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submit,
                  child: Text(widget.strings.supportCreateSubmitAction),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final String title = _titleController.text.trim();
    final String message = _messageController.text.trim();
    if (title.length < 3) {
      _showValidation(widget.strings.supportValidationTitle);
      return;
    }
    if (message.length < 10) {
      _showValidation(widget.strings.supportValidationMessage);
      return;
    }
    await widget.controller.createTicket(title: title, message: message);
    if (!mounted) {
      return;
    }
    if (widget.controller.errorMessage?.trim().isNotEmpty == true) {
      return;
    }
    Navigator.of(context).pop();
  }

  void _showValidation(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.strings, required this.message});

  final AppStrings strings;
  final SupportTicketMessage message;

  @override
  Widget build(BuildContext context) {
    final bool fromAdmin = message.isFromAdmin;
    return Align(
      alignment: fromAdmin ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: fromAdmin
              ? Colors.white.withValues(alpha: 0.06)
              : const Color(0x332DD4BF),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: fromAdmin
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0x442DD4BF),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              fromAdmin
                  ? strings.supportReplyFromSupport
                  : strings.supportReplyFromYou,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: fromAdmin
                    ? const Color(0xFFCBD5E1)
                    : const Color(0xFF5EEAD4),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message.messageText,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _formatDate(message.createdAt),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportEmptyState extends StatelessWidget {
  const _SupportEmptyState({required this.strings, required this.onCreate});

  final AppStrings strings;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white.withValues(alpha: 0.03),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: <Widget>[
          const Icon(
            Icons.mark_chat_read_rounded,
            color: Color(0xFF5EEAD4),
            size: 34,
          ),
          const SizedBox(height: 12),
          _BlockTitle(strings.supportEmptyTitle, align: TextAlign.center),
          const SizedBox(height: 8),
          _BodyText(strings.supportEmptyBody, align: TextAlign.center),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_comment_rounded),
            label: Text(strings.supportCreateAction),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _BlockTitle extends StatelessWidget {
  const _BlockTitle(this.text, {this.align});

  final String text;
  final TextAlign? align;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: align,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _BodyText extends StatelessWidget {
  const _BodyText(this.text, {this.align});

  final String text;
  final TextAlign? align;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: align,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: const Color(0xFFCBD5E1),
        height: 1.4,
      ),
    );
  }
}

class _SupportErrorBanner extends StatelessWidget {
  const _SupportErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0x26DC2626),
        border: Border.all(color: const Color(0x55DC2626)),
      ),
      child: Text(
        message,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: const Color(0xFFFECACA)),
      ),
    );
  }
}

class _SupportHintBanner extends StatelessWidget {
  const _SupportHintBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: const Color(0xFFCBD5E1)),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.isClosed});

  final String label;
  final bool isClosed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: isClosed ? const Color(0x1FF87171) : const Color(0x1F2DD4BF),
        border: Border.all(
          color: isClosed ? const Color(0x44F87171) : const Color(0x442DD4BF),
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: isClosed ? const Color(0xFFFECACA) : const Color(0xFF99F6E4),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _formatDate(DateTime dateTime) {
  final DateTime local = dateTime.toLocal();
  final String day = local.day.toString().padLeft(2, '0');
  final String month = local.month.toString().padLeft(2, '0');
  final String hour = local.hour.toString().padLeft(2, '0');
  final String minute = local.minute.toString().padLeft(2, '0');
  return '$day.$month • $hour:$minute';
}
