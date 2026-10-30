import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mark_v3/pages/CentroAtencion_/centro_atencion_service.dart';
import 'package:mark_v3/pages/MaintenancePage.dart';
import 'package:mark_v3/pages/MyVehicle_/MyVehiclePage.dart';
import 'package:mark_v3/pages/Vehicles_/CreditPage.dart';
import 'package:mark_v3/pages/Vehicles_/InsurancePage.dart';
import 'package:mark_v3/pages/inspeccion/SeleccionPlantillasPage.dart';
import 'package:mark_v3/pages/tasks_page.dart';
import 'package:mark_v3/providers/Routes_/routes_provider.dart';
import 'package:mark_v3/services/mark_api_client.dart';
import 'package:mark_v3/widgets/app_skeleton.dart';
import 'package:mark_v3/widgets/apple_detail_row.dart';
import 'package:mark_v3/widgets/apple_empty_state.dart';
import 'package:mark_v3/widgets/loading_action_button.dart';

/// Pantalla ejecutiva del Centro de Atención bajo Apple Human Interface Guidelines.
/// Agrupa y visualiza todas las situaciones de Documentos, Inspecciones, Mantenimientos
/// y Tareas pendientes, con filtros reactivos, búsqueda, skeleton y diseño idéntico
/// al patrón oficial de la app.
class CentroAtencionPage extends ConsumerStatefulWidget {
  final String userId;
  final String idCollaborator;
  final String idMainAccount;

  const CentroAtencionPage({
    super.key,
    required this.userId,
    required this.idCollaborator,
    required this.idMainAccount,
  });

  @override
  ConsumerState<CentroAtencionPage> createState() => _CentroAtencionPageState();
}

