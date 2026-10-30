import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mark_v3/pages/CentroAtencion_/centro_atencion_page.dart';
import 'package:mark_v3/pages/CentroAtencion_/centro_atencion_service.dart';
import 'package:mark_v3/providers/Routes_/routes_provider.dart';
import 'package:mark_v3/widgets/app_skeleton.dart';

/// Widget interactivo de Pendientes para el Home.
/// Implementado bajo Apple Human Interface Guidelines:
/// sin icono de notificación, tipografía limpia, sin truncamientos
/// y botón de acción rápida en la esquina superior derecha.
class CentroAtencionCard extends ConsumerStatefulWidget {
  final String userId;
  final String idCollaborator;
  final String idMainAccount;

  const CentroAtencionCard({
    super.key,
    required this.userId,
    required this.idCollaborator,
    required this.idMainAccount,
  });

  @override
  ConsumerState<CentroAtencionCard> createState() =>
      _CentroAtencionCardState();
}

class _CentroAtencionCardState extends ConsumerState<CentroAtencionCard> {
  bool _cargando = true;
  CentroAtencionDataResult? _data;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _cargar();
    });
  }

  Future<void> _cargar() async {
    if (!mounted) return;
    setState(() => _cargando = true);

    try {
      final routesState = ref.read(routesProvider);
      final rutas = routesState.dayPackage?.rutas ?? const [];
      final activeRoute = rutas.where((r) => r.isActiva).firstOrNull ??
          rutas.where((r) => !r.isFinalizada).firstOrNull ??
          rutas.firstOrNull;
      final int? activeVehicId = activeRoute?.vehiculo?.id;

      final res = await CentroAtencionService.instance.fetchAlertas(
        activeVehicleId: activeVehicId,
      );

      if (mounted) {
        setState(() {
          _data = res;
          _cargando = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  void _abrirCentro() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CentroAtencionPage(
          userId: widget.userId,
          idCollaborator: widget.idCollaborator,
          idMainAccount: widget.idMainAccount,
        ),
      ),
    ).then((_) => _cargar());
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return _buildSkeleton();
    }

    final data = _data;
    if (data == null || data.total == 0) {
      return const SizedBox.shrink();
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _abrirCentro,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFE2E8F0),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withOpacity(0.035),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── ENCABEZADO APPLE (SIN ICONO DE CAMPANA) ─────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Pendientes',
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7.5, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                '${data.total}',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: data.urgentes > 0
                                      ? const Color(0xFFEF4444)
                                      : const Color(0xFF0284C7),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Situaciones que requieren tu atención',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Botón circular estilo Apple con flecha
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 0.9,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.arrow_outward_rounded,
                        size: 14,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── 3 STAT CHIPS VERTICALES (SIN FONDOS PASTELES) ───────
              Row(
                children: [
                  _HomeStatChip(
                    icon: Icons.error_outline_rounded,
                    label: 'Urgentes',
                    count: data.urgentes,
                    color: const Color(0xFFEF4444),
                  ),
                  const SizedBox(width: 8),
                  _HomeStatChip(
                    icon: Icons.schedule_rounded,
                    label: 'Por vencer',
                    count: data.porVencer,
                    color: const Color(0xFFF59E0B),
                  ),
                  const SizedBox(width: 8),
                  _HomeStatChip(
                    icon: Icons.info_outline_rounded,
                    label: 'Pendientes',
                    count: data.pendientes,
                    color: const Color(0xFF0284C7),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── PIE DE ACCIÓN (VER TODOS LOS PENDIENTES) ─────────────
              Container(
                padding: const EdgeInsets.only(top: 9),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Color(0xFFF1F5F9), width: 1.0),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Ver todos los pendientes',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0284C7),
                        letterSpacing: -0.1,
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 13,
                      color: Color(0xFF0284C7),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── SKELETON CON APP_SKELETON (Apple HIG) ────────────────────────
  Widget _buildSkeleton() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  AppShimmerBox.text(width: 120, height: 16),
                  SizedBox(height: 5),
                  AppShimmerBox.text(width: 200, height: 11),
                ],
              ),
              const AppShimmerBox(width: 28, height: 28, borderRadius: 14),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: const [
              Expanded(child: AppShimmerBox(height: 58, borderRadius: 14)),
              SizedBox(width: 8),
              Expanded(child: AppShimmerBox(height: 58, borderRadius: 14)),
              SizedBox(width: 8),
              Expanded(child: AppShimmerBox(height: 58, borderRadius: 14)),
            ],
          ),
          const SizedBox(height: 12),
          const AppShimmerBox.text(width: 150, height: 12),
        ],
      ),
    );
  }
}

class _HomeStatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;

  const _HomeStatChip({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 0.9),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 13.5),
                const SizedBox(width: 5),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: color,
                    height: 1.0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
                letterSpacing: -0.1,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }
}
