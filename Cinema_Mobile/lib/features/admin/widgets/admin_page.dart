import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/session/roles.dart';
import '../../../core/session/session_state.dart';
import '../../../core/widgets/cinema_background.dart';

// Sections of the admin website. Staff see Dashboard, Operations, Check-in and
// Profile; admins also manage movies, rooms and accounts.
enum AdminSection {
  dashboard,
  operations,
  checkIn,
  movies,
  rooms,
  snacks,
  promotions,
  accounts,
  profile,
}

class _Destination {
  const _Destination(this.section, this.label, this.icon, this.route);

  final AdminSection section;
  final String label;
  final IconData icon;
  final String route;
}

List<_Destination> _destinationsFor({required bool admin}) => [
  _Destination(
    AdminSection.dashboard,
    'Dashboard',
    Icons.space_dashboard_rounded,
    admin ? AppRoutes.adminDashboard : AppRoutes.staffDashboard,
  ),
  const _Destination(
    AdminSection.operations,
    'Operations',
    Icons.local_activity,
    AppRoutes.staffOperations,
  ),
  const _Destination(
    AdminSection.checkIn,
    'Check-in',
    Icons.qr_code_scanner,
    AppRoutes.staffCheckIn,
  ),
  if (admin) ...const [
    _Destination(
      AdminSection.movies,
      'Movies',
      Icons.movie_outlined,
      AppRoutes.adminMovies,
    ),
    _Destination(
      AdminSection.rooms,
      'Rooms',
      Icons.meeting_room_outlined,
      AppRoutes.adminRooms,
    ),
    _Destination(
      AdminSection.snacks,
      'Snacks',
      Icons.fastfood_outlined,
      AppRoutes.adminSnacks,
    ),
    _Destination(
      AdminSection.promotions,
      'Promotions',
      Icons.local_offer_outlined,
      AppRoutes.adminPromotions,
    ),
    _Destination(
      AdminSection.accounts,
      'Accounts',
      Icons.manage_accounts,
      AppRoutes.adminUsers,
    ),
  ],
  _Destination(
    AdminSection.profile,
    'Profile',
    Icons.person,
    admin ? AppRoutes.adminProfile : AppRoutes.staffProfile,
  ),
];

// Page frame of the admin website: navigation on the left and the page on the
// right, built for a computer screen. Narrow windows get the navigation in a
// drawer.
class AdminPage extends StatelessWidget {
  const AdminPage({
    required this.title,
    required this.section,
    required this.child,
    this.actions = const [],
    super.key,
  });

  final String title;
  final AdminSection section;
  final Widget child;
  final List<Widget> actions;

  static const drawerBelow = 640.0;
  static const labelsFrom = 1100.0;
  static const _railWidth = 88.0;
  static const _extendedRailWidth = 240.0;

  // Width the navigation takes next to the page in a window this wide (with
  // its divider); 0 when it is in a drawer.
  static double navigationWidth(double windowWidth) => windowWidth < drawerBelow
      ? 0
      : (windowWidth >= labelsFrom ? _extendedRailWidth : _railWidth) + 1;

