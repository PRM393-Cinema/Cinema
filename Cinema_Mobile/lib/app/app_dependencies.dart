import '../core/network/api_client.dart';
import '../core/session/session_state.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/booking_repository.dart';
import '../data/repositories/catalog_repository.dart';
import '../data/services/auth_service.dart';
import '../data/services/booking_service.dart';
import '../data/services/movie_service.dart';
import '../data/services/staff_service.dart';
import '../data/storage/auth_token_storage.dart';
import '../data/storage/token_manager.dart';

class AppDependencies {
  const AppDependencies({
    required this.authRepository,
    required this.catalogRepository,
    required this.bookingRepository,
    required this.staffService,
  });

  // Repositories backed by the API gateway. Token renewals and expiry are
  // reflected in [session] so the UI follows the signed-in state.
  factory AppDependencies.remote({required SessionState session}) {
    final storage = SecureAuthTokenStorage();

    late final AuthService authService;
    final tokenManager = TokenManager(
      storage: storage,
      refreshSession: (refreshToken) => authService.refresh(refreshToken),
      onSessionRenewed: session.setAuthenticated,
      onSessionExpired: session.clear,
    );

    final client = ApiClient(tokenProvider: tokenManager);
    authService = AuthService(client: client);
    final bookingService = BookingService(client: client);

    return AppDependencies(
      authRepository: RemoteAuthRepository(
        service: authService,
        storage: storage,
      ),
      catalogRepository: RemoteCatalogRepository(
        movieService: MovieService(client: client),
        bookingService: bookingService,
      ),
      bookingRepository: RemoteBookingRepository(service: bookingService),
      staffService: StaffService(client: client),
    );
  }

  final AuthRepository authRepository;
  final CatalogRepository catalogRepository;
  final BookingRepository bookingRepository;
  final StaffService staffService;
}
