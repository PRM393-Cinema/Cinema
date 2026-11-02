import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/session/roles.dart';
import '../core/session/session_state.dart';
import '../core/utils/layout.dart';
import '../core/widgets/cinema_background.dart';
import 'routes/app_routes.dart';
import 'theme/app_colors.dart';
import 'theme/app_spacing.dart';
import 'theme/app_text_styles.dart';
import 'theme/theme_switch.dart';

// Name of the page on top of the customer app's navigator, so the website
// navigation can show where the customer is.
class RouteTracker extends NavigatorObserver {
  final current = ValueNotifier<String?>(null);
  final _pages = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) _pages.add(route);
    _publish();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _pages.remove(route);
    _publish();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _pages.remove(route);
    _publish();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _pages.indexOf(oldRoute);
    if (newRoute is PageRoute) {
      if (index >= 0) {
        _pages[index] = newRoute;
      } else {
        _pages.add(newRoute);
      }
    } else if (index >= 0) {
      _pages.removeAt(index);
    }
    _publish();
  }

  // The navigator reports changes while it builds, also in the first build,
  // which runs outside a frame: publish after the next frame.
  void _publish() {
    SchedulerBinding.instance
      ..addPostFrameCallback(
        (_) =>
            current.value = _pages.isEmpty ? null : _pages.last.settings.name,
      )
      ..ensureVisualUpdate();
  }
}

enum _Section { movies, tickets, ratings, notifications, account }

const _authPages = {
  AppRoutes.login,
  AppRoutes.register,
  AppRoutes.verifyEmail,
  AppRoutes.forgotPassword,
  AppRoutes.resetPassword,
};

_Section? _sectionOf(String path) {
  if (path.startsWith(AppRoutes.myBookings)) return _Section.tickets;
  if (path.startsWith(AppRoutes.myRatings)) return _Section.ratings;
  if (path.startsWith(AppRoutes.notifications)) return _Section.notifications;
  if (path == AppRoutes.profile || path == AppRoutes.paymentHistory) {
    return _Section.account;
  }
  if (path == '/' ||
      path == AppRoutes.home ||
      path.startsWith('/movies') ||
      path.startsWith('/showtimes')) {
    return _Section.movies;
  }
  return null;
}

// Customer app frame (MaterialApp.builder): on a computer, every page gets the
// website navigation bar at the top; the tab bar at the bottom is only used in
// the app layout. Sign-in pages keep their own full-screen design.
class CustomerFrame extends StatelessWidget {
  const CustomerFrame({
    required this.routes,
    required this.child,
    required this.onSignOut,
    super.key,
  });

  final RouteTracker routes;
  final Widget child;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    if (!isDesktopLayout(context)) return child;

    return ValueListenableBuilder<String?>(
      valueListenable: routes.current,
      builder: (context, name, _) {
        final session = SessionProvider.of(context);
        final path = Uri.tryParse(name ?? '')?.path ?? '';
        final hidden =
            name == null ||
            _authPages.contains(path) ||
            isManagementAccount(session.user?.roles);
        if (hidden) return child;

        final frame = Stack(
          fit: StackFit.expand,
          children: [
            Padding(
              padding: EdgeInsets.only(
                top: path == AppRoutes.home || path == '/'
                    ? 0
                    : _WebHeader.height,
              ),
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: Theme(
                  data: Theme.of(context)
                      .copyWith(scaffoldBackgroundColor: Colors.transparent),
                  child: child,
                ),
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: Overlay.wrap(
                alwaysSizeToContent: true,
                clipBehavior: Clip.none,
                child: _WebHeader(
                  onSignOut: onSignOut,
                  menuContext: () => routes.navigator?.overlay?.context,
                  selected: _sectionOf(path),
                  signedIn: session.isAuthenticated,
                  userName: session.user?.displayName,
                  onOpen: (route) {
                    final navigator = routes.navigator;
                    if (navigator == null || route == name) return;
                    // Like the tab bar: sections open on top of Home.
                    navigator.pushNamedAndRemoveUntil(
                      route,
                      (page) =>
                          route != AppRoutes.home &&
                          page.settings.name == AppRoutes.home,
                    );
                  },
                ),
              ),
            ),
          ],
        );
        return ColoredBox(
          key: const Key('webFrameBackground'),
          color: AppPalette.of(context).background,
          child: CinemaBackground(child: frame),
        );
      },
    );
  }
}

