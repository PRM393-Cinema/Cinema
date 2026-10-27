import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/session/roles.dart';
import '../core/session/session_state.dart';
import '../core/utils/layout.dart';
import 'routes/app_routes.dart';
import 'theme/app_colors.dart';
import 'theme/app_spacing.dart';
import 'theme/app_text_styles.dart';

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

enum _Section { movies, tickets, notifications, account }

const _authPages = {
  AppRoutes.login,
  AppRoutes.register,
  AppRoutes.verifyEmail,
  AppRoutes.forgotPassword,
  AppRoutes.resetPassword,
};

_Section? _sectionOf(String path) {
  if (path.startsWith(AppRoutes.myBookings)) return _Section.tickets;
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
  const CustomerFrame({required this.routes, required this.child, super.key});

  final RouteTracker routes;
  final Widget child;

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

        return Column(
          children: [
            _WebHeader(
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
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: child,
              ),
            ),
          ],
        );
      },
    );
  }
}

// Website navigation bar. It sits above the navigator, so it uses no tooltips
// or menus (they need the navigator's overlay).
class _WebHeader extends StatelessWidget {
  const _WebHeader({
    required this.selected,
    required this.signedIn,
    required this.userName,
    required this.onOpen,
  });

  static const height = 68.0;

  final _Section? selected;
  final bool signedIn;
  final String? userName;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final name = userName?.trim() ?? '';

    return Material(
      key: const Key('webHeader'),
      color: AppColors.surface.withValues(alpha: 0.92),
      child: Container(
        height: height,
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        padding: centeredPadding(
          context,
          AppSpacing.lg,
          maxWidth: pageMaxWidth,
        ).copyWith(top: 0, bottom: 0),
        child: Row(
          children: [
            InkWell(
              key: const Key('webHeaderLogo'),
              borderRadius: BorderRadius.circular(8),
              onTap: () => onOpen(AppRoutes.home),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_movies, color: AppColors.primary),
                    const SizedBox(width: AppSpacing.sm),
                    Text.rich(
                      const TextSpan(
                        children: [
                          TextSpan(
                            text: 'COSMO',
                            style: TextStyle(color: AppColors.primary),
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
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xl),
            _HeaderLink(
              label: 'Movies',
              selected: selected == _Section.movies,
              onTap: () => onOpen(AppRoutes.home),
            ),
            if (signedIn) ...[
              _HeaderLink(
                label: 'My tickets',
                selected: selected == _Section.tickets,
                onTap: () => onOpen(AppRoutes.myBookings),
              ),
              _HeaderLink(
                label: 'Notifications',
                selected: selected == _Section.notifications,
                badge: SessionProvider.of(context).unreadNotifications,
                onTap: () => onOpen(AppRoutes.notifications),
              ),
            ],
            const Spacer(),
            if (signedIn)
              _AccountButton(
                name: name.isEmpty ? 'Account' : name,
                selected: selected == _Section.account,
                onTap: () => onOpen(AppRoutes.profile),
              )
            else ...[
              TextButton(
                key: const Key('webHeaderSignIn'),
                onPressed: () => onOpen(AppRoutes.login),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                ),
                child: const Text('Sign in', style: AppTextStyles.button),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton(
                key: const Key('webHeaderRegister'),
                onPressed: () => onOpen(AppRoutes.register),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.background,
                ),
                child: const Text('Create account'),
              ),
            ],
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
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? AppColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Badge(
          isLabelVisible: badge > 0,
          label: Text('$badge'),
          offset: const Offset(14, -6),
          child: Text(
            label,
            style: AppTextStyles.body.copyWith(
              color: selected ? AppColors.primary : AppColors.textSecondary,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    ),
  );
}

class _AccountButton extends StatelessWidget {
  const _AccountButton({
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    key: const Key('webHeaderAccount'),
    borderRadius: BorderRadius.circular(24),
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.fromLTRB(6, 6, AppSpacing.md, 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: AppColors.primary.withValues(alpha: 0.16),
            child: Text(
              name.characters.first.toUpperCase(),
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
