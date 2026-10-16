import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mark_v3/services/ConnectionNotification_/NotificationCon_service.dart';

// Estado inmutable de la vista Home
class HomeState {
  final int selectedNavIndex;
  final String searchQuery;
  final bool isGpsActive;
  final bool isRefreshing;
  final int unreadNotifications;
  final String activeZone;
  final String transmissionStatus;

  const HomeState({
    this.selectedNavIndex = 0,
    this.searchQuery = '',
    this.isGpsActive = true,
    this.isRefreshing = false,
    this.unreadNotifications = 0,
    this.activeZone = 'Zona Asignada',
    this.transmissionStatus = 'En línea',
  });

  HomeState copyWith({
    int? selectedNavIndex,
    String? searchQuery,
    bool? isGpsActive,
    bool? isRefreshing,
    int? unreadNotifications,
    String? activeZone,
    String? transmissionStatus,
  }) {
    return HomeState(
      selectedNavIndex: selectedNavIndex ?? this.selectedNavIndex,
      searchQuery: searchQuery ?? this.searchQuery,
      isGpsActive: isGpsActive ?? this.isGpsActive,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      unreadNotifications: unreadNotifications ?? this.unreadNotifications,
      activeZone: activeZone ?? this.activeZone,
      transmissionStatus: transmissionStatus ?? this.transmissionStatus,
    );
  }
}

// Proveedor global de Home gestionado con Riverpod Notifier
final homeProvider = NotifierProvider<HomeNotifier, HomeState>(HomeNotifier.new);

class HomeNotifier extends Notifier<HomeState> {
  @override
  HomeState build() {
    return const HomeState();
  }

  void setNavIndex(int index) {
    state = state.copyWith(selectedNavIndex: index);
  }

  Future<void> fetchUnreadNotifications(String userId) async {
    try {
      final int uid = int.tryParse(userId) ?? 0;
      final notifications =
          await NotificationService().getNotifications(uid.toString());
      final int unread = notifications.where((n) => n['sendApp'] == 1).length;
      state = state.copyWith(unreadNotifications: unread);
    } catch (_) {
      // Ignorar errores de red temporales
    }
  }

  void updateSearch(String query) {
    state = state.copyWith(searchQuery: query.trim());
  }

  void clearSearch() {
    state = state.copyWith(searchQuery: '');
  }

  void setGpsActive(bool active) {
    state = state.copyWith(isGpsActive: active);
  }

  void setUnreadNotifications(int count) {
    state = state.copyWith(unreadNotifications: count);
  }

  Future<void> refreshHome(String userId) async {
    state = state.copyWith(isRefreshing: true);
    await fetchUnreadNotifications(userId);
    await Future.delayed(const Duration(milliseconds: 600));
    state = state.copyWith(isRefreshing: false);
  }
}