  @override
  Widget build(BuildContext context) {
    final admin = isAdminAccount(SessionProvider.of(context).user?.roles);
    final destinations = _destinationsFor(admin: admin);
    final selected = destinations.indexWhere((d) => d.section == section);

    void open(int index) {
      if (index == selected && !Navigator.canPop(context)) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        destinations[index].route,
        (_) => false,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < drawerBelow;
        final page = _PageBody(
          title: title,
          actions: actions,
          showMenu: compact,
          child: child,
        );

        if (compact) {
          return Scaffold(
            drawer: _NavigationDrawer(
              admin: admin,
              destinations: destinations,
              selected: selected,
              onOpen: open,
            ),
            body: CinemaBackground(child: SafeArea(child: page)),
          );
        }

        return Scaffold(
          body: CinemaBackground(
            child: SafeArea(
              child: Row(
                children: [
                  SizedBox(
                    width: navigationWidth(constraints.maxWidth) - 1,
                    child: _NavigationSide(
                      admin: admin,
                      extended: constraints.maxWidth >= labelsFrom,
                      destinations: destinations,
                      selected: selected,
                      onOpen: open,
                    ),
                  ),
                  const VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: AppColors.border,
                  ),
                  Expanded(child: page),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// Gives a staff or admin page the size of its content area (the window minus
// the navigation), so pages that size and centre their content from
// MediaQuery line up with the page title instead of the whole window.
class AdminViewport extends StatelessWidget {
  const AdminViewport({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final width = media.size.width;
    return MediaQuery(
      data: media.copyWith(
        size: Size(width - AdminPage.navigationWidth(width), media.size.height),
      ),
      child: child,
    );
  }
}

class _PageBody extends StatelessWidget {
  const _PageBody({
    required this.title,
    required this.actions,
    required this.showMenu,
    required this.child,
  });

  final String title;
  final List<Widget> actions;
  final bool showMenu;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final canGoBack = Navigator.canPop(context);

    return LayoutBuilder(
      // Pages size and centre themselves from MediaQuery: give them the width
      // next to the navigation, not the whole window.
      builder: (context, constraints) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(size: Size(constraints.maxWidth, constraints.maxHeight)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Row(
                children: [
                  if (showMenu)
                    Builder(
                      builder: (context) => IconButton(
                        tooltip: 'Menu',
                        icon: const Icon(Icons.menu),
                        onPressed: () => Scaffold.of(context).openDrawer(),
                      ),
                    ),
                  if (canGoBack)
                    IconButton(
                      tooltip: 'Back',
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.maybePop(context),
                    ),
                  if (showMenu || canGoBack)
                    const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      title,
                      style: AppTextStyles.heading1,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ...actions,
                ],
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _NavigationSide extends StatelessWidget {
  const _NavigationSide({
    required this.admin,
    required this.extended,
    required this.destinations,
    required this.selected,
    required this.onOpen,
  });

  final bool admin;
  final bool extended;
  final List<_Destination> destinations;
  final int selected;
  final ValueChanged<int> onOpen;

  // Short windows scroll the navigation instead of cutting off its last
  // sections.
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: IntrinsicHeight(child: _rail()),
      ),
    ),
  );

  Widget _rail() {
    return NavigationRail(
      extended: extended,
      minWidth: AdminPage._railWidth,
      minExtendedWidth: AdminPage._extendedRailWidth,
      backgroundColor: AppColors.surface.withValues(alpha: 0.72),
      selectedIndex: selected < 0 ? null : selected,
      onDestinationSelected: onOpen,
      labelType: extended
          ? NavigationRailLabelType.none
          : NavigationRailLabelType.all,
      indicatorColor: AppColors.primary.withValues(alpha: 0.16),
      selectedIconTheme: const IconThemeData(color: AppColors.primary),
      unselectedIconTheme: const IconThemeData(color: AppColors.textSecondary),
      selectedLabelTextStyle: AppTextStyles.bodySmall.copyWith(
        color: AppColors.primary,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelTextStyle: AppTextStyles.bodySmall.copyWith(
        color: AppColors.textSecondary,
      ),
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: _Brand(admin: admin, extended: extended),
      ),
      destinations: [
        for (final destination in destinations)
          NavigationRailDestination(
            icon: Icon(destination.icon),
            label: Text(destination.label),
          ),
      ],
    );
  }
}

class _NavigationDrawer extends StatelessWidget {
  const _NavigationDrawer({
    required this.admin,
    required this.destinations,
    required this.selected,
    required this.onOpen,
  });

  final bool admin;
  final List<_Destination> destinations;
  final int selected;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: _Brand(admin: admin, extended: true),
            ),
            for (final (index, destination) in destinations.indexed)
              ListTile(
                leading: Icon(destination.icon),
                title: Text(destination.label),
                selected: index == selected,
                selectedColor: AppColors.primary,
                iconColor: AppColors.textSecondary,
                textColor: AppColors.textPrimary,
                onTap: () {
                  Navigator.pop(context);
                  onOpen(index);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.admin, required this.extended});

  final bool admin;
  final bool extended;

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        admin ? 'ADMIN' : 'STAFF',
        style: AppTextStyles.caption.copyWith(color: AppColors.primary),
      ),
    );
    const icon = Icon(Icons.local_movies, color: AppColors.primary);

    if (!extended) {
      return Column(
        children: [
          icon,
          const SizedBox(height: AppSpacing.sm),
          badge,
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: AppSpacing.sm),
        Text(
          'COSMOQ',
          style: AppTextStyles.title.copyWith(
            color: AppColors.primary,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        badge,
      ],
    );
  }
}
