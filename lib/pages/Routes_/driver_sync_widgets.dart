import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mark_v3/pages/Routes_/cedi_warehouse_page.dart';
import 'package:mark_v3/providers/Routes_/routes_provider.dart';

/// Píldora de estado de red (En línea / Sin señal) para el AppBar o cabecera de chofer estilo Apple
class DriverOnlinePill extends ConsumerWidget {
  const DriverOnlinePill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(routesProvider.select((s) => s.isOnline));
    final isSyncing = ref.watch(routesProvider.select((s) => s.isSyncing));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: isSyncing
            ? null
            : () =>
                ref.read(routesProvider.notifier).syncPendingQueueAndRefreshDay(
                      forceRefreshDay: true,
                      isUserInitiated: true,
                    ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isOnline ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color:
                  isOnline ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA),
              width: 0.9,
            ),
            boxShadow: [
              BoxShadow(
                color: (isOnline
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444))
                    .withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSyncing)
                const SizedBox(
                  width: 11,
                  height: 11,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    color: Color(0xFF059669),
                  ),
                )
              else
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: isOnline
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (isOnline
                                ? const Color(0xFF10B981)
                                : const Color(0xFFEF4444))
                            .withOpacity(0.4),
                        blurRadius: 4,
                        spreadRadius: 0.5,
                      ),
                    ],
                  ),
                ),
              const SizedBox(width: 5.5),
              Text(
                isOnline ? 'En línea' : 'Sin señal',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isOnline
                      ? const Color(0xFF065F46)
                      : const Color(0xFF991B1B),
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Barra de estado inferior estilo Apple Design (Cápsula flotante minimalista).
/// Se muestra automáticamente si:
/// - No hay conexión a internet (!isOnline)
/// - Hay acciones o fotos pendientes en la cola local (pendingCount > 0)
/// - Hay acciones rechazadas que requieren revisión (rejectedCount > 0)
/// - Se está realizando una sincronización manual o automática (isSyncing)
/// - Recién finalizó una sincronización (visible durante 4 segundos de confirmación)
/// En estado normal (en línea y 0 pendientes), se oculta suavemente.
class DriverSyncStatusBar extends ConsumerStatefulWidget {
  const DriverSyncStatusBar({super.key});

  @override
  ConsumerState<DriverSyncStatusBar> createState() =>
      _DriverSyncStatusBarState();
}

class _DriverSyncStatusBarState extends ConsumerState<DriverSyncStatusBar> {
  bool _showSuccessTemporarily = false;
  Timer? _hideTimer;

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _triggerSuccessTemporarily() {
    _hideTimer?.cancel();
    if (mounted) {
      setState(() {
        _showSuccessTemporarily = true;
      });
    }
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _showSuccessTemporarily = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<RoutesState>(routesProvider, (previous, next) {
      if (previous != null &&
          previous.isSyncing &&
          !next.isSyncing &&
          next.isOnline &&
          next.totalPendingSyncCount == 0 &&
          next.rejectedActions.isEmpty) {
        _triggerSuccessTemporarily();
      }
    });

    final state = ref.watch(routesProvider);
    final isOnline = state.isOnline;
    final isSyncing = state.isSyncing;
    final pendingCount = state.totalPendingSyncCount;
    final rejectedCount = state.rejectedActions.length;

    // Reglas de visibilidad condicional
    final bool shouldShow = !isOnline ||
        pendingCount > 0 ||
        rejectedCount > 0 ||
        isSyncing ||
        _showSuccessTemporarily;

    if (!shouldShow) {
      return const SizedBox.shrink();
    }

    final Color badgeBgColor;
    final Color? badgeBorderColor;
    final Widget iconWidget;
    final String titleText;
    final String? pillText;
    final Color? pillBgColor;
    final Color? pillTextColor;
    final List<BoxShadow>? pillShadow;
    final String subtitleText;
    final Color subtitleColor;
    final Color syncButtonBg;
    final Color syncButtonIconColor;

    if (isSyncing) {
      badgeBgColor = const Color(0xFFEFF6FF);
      badgeBorderColor = const Color(0xFFBFDBFE);
      iconWidget = const SizedBox(
        width: 15,
        height: 15,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          color: Color(0xFF0284C7),
        ),
      );
      titleText = 'Sincronizando';
      pillText = pendingCount > 0 ? '$pendingCount en cola' : 'Enviando';
      pillBgColor = const Color(0xFFDBEAFE);
      pillTextColor = const Color(0xFF0284C7);
      pillShadow = null;
      subtitleText = state.lastSyncTime != null
          ? 'Última: ${state.lastSyncTime}'
          : 'Subiendo cambios al servidor';
      subtitleColor = const Color(0xFF0284C7);
      syncButtonBg = const Color(0xFFF8FAFC);
      syncButtonIconColor = const Color(0xFF94A3B8);
    } else if (pendingCount > 0) {
      // ESTADO DESTACADO: PENDIENTES POR SUBIR (Estilo Apple con badge resaltado)
      badgeBgColor = const Color(0xFFFFEDD5);
      badgeBorderColor = const Color(0xFFFDBA74);
      iconWidget = const Icon(
        Icons.cloud_upload_rounded,
        size: 19,
        color: Color(0xFFEA580C),
      );
      titleText = !isOnline ? 'Sin señal' : 'Por enviar';
      pillText = pendingCount == 1 ? '1 por subir' : '$pendingCount por subir';
      pillBgColor = const Color(0xFFEA580C);
      pillTextColor = Colors.white;
      pillShadow = [
        BoxShadow(
          color: const Color(0xFFEA580C).withOpacity(0.35),
          blurRadius: 5,
          offset: const Offset(0, 1.5),
        ),
      ];
      subtitleText = !isOnline
          ? 'Guardado en el equipo · Se subirá con red'
          : 'Listo para subir · Toca para sincronizar';
      subtitleColor = const Color(0xFFC2410C);
      syncButtonBg = const Color(0xFFFFF7ED);
      syncButtonIconColor = const Color(0xFFEA580C);
    } else if (!isOnline) {
      badgeBgColor = const Color(0xFFFFF7ED);
      badgeBorderColor = const Color(0xFFFED7AA);
      iconWidget = const Icon(
        Icons.cloud_rounded,
        size: 18,
        color: Color(0xFFEA580C),
      );
      titleText = 'Sin señal';
      pillText = 'Modo local';
      pillBgColor = const Color(0xFFF1F5F9);
      pillTextColor = const Color(0xFF64748B);
      pillShadow = null;
      subtitleText = 'Los registros se guardarán en el celular';
      subtitleColor = const Color(0xFF64748B);
      syncButtonBg = const Color(0xFFF8FAFC);
      syncButtonIconColor = const Color(0xFFEA580C);
    } else {
      // Sincronizado con éxito
      badgeBgColor = const Color(0xFFECFDF5);
      badgeBorderColor = const Color(0xFFA7F3D0);
      iconWidget = const Icon(
        Icons.cloud_done_rounded,
        size: 18,
        color: Color(0xFF059669),
      );
      titleText = 'Sincronizado';
      pillText = 'Al día';
      pillBgColor = const Color(0xFFD1FAE5);
      pillTextColor = const Color(0xFF047857);
      pillShadow = null;
      subtitleText = state.lastSyncTime != null
          ? 'Última: ${state.lastSyncTime}'
          : 'Todo al día';
      subtitleColor = const Color(0xFF059669);
      syncButtonBg = const Color(0xFFF8FAFC);
      syncButtonIconColor = const Color(0xFF059669);
    }

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 10, top: 2),
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: const Color(0xFFE2E8F0),
              width: 0.9,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withOpacity(0.06),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: const Color(0xFF0F172A).withOpacity(0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            children: [
              // 1. Icono con fondo circular sutil Apple
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: badgeBgColor,
                  shape: BoxShape.circle,
                  border: badgeBorderColor != null
                      ? Border.all(color: badgeBorderColor, width: 1.0)
                      : null,
                ),
                child: Center(child: iconWidget),
              ),
              const SizedBox(width: 10),

              // 2. Textos (Título + Badge Pill + Subtítulo)
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          titleText,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.2,
                            height: 1.15,
                          ),
                        ),
                        if (pillText != null) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: pillBgColor,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: pillShadow,
                              ),
                              child: Text(
                                pillText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: pillTextColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 1.5),
                    Text(
                      subtitleText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: subtitleColor,
                        letterSpacing: -0.1,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),

              // 3. Botón de errores rechazados (si hubiese)
              if (rejectedCount > 0) ...[
                const SizedBox(width: 6),
                InkWell(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const RejectedActionsSheet(),
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: Color(0xFFDC2626),
                          size: 13,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'Revisar ($rejectedCount)',
                          style: const TextStyle(
                            color: Color(0xFFDC2626),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(width: 8),

              // 4. Botón circular Apple de Recargar / Sincronizar
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: isSyncing
                      ? null
                      : () {
                          ref
                              .read(routesProvider.notifier)
                              .syncPendingQueueAndRefreshDay(
                                forceRefreshDay: true,
                                isUserInitiated: true,
                              );
                          _triggerSuccessTemporarily();
                        },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: syncButtonBg,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 0.8,
                      ),
                    ),
                    child: Center(
                      child: isSyncing
                          ? const SizedBox(
                              width: 13,
                              height: 13,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.8,
                                color: Color(0xFF0284C7),
                              ),
                            )
                          : Icon(
                              Icons.sync_rounded,
                              size: 17,
                              color: syncButtonIconColor,
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
