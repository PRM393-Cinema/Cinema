import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/session/session_state.dart';
import '../../../core/widgets/cinema_account_widgets.dart';
import '../../../data/services/chat_service.dart';
import '../../../data/storage/chat_history_storage.dart';
import '../../../core/utils/formatters.dart';

class ChatPanel extends StatefulWidget {
  const ChatPanel({
    required this.service,
    required this.onClose,
    required this.onReviewBooking,
    this.userId,
    super.key,
  });

  final ChatService service;
  final VoidCallback onClose;
  final Future<bool> Function(ChatBookingProposal) onReviewBooking;
  final int? userId;

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <ChatMessage>[];
  bool _sending = false;
  String? _error;
  ChatBookingProposal? _proposal;
  bool _reviewing = false;
  late final _historyStorage = ChatHistoryStorage(userId: widget.userId);
  final _chats = <SavedChat>[];
  String? _activeId;
  bool _loadingHistory = true;
  bool _showHistory = false;
  String? _historyError;
  bool _canSaveHistory = true;
  String? _deletingId;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final history = await _historyStorage.read();
      if (!mounted) return;
      setState(() {
        _chats.addAll(history.chats);
        _activeId = history.activeId;
        for (final chat in _chats) {
          if (chat.id == _activeId) _messages.addAll(chat.messages);
        }
      });
      _scrollToLatest();
    } on Object {
      _canSaveHistory = false;
      if (mounted) {
        setState(
          () => _historyError =
              'Unable to load saved chats. New messages will stay in memory.',
        );
      }
    } finally {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  Future<void> _saveHistory() async {
    // Preserve unreadable existing history rather than overwriting it after a storage failure.
    if (!_canSaveHistory) return;
    try {
      await _historyStorage.save(
        ChatHistory(activeId: _activeId, chats: List.of(_chats)),
      );
      if (mounted && _historyError != null) {
        setState(() => _historyError = null);
      }
    } on Object {
      if (mounted) {
        setState(
          () => _historyError = 'Unable to save chat history on this device.',
        );
      }
    }
  }

  void _rememberChat() {
    final now = DateTime.now();
    _activeId ??= now.microsecondsSinceEpoch.toString();
    _chats.removeWhere((chat) => chat.id == _activeId);
    _chats.insert(
      0,
      SavedChat(id: _activeId!, updatedAt: now, messages: List.of(_messages)),
    );
    // shortcut: keep 20 chats with 60 messages each on this device; use server history for cross-device sync.
    if (_chats.length > 20) _chats.removeRange(20, _chats.length);
    _saveHistory();
  }

  void _newChat() {
    setState(() {
      _messages.clear();
      _activeId = null;
      _error = null;
      _input.clear();
      _proposal = null;
      _showHistory = false;
    });
    _saveHistory();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> _send(String text) async {
    final content = text.trim();
    if (_loadingHistory ||
        _sending ||
        _reviewing ||
        content.isEmpty ||
        content.length > 1000) {
      return;
    }
    setState(() {
      if (_error != null) _messages.removeLast();
      if (_messages.length >= 60) _messages.removeRange(0, 2);
      _messages.add(ChatMessage(role: 'user', content: content));
      _input.clear();
      _proposal = null;
    });
    await _request();
  }

  void _sendOnEnter() {
    // Enter must still confirm an active IME composition before sending.
    final composing = _input.value.composing;
    if (composing.isValid && !composing.isCollapsed) return;
    _send(_input.text);
  }

  void _insertNewline() {
    if (_sending) return;
    final value = _input.value;
    if (value.composing.isValid && !value.composing.isCollapsed) return;
    final selection = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: value.text.length);
    final next = value.replaced(selection, '\n');
    if (next.text.length <= 1000) {
      _input.value = next.copyWith(
        selection: TextSelection.collapsed(offset: selection.start + 1),
      );
    }
  }

  Future<void> _request() async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    _scrollToLatest();
    // Keep complete turns within the backend's message and character limits.
    final context = List<ChatMessage>.of(_messages);
    while (context.length > 11 ||
        context.fold<int>(0, (sum, message) => sum + message.content.length) >
            12000) {
      context.removeRange(0, 2);
    }
    try {
      final reply = await widget.service.replyWithActions(
        context,
        authenticated: SessionProvider.of(this.context).isAuthenticated,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(role: 'assistant', content: reply.message));
        _proposal = reply.booking;
        _rememberChat();
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on Object {
      if (mounted) {
        setState(() => _error = 'Unable to reach Cinema AI. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _scrollToLatest();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return CinemaPanel(
      key: const Key('cinemaChatPanel'),
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: colors.primary,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.sm),
                const Expanded(
                  child: Text('Cinema AI', style: AppTextStyles.title),
                ),
                IconButton(
                  key: const Key('cinemaChatHistory'),
                  tooltip: _showHistory ? 'Back to chat' : 'Chat history',
                  onPressed: _loadingHistory || _sending || _reviewing
                      ? null
                      : () => setState(() => _showHistory = !_showHistory),
                  icon: Icon(
                    _showHistory
                        ? Icons.arrow_back_rounded
                        : Icons.history_rounded,
                    size: 20,
                  ),
                ),
                IconButton(
                  key: const Key('newCinemaChat'),
                  tooltip: 'New chat',
                  onPressed:
                      _loadingHistory ||
                          _sending ||
                          _reviewing ||
                          (_messages.isEmpty && !_showHistory)
                      ? null
                      : _newChat,
                  icon: const Icon(Icons.add_comment_outlined, size: 20),
                ),
                IconButton(
                  key: const Key('closeCinemaChat'),
                  tooltip: 'Minimize chat',
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.border),
          if (_historyError != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                _historyError!,
                style: AppTextStyles.caption.copyWith(color: colors.error),
              ),
            ),
          Expanded(
            child: _loadingHistory
                ? const Center(child: CircularProgressIndicator())
                : _showHistory
                ? _historyList(context)
                : ListView(
                    key: const Key('cinemaChatMessages'),
                    controller: _scroll,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    children: [
                      if (_messages.isEmpty) _welcome(context),
                      for (var index = 0; index < _messages.length; index++)
                        _MessageBubble(message: _messages[index], index: index),
                      if (_proposal != null)
                        OutlinedButton.icon(
                          key: const Key('reviewChatBooking'),
                          onPressed: _reviewing || _sending
                              ? null
                              : () async {
                                  setState(() => _reviewing = true);
                                  try {
                                    final consumed = await widget
                                        .onReviewBooking(_proposal!);
                                    if (mounted && consumed) {
                                      setState(() => _proposal = null);
                                    }
                                  } finally {
                                    if (mounted) {
                                      setState(() => _reviewing = false);
                                    }
                                  }
                                },
                          icon: const Icon(Icons.confirmation_number_outlined),
                          label: Text(
                            _reviewing ? 'Checking seats…' : 'Review booking',
                          ),
                        ),
                      if (_sending)
                        Semantics(
                          liveRegion: true,
                          child: Row(
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Text(
                                  'Cinema AI is thinking…',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_error != null)
                        Semantics(
                          liveRegion: true,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _error!,
                                key: const Key('cinemaChatError'),
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: colors.error,
                                ),
                              ),
                              TextButton.icon(
                                key: const Key('retryCinemaChat'),
                                onPressed: _sending ? null : _request,
                                icon: const Icon(
                                  Icons.refresh_rounded,
                                  size: 18,
                                ),
                                label: const Text('Try again'),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
          Divider(height: 1, color: colors.border),
          if (!_showHistory)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CallbackShortcuts(
                    bindings: {
                      const SingleActivator(LogicalKeyboardKey.enter):
                          _sendOnEnter,
                      const SingleActivator(LogicalKeyboardKey.numpadEnter):
                          _sendOnEnter,
                      const SingleActivator(
                        LogicalKeyboardKey.enter,
                        shift: true,
                      ): _insertNewline,
                      const SingleActivator(
                        LogicalKeyboardKey.numpadEnter,
                        shift: true,
                      ): _insertNewline,
                    },
                    child: TextField(
                      key: const Key('cinemaChatInput'),
                      controller: _input,
                      enabled: !_loadingHistory && !_sending && !_reviewing,
                      minLines: 1,
                      maxLines: 3,
                      maxLength: 1000,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _send,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: 'Ask Cinema AI',
                        hintText: 'Find a movie or ask about booking…',
                        suffixIcon: ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _input,
                          builder: (context, value, _) => IconButton(
                            key: const Key('sendCinemaChat'),
                            tooltip: 'Send message',
                            onPressed:
                                _loadingHistory ||
                                    _sending ||
                                    _reviewing ||
                                    value.text.trim().isEmpty ||
                                    value.text.trim().length > 1000
                                ? null
                                : () => _send(value.text),
                            icon: const Icon(Icons.arrow_upward_rounded),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'AI may make mistakes. Requested account facts and chats go via OpenRouter to the model provider. Never share passwords or card details.',
                    style: AppTextStyles.caption.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _historyList(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Chat history', style: AppTextStyles.title),
            const SizedBox(height: 4),
            Text(
              'Saved on this device · ${_chats.length}/20 chats',
              style: AppTextStyles.caption,
            ),
          ],
        ),
      ),
      Expanded(
        child: _chats.isEmpty
            ? const Center(child: Text('No saved chats yet.'))
            : ListView.builder(
                itemCount: _chats.length,
                itemBuilder: (context, index) {
                  final chat = _chats[index];
                  return ListTile(
                    selected: chat.id == _activeId,
                    title: Text(
                      chat.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      formatDateTime(chat.updatedAt),
                      style: AppTextStyles.caption,
                    ),
                    onTap: () {
                      setState(() {
                        _messages
                          ..clear()
                          ..addAll(chat.messages);
                        _activeId = chat.id;
                        _proposal = null;
                        _error = null;
                        _input.clear();
                        _showHistory = false;
                      });
                      _saveHistory();
                      _scrollToLatest();
                    },
                    trailing: _deletingId != chat.id
                        ? IconButton(
                            tooltip: 'Delete chat',
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 20,
                            ),
                            onPressed: () =>
                                setState(() => _deletingId = chat.id),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Cancel deletion',
                                icon: const Icon(Icons.close_rounded, size: 20),
                                onPressed: () =>
                                    setState(() => _deletingId = null),
                              ),
                              IconButton(
                                tooltip: 'Confirm delete chat',
                                icon: Icon(
                                  Icons.check_rounded,
                                  size: 20,
                                  color: AppPalette.of(context).error,
                                ),
                                onPressed: () async {
                                  setState(() {
                                    _deletingId = null;
                                    _chats.removeWhere(
                                      (entry) => entry.id == chat.id,
                                    );
                                    if (_activeId == chat.id) {
                                      _activeId = null;
                                      _messages.clear();
                                      _proposal = null;
                                      _error = null;
                                    }
                                  });
                                  await _saveHistory();
                                },
                              ),
                            ],
                          ),
                  );
                },
              ),
      ),
    ],
  );

  Widget _welcome(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.chat_bubble_outline_rounded,
          size: 28,
          color: AppPalette.of(context).primary,
        ),
        const SizedBox(height: AppSpacing.lg),
        const Text(
          'What would you like to watch?',
          style: AppTextStyles.heading2,
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'Find movies and seats, review a ticket proposal, or ask about your membership, bookings and spending after signing in. You confirm every booking and complete payment yourself.',
          style: AppTextStyles.bodySmall,
        ),
        const SizedBox(height: AppSpacing.xl),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final prompt in const [
              'Gợi ý phim đang chiếu',
              'Có lịch chiếu nào sắp tới?',
              'Hạng thành viên và điểm của tôi',
              'Hóa đơn đã thanh toán cao nhất của tôi',
            ])
              OutlinedButton(
                onPressed: _loadingHistory || _sending
                    ? null
                    : () => _send(prompt),
                child: Text(prompt),
              ),
          ],
        ),
      ],
    ),
  );
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.index});

  final ChatMessage message;
  final int index;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final user = message.role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Align(
        alignment: user ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 640),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: user
                ? colors.primary.withValues(alpha: 0.08)
                : colors.surfaceSoft,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                user ? 'You' : 'Cinema AI',
                style: AppTextStyles.caption.copyWith(
                  color: user ? colors.primary : colors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SelectableText(
                message.content,
                semanticsLabel: message.content,
                key: ValueKey('chatMessage-$index'),
                style: AppTextStyles.bodySmall.copyWith(
                  color: colors.textPrimary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
