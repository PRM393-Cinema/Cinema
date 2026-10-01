import 'package:flutter/material.dart';

import '../data/cinema_api.dart';
import '../features/account/account_page.dart';
import '../features/discovery/home_page.dart';
import '../features/tickets/tickets_page.dart';
import 'theme.dart';

class CinemaApp extends StatelessWidget {
  const CinemaApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Ciné',
    debugShowCheckedModeBanner: false,
    theme: cinemaTheme(),
    home: const CinemaShell(),
  );
}

class CinemaShell extends StatefulWidget {
  const CinemaShell({super.key});

  @override
  State<CinemaShell> createState() => _CinemaShellState();
}

class _CinemaShellState extends State<CinemaShell> {
  final _api = CinemaApi();
  int _tab = 0;
  bool _ready = false;
  Map<String, dynamic>? _user;
  int _ticketRevision = 0;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    await _api.restoreSession();
    if (!mounted) return;
    setState(() {
      _user = _api.user;
      _ready = true;
    });
  }

  Future<Map<String, dynamic>?> _authenticate() async {
    final user = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => AuthPage(api: _api)),
    );
    if (user != null && mounted) setState(() => _user = user);
    return user;
  }

  Future<void> _signOut() async {
    await _api.signOut();
    if (mounted) setState(() => _user = null);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready)
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: CinemaColors.gold),
        ),
      );
    final pages = [
      HomePage(
        api: _api,
        onAuthenticate: _authenticate,
        onBookingCreated: _bookingCreated,
      ),
      TicketsPage(
        api: _api,
        user: _user,
        onAuthenticate: _authenticate,
        revision: _ticketRevision,
      ),
      AccountPage(
        user: _user,
        onAuthenticate: _authenticate,
        onSignOut: _signOut,
      ),
    ];
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: SafeArea(
        top: false,
        child: NavigationBar(
          selectedIndex: _tab,
          height: 66,
          backgroundColor: CinemaColors.surface,
          indicatorColor: CinemaColors.gold.withValues(alpha: .2),
          onDestinationSelected: (index) => setState(() {
            _tab = index;
            if (index == 1) _ticketRevision++;
          }),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.local_movies_outlined),
              selectedIcon: Icon(Icons.local_movies),
              label: 'Khám phá',
            ),
            NavigationDestination(
              icon: Icon(Icons.confirmation_number_outlined),
              selectedIcon: Icon(Icons.confirmation_number),
              label: 'Vé của tôi',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Tài khoản',
            ),
          ],
        ),
      ),
    );
  }

  void _bookingCreated() => setState(() {
    _ticketRevision++;
    _tab = 1;
  });
}
