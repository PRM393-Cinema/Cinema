import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/customer_frame.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/session/roles.dart';
import '../../../core/session/session_state.dart';
import '../../../core/utils/layout.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/network/api_exception.dart';
import '../../../data/models/booking_draft.dart';
import '../../../data/models/seat.dart';
import '../../../data/repositories/booking_repository.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../data/services/chat_service.dart';
import 'chat_panel.dart';

// Above the navigator so the same chat survives customer page changes.
class ChatLauncher extends StatefulWidget {
  const ChatLauncher({
    required this.routes,
    required this.service,
    required this.catalogRepository,
    required this.bookingRepository,
    required this.child,
    super.key,
  });

  final RouteTracker routes;
  final ChatService service;
  final CatalogRepository catalogRepository;
  final BookingRepository bookingRepository;
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
  bool _reviewingBooking = false;

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

  Future<bool> _reviewBooking(ChatBookingProposal proposal) async {
    final session = SessionProvider.of(context);
    final userId = session.user?.userId;
    final navigator = widget.routes.navigator;
    if (!session.isAuthenticated || navigator == null) return false;
    FocusManager.instance.primaryFocus?.unfocus();
    // The launcher sits above the navigator; hide it while its modal is open.
    setState(() => _reviewingBooking = true);
    try {
      if (!proposal.expiresAt.isAfter(DateTime.now())) {
        throw const FormatException(
          'This proposal expired. Ask Cinema AI for a fresh proposal.',
        );
      }
      final movie = await widget.catalogRepository.getMovie(proposal.movieId);
      final showtime = await widget.catalogRepository.getShowtime(
        proposal.showtimeId,
      );
      final seatMap = await widget.catalogRepository.getSeatMap(showtime);
      final seats = seatMap.seats
          .where((seat) => proposal.seatIds.contains(seat.id))
          .toList();
      final draft = BookingDraft(
        movie: movie,
        showtime: showtime,
        seats: seats,
      );
      if (showtime.movieId != movie.id ||
          showtime.status != 'OPEN' ||
          !showtime.startTime.isAfter(DateTime.now()) ||
          seats.length != proposal.seatIds.length ||
          seats.any(
            (s) => seatMap.statusOf(s) != SeatReservationStatus.available,
          ) ||
          seats.any(
            (s) => s.isSweetbox && s.sweetboxPartnerIn(seats) == null,
          ) ||
          (draft.totalPrice - proposal.total).abs() > 0.01) {
        throw const FormatException(
          'Seats, showtime or prices changed. Ask Cinema AI to refresh the proposal.',
        );
      }
      if (!mounted ||
          session.user?.userId != userId ||
          !session.isAuthenticated) {
        return false;
      }
      final confirmed = await showDialog<bool>(
        context: navigator.context,
        builder: (context) => AlertDialog(
          title: const Text('Review booking'),
          scrollable: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(movie.title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Text(
                '${formatDateTime(showtime.startTime)} · ${showtime.format}',
              ),
              Text('Seats: ${seats.map((s) => s.label).join(', ')}'),
              const SizedBox(height: 12),
              Text('Tickets: ${formatVnd(draft.totalPrice)}'),
              const SizedBox(height: 12),
              const Text(
                'Confirm to hold these seats and open checkout. Snacks, discounts and points can be reviewed there. No payment is taken here.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('confirmChatBooking'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm & hold seats'),
            ),
          ],
        ),
      );
      if (confirmed != true ||
          !mounted ||
          !session.isAuthenticated ||
          session.user?.userId != userId) {
        return false;
      }
      if (!proposal.expiresAt.isAfter(DateTime.now())) {
        throw const FormatException(
          'This proposal expired. Please refresh it.',
        );
      }
      _close();
      // The existing summary performs the real transaction, checks seat conflicts and recalculates prices.
      navigator.pushNamed(
        AppRoutes.bookingSummary(showtime.id),
        arguments: draft,
      );
      return true;
    } on Object catch (error) {
      if (mounted && navigator.mounted) {
        await showDialog<void>(
          context: navigator.context,
          builder: (context) => AlertDialog(
            title: const Text('Unable to prepare booking'),
            content: Text(
              error is FormatException
                  ? error.message
                  : error is ApiException
                  ? error.message
                  : 'Unable to check seats. Please try again.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _reviewingBooking = false);
    }
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
                      offstage: !_open || _reviewingBooking,
                      child: TickerMode(
                        enabled: _open && !_reviewingBooking,
                        child: ExcludeFocus(
                          excluding: !_open || _reviewingBooking,
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
                                  userId: session.user?.userId,
                                  service: widget.service,
                                  catalogRepository: widget.catalogRepository,
                                  bookingRepository: widget.bookingRepository,
                                  onClose: _close,
                                  onOpenLink: (route) {
                                    final navigator = widget.routes.navigator;
                                    if (navigator == null) return;
                                    _close();
                                    navigator.pushNamed(route);
                                  },
                                  onReviewBooking: _reviewBooking,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (!_open && !_reviewingBooking)
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
