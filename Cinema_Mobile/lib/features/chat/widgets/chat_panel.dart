import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/session/session_state.dart';
import '../../../core/widgets/cinema_account_widgets.dart';
import '../../../data/models/concession.dart';
import '../../../data/models/seat.dart';
import '../../../data/repositories/booking_repository.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../data/services/chat_service.dart';
import '../../../data/storage/chat_history_storage.dart';
import '../../../core/utils/formatters.dart';
import 'chat_answer.dart';
import 'chat_booking_form.dart';
import 'chat_recommendation_card.dart';
import 'chat_seat_booking.dart';
import 'chat_seat_preview.dart';

class ChatPanel extends StatefulWidget {
  const ChatPanel({
    required this.service,
    required this.onClose,
    required this.onSignIn,
    required this.showSeatPicker,
    required this.onOpenLink,
    required this.catalogRepository,
    required this.bookingRepository,
    this.userId,
    this.initialSelection,
    super.key,
  });

  final ChatService service;
  final VoidCallback onClose;
  final ValueChanged<ChatSeatSelection> onSignIn;
  final Future<List<Seat>?> Function(WidgetBuilder) showSeatPicker;
  final ValueChanged<String> onOpenLink;
  final CatalogRepository catalogRepository;
  final BookingRepository bookingRepository;
  final int? userId;
  final ChatSeatSelection? initialSelection;

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final _input = TextEditingController();
  final _inputFocus = FocusNode();
  final _scroll = ScrollController();
  final _messages = <ChatMessage>[];
  final _recommendations = <String, Future<ChatRecommendation?>>{};
  final _seatPreviews = <String, Future<ChatSeatPreviewData>>{};
  Future<List<ConcessionItem>>? _menu;
  bool _sending = false;
  String? _error;
  ChatBookingProposal? _proposal;
  ChatBookingForm? _bookingForm;
  Map<String, int> _showtimeTickets = const {};
  late ChatSeatSelection? _seatSelection = widget.initialSelection;
  int? _bookingAfter;
  ({int after, String text})? _bookingNotice;
  bool get _reviewing => _seatSelection != null;
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

