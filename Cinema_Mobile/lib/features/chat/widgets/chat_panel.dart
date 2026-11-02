import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/cinema_account_widgets.dart';
import '../../../data/services/chat_service.dart';

class ChatPanel extends StatefulWidget {
  const ChatPanel({required this.service, required this.onClose, super.key});

  final ChatService service;
  final VoidCallback onClose;

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <ChatMessage>[];
  bool _sending = false;
  String? _error;

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
    if (_sending || content.isEmpty || content.length > 1000) return;
    setState(() {
      if (_error != null) _messages.removeLast();
      if (_messages.length >= 60) _messages.removeRange(0, 2);
      _messages.add(ChatMessage(role: 'user', content: content));
      _input.clear();
    });
    await _request();
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
      final reply = await widget.service.reply(context);
      if (!mounted) return;
      setState(
        () => _messages.add(ChatMessage(role: 'assistant', content: reply)),
      );
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
                  key: const Key('newCinemaChat'),
                  tooltip: 'New chat',
                  onPressed: _sending || _messages.isEmpty
                      ? null
                      : () => setState(() {
                          _messages.clear();
                          _error = null;
                          _input.clear();
                        }),
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
          Expanded(
            child: ListView(
              key: const Key('cinemaChatMessages'),
              controller: _scroll,
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                if (_messages.isEmpty) _welcome(context),
                for (var index = 0; index < _messages.length; index++)
                  _MessageBubble(message: _messages[index], index: index),
                if (_sending)
                  Semantics(
                    liveRegion: true,
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
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
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.border),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  key: const Key('cinemaChatInput'),
                  controller: _input,
                  enabled: !_sending,
                  minLines: 1,
                  maxLines: 3,
                  maxLength: 1000,
                  keyboardType: TextInputType.multiline,
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
                            _sending ||
                                value.text.trim().isEmpty ||
                                value.text.trim().length > 1000
                            ? null
                            : () => _send(value.text),
                        icon: const Icon(Icons.arrow_upward_rounded),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'AI can make mistakes. Messages are sent to OpenAI; avoid personal information.',
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
          'Tell me what you enjoy. I can suggest movies, look up upcoming showtimes and explain how to book.',
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
              'Hướng dẫn đặt vé',
            ])
              OutlinedButton(
                onPressed: _sending ? null : () => _send(prompt),
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