class _CentroAtencionPageState extends ConsumerState<CentroAtencionPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode(skipTraversal: true);

  bool _cargando = true;
  String _filtroActivo = 'todos'; // 'todos', 'urgentes', 'por_vencer', 'pendientes'
  String _searchQuery = '';
  CentroAtencionDataResult? _data;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _cargar();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _cargar({bool isRefresh = false}) async {
    if (!isRefresh) {
      setState(() => _cargando = true);
    }

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
        setState(() {
          _cargando = false;
        });
      }
    }
  }

  List<AlertaItem> get _itemsFiltrados {
    final todos = _data?.items ?? [];
    List<AlertaItem> lista;

    switch (_filtroActivo) {
      case 'urgentes':
        lista = todos.where((i) => i.nivel == AlertaNivel.urgente).toList();
        break;
      case 'por_vencer':
        lista = todos.where((i) => i.nivel == AlertaNivel.porVencer).toList();
        break;
      case 'pendientes':
        lista = todos.where((i) => i.nivel == AlertaNivel.pendiente).toList();
        break;
      default:
        lista = todos;
    }

    if (_searchQuery.trim().isEmpty) return lista;

    final query = _searchQuery.toLowerCase();
    return lista.where((item) {
      return item.titulo.toLowerCase().contains(query) ||
          item.subtitulo.toLowerCase().contains(query) ||
          item.statusDetail.toLowerCase().contains(query) ||
          item.unidad.toLowerCase().contains(query) ||
          item.categoria.displayName.toLowerCase().contains(query);
    }).toList();
  }

  // ── GESTIÓN DE ACCIONES POR ALERTA ─────────────────────────────
  Future<void> _resolverAlerta(AlertaItem item) async {
    final session = MarkApiClient.instance.currentSession;
    final veh = item.vehicleRaw ?? <String, dynamic>{};

    switch (item.categoria) {
      case AlertaCategoria.seguro:
        if (veh.isNotEmpty) {
          final canEdit = (session?.flota.can('seguro', 'editar') ?? true) ||
              (session?.flota.can('seguro', 'crear') ?? true);
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => InsurancePage(
                vehicle: veh,
                insurancePermission: canEdit ? '1' : '0',
                idMainAccount: widget.idMainAccount,
                userId: widget.userId,
              ),
            ),
          );
          _cargar(isRefresh: true);
          return;
        }
        break;

      case AlertaCategoria.credito:
        if (veh.isNotEmpty) {
          final canCredit = session?.flota.can('credito', 'ver') ?? true;
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => Creditpage(
                vehicle: veh,
                creditPermission: canCredit ? '1' : '0',
                idMainAccount: widget.idMainAccount,
                userId: widget.userId,
              ),
            ),
          );
          _cargar(isRefresh: true);
          return;
        }
        break;

      case AlertaCategoria.inspeccion:
        Vehicle? targetVehicle;
        if (veh.isNotEmpty) {
          targetVehicle = Vehicle.fromMap({
            'idVehic': veh['idVehic'] ?? veh['id'],
            'economico': veh['economico'] ?? '',
            'placas': veh['placas'] ?? '',
            'Status': 'Activo',
          });
        }
        if (targetVehicle != null) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SeleccionPlantillasPage(
                vehicle: targetVehicle!,
                userId: widget.userId,
                idCollaborator: widget.idCollaborator,
                idMainAccount: widget.idMainAccount.isNotEmpty
                    ? widget.idMainAccount
                    : (session?.usuario.idCuenta.toString() ?? ''),
              ),
            ),
          );
        } else {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MyVehiclePage(
                idMainAccount: widget.idMainAccount,
                idCollaborator: widget.idCollaborator,
                userId: widget.userId,
                inspectionsPermission:
                    (session?.flota.can('inspeccion', 'crear') ?? true) ? '1' : '0',
              ),
            ),
          );
        }
        _cargar(isRefresh: true);
        return;

      case AlertaCategoria.mantenimiento:
        if (veh.isNotEmpty) {
          final canService = session?.flota.can('servicios', 'crear') ?? true;
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MaintenancePage(
                vehicle: veh,
                canRegisterService: canService,
              ),
            ),
          );
          _cargar(isRefresh: true);
          return;
        }
        break;

      case AlertaCategoria.tarea:
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TasksPage()),
        );
        _cargar(isRefresh: true);
        return;

      case AlertaCategoria.documento:
        if (veh.isNotEmpty) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MyVehiclePage(
                idMainAccount: widget.idMainAccount,
                idCollaborator: widget.idCollaborator,
                userId: widget.userId,
                inspectionsPermission: '1',
              ),
            ),
          );
          _cargar(isRefresh: true);
          return;
        }
        break;
    }

    // Modal de detalle estilo Apple si no navega directamente
    _mostrarModalDetalle(item);
  }

  void _mostrarModalDetalle(AlertaItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AlertaDetalleSheet(
        item: item,
        onResolver: () {
          Navigator.pop(context);
          _resolverAlerta(item);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final clampedScaler = mediaQuery.textScaler.clamp(
      minScaleFactor: 0.85,
      maxScaleFactor: 1.15,
    );

    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: clampedScaler),
      child: Scaffold(
        // Fondo oficial estilo Apple Grouped Background
        backgroundColor: const Color(0xFFF2F4F7),
        body: SafeArea(
          bottom: false,
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            behavior: HitTestBehavior.translucent,
            child: RefreshIndicator(
              color: const Color(0xFF0284C7),
              onRefresh: () async {
                await _cargar(isRefresh: true);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. ENCABEZADO ESTILO APPLE
                    _buildHeader(context),
                    const SizedBox(height: 12),

                    // 2. BUSCADOR ESTILO APPLE (SIN BORDE)
                    _buildSearchBar(),
                    const SizedBox(height: 14),

                    if (_cargando)
                      _buildSkeleton()
                    else ...[
                      // 3. FILTROS SEGMENTADOS ESTILO CUSTODIA
                      _buildFiltrosSegmentados(),
                      const SizedBox(height: 14),

                      // 4. LISTA DE ALERTAS O EMPTY STATE
                      if (_itemsFiltrados.isEmpty)
                        _buildEmptyState()
                      else
                        ..._itemsFiltrados.map((item) => _buildAlertaCard(item)),
                    ],

                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── 1. HEADER ESTILO APPLE (SIN BOTÓN MANUAL DE REFRESCO) ────────
  Widget _buildHeader(BuildContext context) {
    final totalCount = _data?.total ?? 0;

    return Row(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.pop(context),
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
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
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
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pendientes',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                _cargando
                    ? 'Consultando estado de la flota...'
                    : '$totalCount situaci${totalCount == 1 ? 'ón que requiere' : 'ones que requieren'} atención',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── 2. BUSCADOR ESTILO APPLE (SIN BORDE) ─────────────────────────
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A1E34).withOpacity(0.035),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.search_rounded,
            color: Color(0xFF94A3B8),
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              cursorColor: const Color(0xFF0284C7),
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w500,
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: const InputDecoration(
                hintText: 'Buscar por documento, unidad o tarea...',
                hintStyle: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 9),
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
              child: Container(
                padding: const EdgeInsets.all(3.5),
                decoration: const BoxDecoration(
                  color: Color(0xFFE2E8F0),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded,
                    size: 12, color: Color(0xFF475569)),
              ),
            ),
        ],
      ),
    );
  }

  // ── 3. FILTROS SEGMENTADOS ESTILO CUSTODIA (IDENTICO A IMAGEN 1) ───
  Widget _buildFiltrosSegmentados() {
    final total = _data?.total ?? 0;
    final urgentes = _data?.urgentes ?? 0;
    final porVencer = _data?.porVencer ?? 0;
    final pendientes = _data?.pendientes ?? 0;

    final filtros = [
      ('todos', 'Todos', total, Icons.grid_view_rounded),
      ('urgentes', 'Urgentes', urgentes, Icons.error_outline_rounded),
      ('por_vencer', 'Por vencer', porVencer, Icons.schedule_rounded),
      ('pendientes', 'Pendientes', pendientes, Icons.info_outline_rounded),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: filtros.map((f) {
            final isSelected = _filtroActivo == f.$1;

            return GestureDetector(
              onTap: () {
                if (_filtroActivo != f.$1) {
                  setState(() => _filtroActivo = f.$1);
                }
              },
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      f.$4,
                      size: 15,
                      color: isSelected
                          ? const Color(0xFF0284C7)
                          : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${f.$2} (${f.$3})',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected
                            ? const Color(0xFF0F172A)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── 5. TARJETA DE ALERTA INDIVIDUAL (ESTILO APPLE HIG - AZUL Y BLANCO) ─
  Widget _buildAlertaCard(AlertaItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _resolverAlerta(item),
          child: Ink(
            padding: const EdgeInsets.all(13.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFFE2E8F0),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withOpacity(0.035),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                // Ícono Squircle de Categoría en Azul y Blanco (Sin fondos pasteles)
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0284C7).withOpacity(0.22),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      item.categoria.icon,
                      color: Colors.white,
                      size: 21,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Contenido central
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Fila: Título + Badge de nivel + Count
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              item.titulo,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.3,
                                height: 1.15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: item.nivel.color.withOpacity(0.35),
                                width: 0.9,
                              ),
                            ),
                            child: Text(
                              item.nivel.label,
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                color: item.nivel.color,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                          if (item.count > 1) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                '${item.count}',
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),

                      // Subtítulo (Unidad / Placa)
                      if (item.subtitulo.isNotEmpty)
                        Text(
                          item.subtitulo,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                      const SizedBox(height: 2),

                      // Detalle de Vencimiento / Estado (rojo si venció)
                      Text(
                        item.statusDetail,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: item.nivel == AlertaNivel.urgente
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: item.nivel == AlertaNivel.urgente
                              ? const Color(0xFFDC2626)
                              : item.nivel == AlertaNivel.porVencer
                                  ? const Color(0xFFD97706)
                                  : const Color(0xFF0284C7),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Chevron Apple
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Color(0xFFCBD5E1),
                  size: 13,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── SKELETON CON APP_SKELETON (Apple HIG) ────────────────────────
  Widget _buildSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Skeleton de Filtros Segmentados
        Container(
          height: 44,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: const [
              Expanded(
                child: AppShimmerBox(
                  width: double.infinity,
                  height: 36,
                  borderRadius: 11,
                ),
              ),
              SizedBox(width: 6),
              Expanded(
                child: AppShimmerBox(
                  width: double.infinity,
                  height: 36,
                  borderRadius: 11,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Skeleton de Tarjetas
        ...List.generate(4, (index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const AppShimmerBox(width: 44, height: 44, borderRadius: 14),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      AppShimmerBox.text(width: 150, height: 13),
                      SizedBox(height: 6),
                      AppShimmerBox.text(width: 190, height: 11),
                      SizedBox(height: 4),
                      AppShimmerBox.text(width: 110, height: 10),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const AppShimmerBox(width: 14, height: 14, borderRadius: 7),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ── ESTADO VACÍO CON APPLE_EMPTY_STATE ───────────────────────────
  Widget _buildEmptyState() {
    return const AppleEmptyState(
      icon: Icons.check_circle_rounded,
      title: 'Todo al corriente',
      description:
          'No se encontraron situaciones pendientes con el filtro actual.',
      iconColor: Color(0xFF10B981),
      iconBgColor: Color(0xFFECFDF5),
    );
  }
}

// ── BOTTOM SHEET DETALLE DE ALERTA (APPLE DESIGN) ──────────────────
class _AlertaDetalleSheet extends StatelessWidget {
  final AlertaItem item;
  final VoidCallback onResolver;

  const _AlertaDetalleSheet({
    required this.item,
    required this.onResolver,
  });

  @override
  Widget build(BuildContext context) {
    String actionLabel = 'Gestionar';
    switch (item.categoria) {
      case AlertaCategoria.seguro:
        actionLabel = 'Ver Póliza de Seguro';
        break;
      case AlertaCategoria.credito:
        actionLabel = 'Ver Detalle de Crédito';
        break;
      case AlertaCategoria.inspeccion:
        actionLabel = 'Comenzar Inspección';
        break;
      case AlertaCategoria.mantenimiento:
        actionLabel = 'Ver Mantenimiento';
        break;
      case AlertaCategoria.tarea:
        actionLabel = 'Ir a la Tarea';
        break;
      case AlertaCategoria.documento:
        actionLabel = 'Ver Documentación';
        break;
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4.5,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Encabezado del sheet
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0284C7).withOpacity(0.22),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    item.categoria.icon,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.titulo,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.categoria.displayName,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: item.nivel.color.withOpacity(0.35)),
                ),
                child: Text(
                  item.nivel.label,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: item.nivel.color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Detalles usando AppleDetailRow
          if (item.subtitulo.isNotEmpty) ...[
            AppleDetailRow(
              icon: Icons.directions_car_rounded,
              label: 'Unidad / Asignado',
              value: item.subtitulo,
            ),
            const SizedBox(height: 8),
          ],
          AppleDetailRow(
            icon: Icons.info_outline_rounded,
            label: 'Estado actual',
            value: item.statusDetail,
            isHighlight: item.nivel == AlertaNivel.urgente,
            highlightColor: item.nivel.color,
          ),
          const SizedBox(height: 8),
          AppleDetailRow(
            icon: Icons.category_rounded,
            label: 'Categoría',
            value: item.categoria.displayName,
          ),

          const SizedBox(height: 24),

          // Botón de acción con LoadingActionButton (Azul Custodia)
          LoadingActionButton(
            text: actionLabel,
            isLoading: false,
            onPressed: onResolver,
            icon: Icons.arrow_forward_rounded,
            backgroundColor: const Color(0xFF0284C7),
          ),
        ],
      ),
    );
  }
}