  @override
  void didUpdateWidget(covariant ChatPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selection = widget.initialSelection;
    if (selection != null && selection != oldWidget.initialSelection) {
      _seatSelection = selection;
      _bookingAfter = null;
      _bookingNotice = null;
      _scrollToLatest();
    }
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
      _recommendations.clear();
      _seatPreviews.clear();
      _menu = null;
      _activeId = null;
      _error = null;
      _input.clear();
      _proposal = null;
      _bookingForm = null;
      _showtimeTickets = const {};
      _showHistory = false;
    });
    _saveHistory();
  }

  Future<ChatRecommendation?> _loadRecommendation(String route) async {
    final id = int.parse(route.substring(route.lastIndexOf('/') + 1));
    try {
      if (route.startsWith('/movies/')) {
        final movie = await widget.catalogRepository.getMovie(id);
        return (
          title: movie.title,
          imageUrl: movie.posterUrl,
          price: '',
          description: movie.genre,
        );
      }
      final menu = await (_menu ??= widget.bookingRepository.getConcessions());
      final item = menu
          .where((item) => item.id == id && item.active)
          .firstOrNull;
      if (item == null) return null;
      return (
        title: item.name,
        imageUrl: item.imageUrl,
        price: formatVnd(item.price),
        description: item.description,
      );
    } on Object {
      return null; // The inline link still works if the preview cannot load.
    }
  }

  Future<ChatSeatPreviewData> _loadSeatPreview(String route) async {
    final catalog = widget.catalogRepository;
    final showtime = await catalog.getShowtime(int.parse(route.split('/')[2]));
    return (showtime: showtime, map: await catalog.getSeatMap(showtime));
  }

  Widget _recommendation(String route) {
    if (route.startsWith('/showtimes/')) {
      return ChatSeatPreview(
        key: ValueKey(route),
        details: widget.userId == null
            ? null
            : _seatPreviews.putIfAbsent(route, () => _loadSeatPreview(route)),
        onOpen: () => _openLink(route),
      );
    }
    return ChatRecommendationCard(
      key: ValueKey(route),
      details: _recommendations.putIfAbsent(
        route,
        () => _loadRecommendation(route),
      ),
      movie: route.startsWith('/movies/'),
      onOpen: () => widget.onOpenLink(
        route.startsWith('/movies/') ? '$route?section=showtimes' : route,
      ),
    );
  }

  @override
  void dispose() {
    _input.dispose();
    _inputFocus.dispose();
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

  void _chooseSeats(ChatSeatSelection selection) {
    if (_sending || _reviewing) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _seatSelection = selection;
      _bookingAfter = _messages.length;
      _bookingNotice = null;
      _proposal = null;
      _bookingForm = null;
    });
    _scrollToLatest();
  }

  void _openLink(String route) {
    if (_sending) return;
    final seatRoute = RegExp(r'^/showtimes/([1-9][0-9]{0,15})/seats$')
        .firstMatch(route);
    if (seatRoute == null) {
      widget.onOpenLink(route);
      return;
    }
    _chooseSeats((
      showtimeId: int.parse(seatRoute[1]!),
      tickets: _showtimeTickets[route] ?? 1,
      proposal: null,
    ));
  }

  Future<void> _send(String text) async {
    final content = text.trim();
    if (_loadingHistory ||
        _sending ||
        content.isEmpty ||
        content.length > 1000) {
      return;
    }
    setState(() {
      if (_error != null) _messages.removeLast();
      final removed = _messages.length >= 60 ? 2 : 0;
      int keptIndex(int index) =>
          math.max(0, math.min(index, _messages.length) - removed);
      if (_reviewing) {
        _bookingAfter = keptIndex(_bookingAfter ?? _messages.length);
      }
      if (_bookingNotice case final notice?) {
        _bookingNotice = (after: keptIndex(notice.after), text: notice.text);
      }
      if (removed > 0) _messages.removeRange(0, removed);
      _messages.add(ChatMessage(role: 'user', content: content));
      if (_input.text.trim() == content) _input.clear();
      _proposal = null;
      _bookingForm = null;
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
        _bookingForm = reply.bookingForm;
        _showtimeTickets = reply.showtimeTickets;
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
    final selection = _seatSelection;
    final bookingAfter = _bookingAfter ?? _messages.length;
    final bookingNotice = _bookingNotice;
    final details = _bookingForm;
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
                  onPressed:
                      _loadingHistory ||
                          _sending ||
                          _reviewing ||
                          details != null
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
                      if (_messages.isEmpty && selection == null)
                        _welcome(context),
                      for (
                        var index = 0;
                        index <= _messages.length;
                        index++
                      ) ...[
                        if (selection != null && index == bookingAfter)
                          ChatSeatBooking(
                            key: ObjectKey(selection),
                            selection: selection,
                            authenticated: widget.userId != null,
                            catalog: widget.catalogRepository,
                            bookings: widget.bookingRepository,
                            showSeatPicker: widget.showSeatPicker,
                            onSignIn: () => widget.onSignIn(selection),
                            onReview: () {
                              if ((_bookingAfter ?? _messages.length) ==
                                  _messages.length) {
                                _scrollToLatest();
                              }
                            },
                            onExpired: (notice) {
                              if (_messages.length <=
                                  (_bookingAfter ?? _messages.length)) {
                                return;
                              }
                              final atBottom =
                                  _scroll.hasClients &&
                                  _scroll.position.extentAfter < AppSpacing.lg;
                              setState(
                                () => _bookingNotice = (
                                  after: _messages.length,
                                  text: notice,
                                ),
                              );
                              if (atBottom) _scrollToLatest();
                            },
                            onBack: () {
                              setState(() {
                                _seatSelection = null;
                                _bookingAfter = null;
                                _bookingNotice = null;
                              });
                              _scrollToLatest();
                            },
                          ),
                        if (bookingNotice != null &&
                            index == bookingNotice.after)
                          Semantics(
                            liveRegion: true,
                            child: _MessageBubble(
                              message: ChatMessage(
                                role: 'assistant',
                                content: bookingNotice.text,
                              ),
                              index: index,
                              onOpenLink: _openLink,
                              recommendation: _recommendation,
                            ),
                          ),
                        if (index < _messages.length)
                          _MessageBubble(
                            message: _messages[index],
                            index: index,
                            onOpenLink: _openLink,
                            recommendation: _recommendation,
                          ),
                      ],
                      if (details != null)
                        ChatBookingFormCard(
                          key: ObjectKey(details),
                          details: details,
                          onSearch: _send,
                          onBack: () => setState(() => _bookingForm = null),
                        ),
                      if (_proposal case final proposal?)
                        OutlinedButton.icon(
                          key: const Key('reviewChatBooking'),
                          onPressed: _reviewing || _sending
                              ? null
                              : () => _chooseSeats((
                                  showtimeId: proposal.showtimeId,
                                  tickets: proposal.seatIds.length,
                                  proposal: proposal,
                                )),
                          icon: const Icon(Icons.confirmation_number_outlined),
                          label: const Text('Review booking'),
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
                      focusNode: _inputFocus,
                      enabled: !_loadingHistory,
                      minLines: 1,
                      maxLines: 3,
                      maxLength: 1000,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.send,
                      onEditingComplete: _input.clearComposing,
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
                                    value.text.trim().isEmpty ||
                                    value.text.trim().length > 1000
                                ? null
                                : () {
                                    _inputFocus.requestFocus();
                                    _send(value.text);
                                  },
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
                        _bookingForm = null;
                        _showtimeTickets = const {};
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
                                      _recommendations.clear();
                                      _seatPreviews.clear();
                                      _menu = null;
                                      _proposal = null;
                                      _bookingForm = null;
                                      _showtimeTickets = const {};
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
          'Chào bạn! Hôm nay bạn muốn xem gì?',
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
  const _MessageBubble({
    required this.message,
    required this.index,
    required this.onOpenLink,
    required this.recommendation,
  });

  final ChatMessage message;
  final int index;
  final ValueChanged<String> onOpenLink;
  final Widget Function(String route) recommendation;

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
              if (!user)
                ChatAnswer(
                  text: message.content,
                  onOpenLink: onOpenLink,
                  recommendation: recommendation,
                  key: ValueKey('chatMessage-$index'),
                )
              else
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
