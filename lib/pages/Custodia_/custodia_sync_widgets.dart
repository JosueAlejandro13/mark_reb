import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mark_v3/providers/Custodia_/custodia_provider.dart';

/// Barra de sincronización estilo Apple Design para Custodia y Rondines.
/// Idéntica en interfaz y comportamiento a la barra de sincronización de rutas.
class CustodiaSyncStatusBar extends ConsumerStatefulWidget {
  final bool alwaysShow;
  final EdgeInsetsGeometry? padding;
  const CustodiaSyncStatusBar({
    super.key,
    this.alwaysShow = false,
    this.padding,
  });

  @override
  ConsumerState<CustodiaSyncStatusBar> createState() =>
      _CustodiaSyncStatusBarState();
}

class _CustodiaSyncStatusBarState extends ConsumerState<CustodiaSyncStatusBar> {
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
    ref.listen<CustodiaState>(custodiaProvider, (previous, next) {
      if (previous != null &&
          previous.isSyncing &&
          !next.isSyncing &&
          next.isOnline &&
          next.pendingActionsCount == 0 &&
          next.rejectedActions.isEmpty) {
        _triggerSuccessTemporarily();
      }
    });

    final state = ref.watch(custodiaProvider);
    final isOnline = state.isOnline;
    final isSyncing = state.isSyncing;
    final pendingCount = state.pendingActionsCount;
    final rejectedCount = state.rejectedActions.length;

    final bool shouldShow = widget.alwaysShow ||
        !isOnline ||
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
      padding: widget.padding ?? const EdgeInsets.only(bottom: 8),
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
                      builder: (_) => const CustodiaRejectedActionsSheet(),
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
                              .read(custodiaProvider.notifier)
                              .syncCustodiaQueue(userInitiated: true);
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
      );
  }
}

/// Modal estilo Apple para revisar y descartar acciones rechazadas en Custodia
class CustodiaRejectedActionsSheet extends ConsumerWidget {
  const CustodiaRejectedActionsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(custodiaProvider);
    final rejected = state.rejectedActions;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFDC2626),
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Acciones pendientes de revisión',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Las siguientes acciones fueron rechazadas por el servidor y requieren tu atención.',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.45,
              ),
              child: rejected.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'No hay acciones rechazadas',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF94A3B8),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: rejected.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, idx) {
                        final act = rejected[idx];
                        final rawAvisos = act.avisos;
                        final String errorText = rawAvisos.isNotEmpty
                            ? rawAvisos.map((a) => a.texto).join('\n')
                            : 'Acción rechazada por el servidor';

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFFFECDD3),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    act.tipo.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFFDC2626),
                                    ),
                                  ),
                                  const Spacer(),
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(50, 24),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    onPressed: () async {
                                      await ref
                                          .read(custodiaProvider.notifier)
                                          .dismissRejectedAction(act.uuid);
                                    },
                                    child: const Text(
                                      'Descartar',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFFDC2626),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                errorText,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF991B1B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