// The header sits above the navigator; menus use its overlay explicitly.
class _WebHeader extends StatelessWidget {
  const _WebHeader({
    required this.selected,
    required this.signedIn,
    required this.userName,
    required this.onOpen,
    required this.onSignOut,
    required this.menuContext,
  });

  static const height = webHeaderHeight;

  final _Section? selected;
  final bool signedIn;
  final String? userName;
  final ValueChanged<String> onOpen;
  final VoidCallback onSignOut;
  final BuildContext? Function() menuContext;

  @override
  Widget build(BuildContext context) {
    final name = userName?.trim() ?? '';

    return Material(
      key: const Key('webHeader'),
      color: Colors.transparent,
      child: Container(
        height: height,
        padding: centeredPadding(
          context,
          AppSpacing.lg,
          maxWidth: pageMaxWidth,
        ).copyWith(top: 0, bottom: 0),
        child: Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: InkWell(
                    key: const Key('webHeaderLogo'),
                    hoverColor: Colors.transparent,
                    focusColor: AppPalette.of(context).primary
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => onOpen(AppRoutes.home),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppPalette.of(context).background
                            .withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.sm,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.local_movies,
                            color: AppPalette.of(context).primary,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: 'COSMO',
                                  style: TextStyle(
                                    color: AppPalette.of(context).primary,
                                  ),
                                ),
                                TextSpan(text: 'Q'),
                                TextSpan(
                                  text: '  Cinema',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0,
                                  ),
                                ),
                              ],
                            ),
                            style: AppTextStyles.heading2.copyWith(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // The links take the free space and scroll sideways rather than
            // overflow on a narrow window.
            Expanded(
              flex: 3,
              child: Align(
                alignment: Alignment.center,
                child: Container(
                  key: const Key('webHeaderNavGroup'),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppPalette.of(context).surface
                        .withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: AppPalette.of(context).border),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      key: const Key('webHeaderLinks'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _HeaderLink(
                          label: 'Movies',
                          selected: selected == _Section.movies,
                          onTap: () => onOpen(AppRoutes.home),
                        ),
                        _HeaderLink(
                          label: 'My tickets',
                          selected: selected == _Section.tickets,
                          onTap: () => onOpen(AppRoutes.myBookings),
                        ),
                        _HeaderLink(
                          key: const Key('myRatings'),
                          label: 'Ratings',
                          selected: selected == _Section.ratings,
                          onTap: () => onOpen(AppRoutes.myRatings),
                        ),
                        _HeaderLink(
                          label: 'Notifications',
                          selected: selected == _Section.notifications,
                          badge: SessionProvider.of(context)
                              .unreadNotifications,
                          onTap: () => onOpen(AppRoutes.notifications),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const ThemeSwitch(),
                      if (signedIn)
                        _AccountButton(
                          name: name.isEmpty ? 'Account' : name,
                          selected: selected == _Section.account,
                          onOpen: onOpen,
                          onSignOut: onSignOut,
                          menuContext: menuContext,
                        )
                      else ...[
                        TextButton(
                          key: const Key('webHeaderSignIn'),
                          onPressed: () => onOpen(AppRoutes.login),
                          style: TextButton.styleFrom(
                            foregroundColor: AppPalette.of(context).textPrimary,
                          ),
                          child: const Text(
                            'Sign in',
                            style: AppTextStyles.button,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        FilledButton(
                          key: const Key('webHeaderRegister'),
                          onPressed: () => onOpen(AppRoutes.register),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppPalette.of(context).primary,
                            foregroundColor: AppPalette.of(context).onPrimary,
                          ),
                          child: const Text('Create account'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderLink extends StatelessWidget {
  const _HeaderLink({
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge = 0,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  // Unread notifications shown next to the label.
  final int badge;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
    child: InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: selected
              ? AppPalette.of(context).primary.withValues(alpha: 0.06)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected
                ? AppPalette.of(context).primary
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Badge(
          isLabelVisible: badge > 0,
          label: Text('$badge'),
          offset: const Offset(14, -6),
          child: Text(
            label,
            style: AppTextStyles.body.copyWith(
              color: selected
                  ? AppPalette.of(context).primary
                  : AppPalette.of(context).textSecondary,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    ),
  );
}

class _AccountButton extends StatefulWidget {
  const _AccountButton({
    required this.name,
    required this.selected,
    required this.onOpen,
    required this.onSignOut,
    required this.menuContext,
  });

  final String name;
  final bool selected;
  final ValueChanged<String> onOpen;
  final VoidCallback onSignOut;
  final BuildContext? Function() menuContext;

  @override
  State<_AccountButton> createState() => _AccountButtonState();
}

class _AccountButtonState extends State<_AccountButton> {
  bool _menuOpen = false;

  Future<void> _openMenu(BuildContext context) async {
    final menuContext = widget.menuContext();
    if (menuContext == null) return;
    if (_menuOpen) {
      Navigator.of(menuContext).pop();
      return;
    }
    setState(() => _menuOpen = true);
    final box = context.findRenderObject()! as RenderBox;
    final overlay = menuContext.findRenderObject()! as RenderBox;
    final anchor = Rect.fromPoints(
      box.localToGlobal(Offset.zero),
      box.localToGlobal(box.size.bottomRight(Offset.zero)),
    ).shift(-overlay.localToGlobal(Offset.zero));
    final selected = await showMenu<String>(
      context: menuContext,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(
          anchor.left,
          (anchor.bottom + 8).clamp(0, overlay.size.height),
          anchor.width,
          0,
        ),
        Offset.zero & overlay.size,
      ),
      constraints: const BoxConstraints.tightFor(width: 264),
      menuPadding: const EdgeInsets.all(AppSpacing.sm),
      color: AppPalette.of(context).surfaceSoft,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppPalette.of(context).border),
      ),
      items: [
        for (final entry in [
          (AppRoutes.profile, Icons.person_outline, 'Account settings'),
          (
            AppRoutes.paymentHistory,
            Icons.receipt_long_outlined,
            'Payment history',
          ),
          ('signOut', Icons.logout_rounded, 'Sign out'),
        ])
          PopupMenuItem(
            value: entry.$1,
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            textStyle: AppTextStyles.body,
            child: Row(
              children: [
                Icon(
                  entry.$2,
                  size: 20,
                  color: entry.$1 == 'signOut'
                      ? AppPalette.of(context).error
                      : AppPalette.of(context).primary,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: Text(entry.$3)),
              ],
            ),
          ),
      ],
    );
    if (!mounted) return;
    setState(() => _menuOpen = false);
    if (selected == null) return;
    if (selected == 'signOut') {
      widget.onSignOut();
    } else {
      widget.onOpen(selected);
    }
  }

  @override
  Widget build(BuildContext context) => InkWell(
    key: const Key('webHeaderAccount'),
    borderRadius: BorderRadius.circular(24),
    onTap: () => _openMenu(context),
    child: Container(
      padding: const EdgeInsets.fromLTRB(6, 6, AppSpacing.md, 6),
      decoration: BoxDecoration(
        color: AppPalette.of(context).surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: widget.selected || _menuOpen
              ? AppPalette.of(context).primary
              : AppPalette.of(context).border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: AppPalette.of(context).primary
                .withValues(alpha: 0.16),
            child: Text(
              widget.name.characters.first.toUpperCase(),
              style: AppTextStyles.bodySmall.copyWith(
                color: AppPalette.of(context).primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              widget.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppPalette.of(context).textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          AnimatedRotation(
            turns: _menuOpen ? 0.5 : 0,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 150),
            child: Icon(
              Icons.expand_more_rounded,
              size: 18,
              color: AppPalette.of(context).textSecondary,
            ),
          ),
        ],
      ),
    ),
  );
}
