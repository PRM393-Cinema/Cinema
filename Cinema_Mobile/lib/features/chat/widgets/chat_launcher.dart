import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/customer_frame.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/session/roles.dart';
import '../../../core/session/session_state.dart';
import '../../../core/utils/layout.dart';
import '../../../data/services/chat_service.dart';
import 'chat_panel.dart';

// Above the navigator so the same chat survives customer page changes.
class ChatLauncher extends StatefulWidget {
  const ChatLauncher({
    required this.routes,
    required this.service,
    required this.child,
    super.key,
  });

  final RouteTracker routes;
  final ChatService service;
  final Widget child;

  @override
  State<ChatLauncher> createState() => _ChatLauncherState();
}

class _ChatLauncherState extends State<ChatLauncher> {
  final _buttonFocus = FocusNode();
  final _panelFocus = FocusNode();
  bool _open = false;
  bool _hasOpened = false;
  bool _hovered = false;
  bool _focused = false;

  @override
  void dispose() {
    _buttonFocus.dispose();
    _panelFocus.dispose();
    super.dispose();
  }

  void _close({bool restoreFocus = false}) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _open = false;
      _focused = false;
      _hovered = false;
    });
    if (restoreFocus) _buttonFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionProvider.of(context);
    if (isManagementAccount(session.user?.roles)) return widget.child;
    final colors = AppPalette.of(context);
    final media = MediaQuery.of(context);
    final desktop = isDesktopLayout(context);
    final expanded = desktop && (_hovered || _focused);
    return ValueListenableBuilder<String?>(
      valueListenable: widget.routes.current,
      builder: (context, route, _) {
        final hasBottomNav =
            !desktop &&
            const {
              '/',
              AppRoutes.home,
              AppRoutes.myBookings,
              AppRoutes.profile,
            }.contains(Uri.tryParse(route ?? '')?.path);
        return LayoutBuilder(
          builder: (context, constraints) {
            final bottom =
                media.viewInsets.bottom + media.viewPadding.bottom + 12;
            final availableHeight = math.max(
              0.0,
              constraints.maxHeight -
                  bottom -
                  media.padding.top -
                  (desktop ? 88 : 12),
            );
            return Stack(
              fit: StackFit.expand,
              children: [
                widget.child,
                if (_hasOpened)
                  Positioned(
                    right: 12,
                    bottom: bottom,
                    width: math.min(400, constraints.maxWidth - 24),
                    height: math.min(600, availableHeight),
                    child: Offstage(
                      offstage: !_open,
                      child: TickerMode(
                        enabled: _open,
                        child: ExcludeFocus(
                          excluding: !_open,
                          child: CallbackShortcuts(
                            bindings: {
                              const SingleActivator(
                                LogicalKeyboardKey.escape,
                              ): () =>
                                  _close(restoreFocus: true),
                            },
                            child: Overlay.wrap(
                              alwaysSizeToContent: true,
                              child: Focus(
                                focusNode: _panelFocus,
                                child: ChatPanel(
                                  key: ValueKey(session.user?.userId),
                                  service: widget.service,
                                  onClose: _close,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (!_open)
                  Positioned(
                    right: 16,
                    bottom: bottom + (hasBottomNav ? 104 : 0),
                    child: MouseRegion(
                      onEnter: (_) => setState(() => _hovered = true),
                      onExit: (_) => setState(() => _hovered = false),
                      child: Semantics(
                        container: true,
                        button: true,
                        label: 'Open Cinema AI chat',
                        child: AnimatedContainer(
                          key: const Key('cinemaChatLauncherSize'),
                          duration: media.disableAnimations
                              ? Duration.zero
                              : const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          width: expanded
                              ? 56 + media.textScaler.scale(88)
                              : 56,
                          height: 56,
                          child: Material(
                            color: colors.primary,
                            elevation: 3,
                            shadowColor: Colors.black.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(28),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              key: const Key('openCinemaChat'),
                              focusNode: _buttonFocus,
                              onFocusChange: (focused) =>
                                  setState(() => _focused = focused),
                              onTap: () {
                                setState(() {
                                  _open = true;
                                  _hasOpened = true;
                                  _hovered = false;
                                  _focused = false;
                                });
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (mounted && _open) {
                                    _panelFocus.requestFocus();
                                  }
                                });
                              },
                              child: ExcludeSemantics(
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 56,
                                      child: Icon(
                                        Icons.chat_bubble_outline_rounded,
                                        color: colors.onPrimary,
                                      ),
                                    ),
                                    if (expanded)
                                      Expanded(
                                        child: Text(
                                          'Cinema AI',
                                          maxLines: 1,
                                          softWrap: false,
                                          style: TextStyle(
                                            color: colors.onPrimary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
