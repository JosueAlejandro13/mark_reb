import 'package:flutter_riverpod/flutter_riverpod.dart';

// Estado inmutable de la vista Home
class HomeState {
  final String searchQuery;
  final bool isGpsActive;
  final bool isRefreshing;
  final int unreadNotifications;
  final String activeZone;
  final String transmissionStatus;

  const HomeState({
    this.searchQuery = '',
    this.isGpsActive = true,
    this.isRefreshing = false,
    this.unreadNotifications = 0,
    this.activeZone = 'Zona Asignada',
    this.transmissionStatus = 'En línea',
  });

  HomeState copyWith({
    String? searchQuery,
    bool? isGpsActive,
    bool? isRefreshing,
    int? unreadNotifications,
    String? activeZone,
    String? transmissionStatus,
  }) {
    return HomeState(
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
    await Future.delayed(const Duration(milliseconds: 600));
    state = state.copyWith(isRefreshing: false);
  }
}
