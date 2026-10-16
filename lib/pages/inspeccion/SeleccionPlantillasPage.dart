import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mark_v3/models/Vehicles_/vehicle_model.dart';
import 'package:mark_v3/pages/Error_/ConnectionErrorPage.dart';
import 'package:mark_v3/pages/Error_/InspError.dart';
import 'package:mark_v3/pages/Error_/ServerErrorPage.dart';
import 'package:mark_v3/pages/inspeccion/MyInspectVehiclePage.dart';
import 'package:mark_v3/providers/Inspeccion_/template_selection_provider.dart';
import 'package:mark_v3/widgets/snackbar_top.dart';
import 'package:mark_v3/widgets/vehicle_skeleton.dart';

/// Pantalla de Selección de Plantillas — Diseño Apple Inset Grouped Ejecutivo
class SeleccionPlantillasPage extends ConsumerStatefulWidget {
  final Vehicle vehicle;
  final String userId;
  final String idCollaborator;
  final String idMainAccount;

  const SeleccionPlantillasPage({
    super.key,
    required this.userId,
    required this.vehicle,
    required this.idCollaborator,
    required this.idMainAccount,
  });

  @override
  ConsumerState<SeleccionPlantillasPage> createState() =>
      _SeleccionPlantillasPageState();
}

class _SeleccionPlantillasPageState
    extends ConsumerState<SeleccionPlantillasPage> {
  bool _isSnackBarShown = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(templateSelectionProvider.notifier).loadTemplates(
            idMainAccount: widget.idMainAccount,
            vehicle: widget.vehicle,
          );
    });
  }

  void _onTemplateTap(PlantillaItem item) async {
    if (item.isReady) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MyInspectVehiclePage(
            vehicle: widget.vehicle,
            plantillaId: item.id,
            userId: widget.idMainAccount,
            idCollaborator: widget.idCollaborator,
            enableStorePhoto: item.enableStorePhoto,
            idMainAccount: widget.idMainAccount,
          ),
        ),
      );

      if (result == true && mounted) {
        ref.read(templateSelectionProvider.notifier).loadTemplates(
              idMainAccount: widget.idMainAccount,
              vehicle: widget.vehicle,
            );
      }
    } else {
      if (_isSnackBarShown) return;
      _isSnackBarShown = true;

      final diasText = item.daysRemaining == 1
          ? 'Falta 1 día'
          : 'Faltan ${item.daysRemaining} días';

      SnackbarTop.showInfo(
        context,
        "No se puede crear una nueva inspección aún. $diasText para la próxima revisión.",
        title: "Inspección en espera",
      );

      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          _isSnackBarShown = false;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(templateSelectionProvider);

    // Manejo de errores de red / servidor / sin inspecciones
    if (state.isConnectionError) {
      return ConnectionErrorPage(
        onRetry: () => ref
            .read(templateSelectionProvider.notifier)
            .loadTemplates(
                idMainAccount: widget.idMainAccount, vehicle: widget.vehicle),
      );
    }

    if (state.isServerError) {
      return ServerErrorPage(
        onRetry: () => ref
            .read(templateSelectionProvider.notifier)
            .loadTemplates(
                idMainAccount: widget.idMainAccount, vehicle: widget.vehicle),
      );
    }

    if (state.isInspError) {
      return InspError(
        onRetry: () => ref
            .read(templateSelectionProvider.notifier)
            .loadTemplates(
                idMainAccount: widget.idMainAccount, vehicle: widget.vehicle),
      );
    }

    final mediaQuery = MediaQuery.of(context);
    final clampedScaler = mediaQuery.textScaler.clamp(
      minScaleFactor: 0.85,
      maxScaleFactor: 1.15,
    );
    final isSmallScreen = mediaQuery.size.width < 360;

    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: clampedScaler),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          child: state.isLoading
              ? const SeleccionPlantillasSkeleton()
              : RefreshIndicator(
                  color: const Color(0xFF0284C7),
                  backgroundColor: Colors.white,
                  onRefresh: () => ref
                      .read(templateSelectionProvider.notifier)
                      .refresh(
                          idMainAccount: widget.idMainAccount,
                          vehicle: widget.vehicle),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 14.0 : 18.0,
                      vertical: 10.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── 1. Encabezado Apple ─────────────────────────────
                        _buildAnimatedItem(_buildAppleHeader(context), 0),
                        const SizedBox(height: 16),

                        // ── 2. Título de Sección ────────────────────────────
                        _buildAnimatedItem(
                          _buildSectionTitle('PLANTILLAS DISPONIBLES'),
                          1,
                        ),
                        const SizedBox(height: 8),

                        // ── 3. Lista de Plantillas o Estado Vacío ───────────
                        if (state.plantillas.isEmpty)
                          _buildAnimatedItem(_buildEmptyState(), 2)
                        else
                          ...state.plantillas.asMap().entries.map((entry) {
                            final index = entry.key;
                            final item = entry.value;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildAnimatedItem(
                                _buildTemplateCard(item),
                                2 + index,
                              ),
                            );
                          }),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  // ── ENCABEZADO APPLE DESIGN (SIN SOMBRAS) ──────────────────────────────────
  Widget _buildAppleHeader(BuildContext context) {
    return Row(
      children: [
        if (Navigator.canPop(context))
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.maybePop(context),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                    width: 1.0,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Color(0xFF0F172A),
                    size: 15,
                  ),
                ),
              ),
            ),
          ),
        if (Navigator.canPop(context)) const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Plantillas de Inspección',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 1),
              Text(
                'Selecciona una plantilla para iniciar la verificación',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── TÍTULO DE SECCIÓN INSET GROUPED ─────────────────────────────────────────
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: Color(0xFF64748B),
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  // ── TARJETA DE CADA PLANTILLA (APPLE DESIGN PREMIUM) ────────────────────────
  Widget _buildTemplateCard(PlantillaItem item) {
    final isReady = item.isReady;
    final statusColor =
        isReady ? const Color(0xFF059669) : const Color(0xFFB45309);
    final statusBg =
        isReady ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB);
    final statusBorder =
        isReady ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A);

    final statusText = isReady
        ? 'Listo para realizar'
        : 'Faltan ${item.daysRemaining} ${item.daysRemaining == 1 ? "día" : "días"}';

    // Manejo de descripción con fallback elegante para evitar sensación de vacío
    final rawDesc = item.description.trim();
    final hasCustomDesc = rawDesc.isNotEmpty &&
        rawDesc.toLowerCase() != 'sin descripción' &&
        rawDesc.toLowerCase() != 'null';
    final displayDesc = hasCustomDesc
        ? rawDesc
        : 'Formato estándar de inspección y control de componentes del vehículo.';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _onTemplateTap(item),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 1. Encabezado: Squircle Icon + Info + Badge de Estado ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icono en Squircle Apple (Degradado Premium)
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isReady
                              ? const [Color(0xFF0284C7), Color(0xFF0369A1)]
                              : const [Color(0xFF64748B), Color(0xFF475569)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(13),
                        boxShadow: [
                          BoxShadow(
                            color: isReady
                                ? const Color(0xFF0284C7).withOpacity(0.28)
                                : const Color(0xFF64748B).withOpacity(0.28),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          isReady
                              ? Icons.fact_check_rounded
                              : Icons.schedule_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Título y Tipo
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Formato de inspección',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Badge de Estado Apple Capsule
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4.5),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── 2. Caja de Descripción estructurada ─────────────────────
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFF1F5F9),
                      width: 1.0,
                    ),
                  ),
                  child: Text(
                    displayDesc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: hasCustomDesc
                          ? const Color(0xFF475569)
                          : const Color(0xFF64748B),
                      fontStyle:
                          hasCustomDesc ? FontStyle.normal : FontStyle.italic,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ── 3. Metadatos Informáticos Apple (Dual Inset Boxes) ───────
                Row(
                  children: [
                    // Frecuencia
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_month_rounded,
                              size: 16,
                              color: Color(0xFF0284C7),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'FRECUENCIA',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF94A3B8),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    item.periodicity == 0
                                        ? 'Bajo demanda'
                                        : 'Cada ${item.periodicity} ${item.periodicity == 1 ? "día" : "días"}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Evidencia fotográfica
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              item.enableStorePhoto == 1
                                  ? Icons.photo_camera_rounded
                                  : Icons.fact_check_outlined,
                              size: 16,
                              color: item.enableStorePhoto == 1
                                  ? const Color(0xFF0284C7)
                                  : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'EVIDENCIA',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF94A3B8),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    item.enableStorePhoto == 1
                                        ? 'Fotos requeridas'
                                        : 'Checklist simple',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // ── 4. Botón de Acción Grande Estilo Apple ───────────────────
                if (isReady)
                  Container(
                    width: double.infinity,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x330284C7),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Iniciar Inspección',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.2,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.lock_rounded,
                          color: Color(0xFF94A3B8),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Próxima revisión en ${item.daysRemaining} ${item.daysRemaining == 1 ? "día" : "días"}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── ESTADO VACÍO ESTILO APPLE ───────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.assignment_outlined,
            size: 48,
            color: Color(0xFF94A3B8),
          ),
          const SizedBox(height: 16),
          const Text(
            'No hay plantillas disponibles',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'No se encontraron formatos de inspección configurados para este vehículo.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: () => ref
                .read(templateSelectionProvider.notifier)
                .loadTemplates(
                    idMainAccount: widget.idMainAccount,
                    vehicle: widget.vehicle),
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text(
              'Recargar',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── ANIMACIÓN STAGGERED ESTILO APPLE ────────────────────────────────────────
  Widget _buildAnimatedItem(Widget child, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 260 + (index * 35)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 10 * (1.0 - value)),
          child: Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
