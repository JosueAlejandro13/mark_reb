import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mark_v3/pages/Error_/ConnectionErrorPage.dart';
import 'package:mark_v3/pages/Error_/ServerErrorPage.dart';
import 'package:mark_v3/pages/Error_/unexpectedErrorPage.dart';
import 'package:mark_v3/services/mark_api_client.dart';
import 'package:mark_v3/widgets/app_skeleton.dart';
import 'package:mark_v3/widgets/snackbar_top.dart';

String _formatPriorityLabel(dynamic val) {
  if (val == null) return 'Media';
  final s = val.toString().trim().toLowerCase();
  switch (s) {
    case '0':
    case 'ninguna':
    case 'ninguno':
      return 'Ninguna';
    case '1':
    case 'baja':
    case 'bajo':
      return 'Baja';
    case '2':
    case 'media':
    case 'medio':
    case 'normal':
      return 'Media';
    case '3':
    case 'alta':
    case 'alto':
      return 'Alta';
    case '4':
    case 'critico':
    case 'crítico':
    case 'critica':
    case 'crítica':
    case 'urgente':
      return 'Crítica';
    default:
      if (s.isNotEmpty) {
        return s[0].toUpperCase() + s.substring(1);
      }
      return 'Media';
  }
}

/// Pantalla de Gestión de Tareas de Flota con Apple Human Interface Guidelines
class TasksPage extends ConsumerStatefulWidget {
  final int? idVehic;
  final int? initialTaskId;

  const TasksPage({super.key, this.idVehic, this.initialTaskId});

  @override
  ConsumerState<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends ConsumerState<TasksPage> {
  final MarkApiClient _client = MarkApiClient.instance;

  String _filterEstado = 'abiertas'; // 'abiertas' | 'todas' | '2' | '3' | '5'
  String _filterMias = 'todas'; // 'todas' | 'asignadas'

  bool _isLoading = true;
  String? _errorMessage;
  Object? _lastError;
  List<Map<String, dynamic>> _tareas = [];

  bool _isNetworkError(Object? e) {
    if (e == null) return false;
    if (e is SocketException) return true;
    final msg = e.toString().toLowerCase();
    return msg.contains('socketexception') ||
        msg.contains('clientexception') ||
        msg.contains('failed host lookup') ||
        msg.contains('network is unreachable') ||
        msg.contains('software caused connection abort') ||
        msg.contains('connection refused') ||
        msg.contains('connection reset') ||
        msg.contains('connection closed') ||
        msg.contains('connection timeout') ||
        msg.contains('os error: network is unreachable') ||
        msg.contains('no address associated with hostname');
  }

  bool _isServerError(Object? e) {
    if (e == null) return false;
    if (e is TimeoutException) return true;
    final msg = e.toString().toLowerCase();
    return msg.contains('timeoutexception') ||
        msg.contains('500') ||
        msg.contains('502') ||
        msg.contains('503') ||
        msg.contains('504') ||
        msg.contains('error de servidor') ||
        msg.contains('server error') ||
        msg.contains('internal server error');
  }

  @override
  void initState() {
    super.initState();
    _loadTareas();
  }

  Future<void> _loadTareas() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _lastError = null;
    });

    try {
      final list = await _client.getTareas(
        estado: _filterEstado == 'todas' ? null : _filterEstado,
        mias: _filterMias == 'todas' ? null : _filterMias,
        idVehic: widget.idVehic,
      );

      if (mounted) {
        setState(() {
          _tareas = list;
          _isLoading = false;
        });

        if (widget.initialTaskId != null) {
          final matched = list.firstWhere(
            (t) =>
                (t['idTarea'] ?? t['id'])?.toString() ==
                widget.initialTaskId.toString(),
            orElse: () => <String, dynamic>{},
          );
          if (matched.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _showTaskDetailSheet(matched);
            });
          } else {
            _client.getTarea(widget.initialTaskId!).then((singleTask) {
              if (mounted && singleTask.isNotEmpty) {
                _showTaskDetailSheet(singleTask);
              }
            }).catchError((_) {});
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _lastError = e;
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _showTaskDetailSheet(Map<String, dynamic> item) async {
    final idTarea =
        int.tryParse((item['idTarea'] ?? item['id'] ?? '0').toString()) ?? 0;
    if (idTarea <= 0) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TaskDetailModal(
        taskSummary: item,
        idTarea: idTarea,
        onTaskUpdated: _loadTareas,
      ),
    );
  }

  void _showCreateTaskSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CreateTaskModal(
        idVehic: widget.idVehic,
        onTaskCreated: _loadTareas,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Si la carga falló, desplegar pantalla oficial de error (Conexión, Servidor o Inesperado)
    if (!_isLoading && _errorMessage != null) {
      if (_isNetworkError(_lastError ?? _errorMessage)) {
        return ConnectionErrorPage(onRetry: _loadTareas);
      } else if (_isServerError(_lastError ?? _errorMessage)) {
        return ServerErrorPage(onRetry: _loadTareas);
      } else {
        return Unexpectederrorpage(onRetry: _loadTareas);
      }
    }

    final mediaQuery = MediaQuery.of(context);
    final clampedScaler = mediaQuery.textScaler.clamp(
      minScaleFactor: 0.85,
      maxScaleFactor: 1.15,
    );

    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: clampedScaler),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF8FAFC),
          surfaceTintColor: Colors.transparent,
          foregroundColor: const Color(0xFF0F172A),
          elevation: 0,
          toolbarHeight: 64,
          leadingWidth: 54,
          titleSpacing: 12,
          leading: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.of(context).maybePop(),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
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
            ),
          ),
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tareas de Flota',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.4,
                ),
              ),
              SizedBox(height: 1),
              Text(
                'Gestión y seguimiento de actividades',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          actions: const [],
        ),
        // Botón flotante estilizado Apple (Pill flotante moderno con sombra suave)
        floatingActionButton: Container(
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0284C7).withOpacity(0.38),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: _showCreateTaskSheet,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_task_rounded, color: Colors.white, size: 19),
                    SizedBox(width: 8),
                    Text(
                      'Nueva Tarea',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Filtros Rápidos Segmentados Apple
              _buildFilterChipsBar(),

              // Contenido Principal con Pull-To-Refresh y Blindaje
              Expanded(
                child: _isLoading
                    ? AppSkeleton.tasks()
                    : RefreshIndicator(
                        onRefresh: _loadTareas,
                        color: const Color(0xFF0284C7),
                        backgroundColor: Colors.white,
                        displacement: 28,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 85),
                          itemCount: _tareas.isEmpty ? 1 : _tareas.length + 1,
                          itemBuilder: (context, i) {
                            // Tarjeta Hero Superior (Hasta arriba) como en Mantenimiento
                            if (i == 0) {
                              return _buildTasksHeroCard();
                            }

                            if (_tareas.isEmpty) {
                              return _buildEmptyState();
                            }

                            final t = _tareas[i - 1];
                            return _buildTaskCard(t);
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- TARJETA HERO SUPERIOR (HASTA ARRIBA) COMO EN MANTENIMIENTO ---
  Widget _buildTasksHeroCard() {
    final abiertas = _tareas.where((t) {
      final s = t['estado']?.toString();
      return s == '1' || s == 'abierta';
    }).length;

    final proceso = _tareas.where((t) {
      final s = t['estado']?.toString();
      return s == '2' || s == 'proceso';
    }).length;

    final resueltas = _tareas.where((t) {
      final s = t['estado']?.toString();
      return s == '3' || s == 'resuelta';
    }).length;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0284C7).withOpacity(0.24),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.assignment_turned_in_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Control de Tareas',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Actividades y órdenes de trabajo activas',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded,
                        size: 12, color: Color(0xFF059669)),
                    SizedBox(width: 4),
                    Text(
                      'Al día',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF047857),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildMiniMetricTile(
                icon: Icons.radio_button_unchecked_rounded,
                label: 'Abiertas',
                value: '$abiertas',
                color: const Color(0xFF0284C7),
              ),
              const SizedBox(width: 8),
              _buildMiniMetricTile(
                icon: Icons.pending_actions_rounded,
                label: 'En Proceso',
                value: '$proceso',
                color: const Color(0xFFD97706),
              ),
              const SizedBox(width: 8),
              _buildMiniMetricTile(
                icon: Icons.check_circle_outline_rounded,
                label: 'Resueltas',
                value: '$resueltas',
                color: const Color(0xFF059669),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetricTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- BARRA DE FILTROS RÁPIDOS APPLE CAPSULES ---
  Widget _buildFilterChipsBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _buildAppleFilterChip(
              label: 'Abiertas',
              isSelected: _filterEstado == 'abiertas',
              onTap: () {
                setState(() => _filterEstado = 'abiertas');
                _loadTareas();
              },
            ),
            const SizedBox(width: 8),
            _buildAppleFilterChip(
              label: 'En Proceso',
              isSelected: _filterEstado == '2',
              onTap: () {
                setState(() => _filterEstado = '2');
                _loadTareas();
              },
            ),
            const SizedBox(width: 8),
            _buildAppleFilterChip(
              label: 'Resueltas',
              isSelected: _filterEstado == '3',
              onTap: () {
                setState(() => _filterEstado = '3');
                _loadTareas();
              },
            ),
            const SizedBox(width: 8),
            _buildAppleFilterChip(
              label: 'Todas',
              isSelected: _filterEstado == 'todas',
              onTap: () {
                setState(() => _filterEstado = 'todas');
                _loadTareas();
              },
            ),
            const SizedBox(width: 10),
            Container(height: 18, width: 1, color: const Color(0xFFCBD5E1)),
            const SizedBox(width: 10),
            _buildAppleFilterChip(
              label: 'Asignadas a mí',
              isSelected: _filterMias == 'asignadas',
              icon: Icons.person_outline_rounded,
              onTap: () {
                setState(() => _filterMias =
                    _filterMias == 'asignadas' ? 'todas' : 'asignadas');
                _loadTareas();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppleFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0284C7) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                isSelected ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF0284C7).withOpacity(0.24),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 13,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- TARJETA DE TAREA BLINDADA CONTRA DESBORDAMIENTOS ---
  Widget _buildTaskCard(Map<String, dynamic> item) {
    final titulo = (item['titulo'] ?? item['title'] ?? 'Sin título').toString();
    final descripcion =
        (item['descripcion'] ?? item['description'] ?? '').toString();
    final prioridad = (item['prioridad'] ?? item['priority'] ?? '').toString();
    final estadoRaw = item['estado'];
    final estado = int.tryParse(estadoRaw.toString()) ??
        (estadoRaw == 'proceso'
            ? 2
            : estadoRaw == 'resuelta'
                ? 3
                : 1);
    final vence = (item['vence'] ?? item['fechaVence'] ?? '').toString();
    final vehiculoEco = (item['vehiculo'] ?? item['eco'] ?? '').toString();

    // Configuración según el paso del proceso
    final (statusLabel, statusColor, statusBg, statusStep, iconData) =
        switch (estado) {
      2 => (
          'Paso 2: En Proceso',
          const Color(0xFFD97706),
          const Color(0xFFFFFBEB),
          2,
          Icons.pending_actions_rounded
        ),
      3 => (
          'Paso 3: Resuelta',
          const Color(0xFF059669),
          const Color(0xFFECFDF5),
          3,
          Icons.check_circle_rounded
        ),
      5 => (
          'Cancelada',
          const Color(0xFFDC2626),
          const Color(0xFFFEF2F2),
          0,
          Icons.cancel_outlined
        ),
      _ => (
          'Paso 1: Abierta',
          const Color(0xFF0284C7),
          const Color(0xFFE0F2FE),
          1,
          Icons.radio_button_unchecked_rounded
        ),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _showTaskDetailSheet(item),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Fila Superior: Badges de Estado, Prioridad y Vehículo
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: statusBg,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(iconData, size: 12, color: statusColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    statusLabel,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: statusColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (prioridad.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              _buildPriorityBadge(prioridad),
                            ],
                            if (vehiculoEco.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 3.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.directions_car_rounded,
                                        size: 11, color: Color(0xFF0284C7)),
                                    const SizedBox(width: 4),
                                    Text(
                                      vehiculoEco,
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0284C7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Título de la tarea
                      Text(
                        titulo,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                      ),

                      // Descripción
                      if (descripcion.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          descripcion,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            height: 1.35,
                          ),
                        ),
                      ],

                      const SizedBox(height: 12),
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      const SizedBox(height: 10),

                      // Pipeline Visual de Proceso y Fecha
                      Row(
                        children: [
                          Expanded(
                            child: _buildMiniPipelineTrack(statusStep),
                          ),
                          if (vence.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.calendar_today_rounded,
                                  size: 11,
                                  color: Color(0xFF94A3B8),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  vence.length > 10
                                      ? vence.substring(0, 10)
                                      : vence,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: Color(0xFFCBD5E1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityBadge(String prioridadRaw) {
    final prioridad = _formatPriorityLabel(prioridadRaw);
    final lower = prioridad.toLowerCase();
    final (bg, color) = switch (lower) {
      'urgente' || 'crítica' || 'critica' => (
          const Color(0xFFFEE2E2),
          const Color(0xFFDC2626)
        ),
      'alta' => (const Color(0xFFFEF3C7), const Color(0xFFD97706)),
      'baja' => (const Color(0xFFF1F5F9), const Color(0xFF64748B)),
      'ninguna' => (const Color(0xFFF1F5F9), const Color(0xFF94A3B8)),
      _ => (const Color(0xFFE0F2FE), const Color(0xFF0284C7)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        prioridad,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  // Mini Stepper Track de progreso para la tarjeta
  Widget _buildMiniPipelineTrack(int currentStep) {
    if (currentStep == 0) {
      return const Text(
        'Cancelada',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
            fontSize: 10.5,
            color: Color(0xFFDC2626),
            fontWeight: FontWeight.w600),
      );
    }

    return Row(
      children: [
        _buildTrackDot(1, currentStep >= 1, currentStep == 1, '1. Abierta'),
        Expanded(
          child: Container(
            height: 2,
            color: currentStep >= 2
                ? const Color(0xFF0284C7)
                : const Color(0xFFE2E8F0),
          ),
        ),
        _buildTrackDot(2, currentStep >= 2, currentStep == 2, '2. En Proceso'),
        Expanded(
          child: Container(
            height: 2,
            color: currentStep >= 3
                ? const Color(0xFF059669)
                : const Color(0xFFE2E8F0),
          ),
        ),
        _buildTrackDot(3, currentStep >= 3, currentStep == 3, '3. Resuelta'),
      ],
    );
  }

  Widget _buildTrackDot(
      int step, bool isReached, bool isCurrent, String label) {
    final color = isCurrent
        ? (step == 3
            ? const Color(0xFF059669)
            : step == 2
                ? const Color(0xFFD97706)
                : const Color(0xFF0284C7))
        : isReached
            ? const Color(0xFF0284C7)
            : const Color(0xFFCBD5E1);

    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  // --- VISTA VACÍA ---
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
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
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Center(
                  child: Icon(
                    Icons.assignment_turned_in_outlined,
                    size: 28,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Sin tareas en esta categoría',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Todas las actividades de esta sección se encuentran al día.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Modal Bottom Sheet para Detalle y Avance de Tarea con Pipeline Apple Guiado y Blindado
class _TaskDetailModal extends StatefulWidget {
  final Map<String, dynamic> taskSummary;
  final int idTarea;
  final VoidCallback onTaskUpdated;

  const _TaskDetailModal({
    required this.taskSummary,
    required this.idTarea,
    required this.onTaskUpdated,
  });

  @override
  State<_TaskDetailModal> createState() => _TaskDetailModalState();
}

class _TaskDetailModalState extends State<_TaskDetailModal> {
  final MarkApiClient _client = MarkApiClient.instance;
  final TextEditingController _commentController = TextEditingController();

  bool _isLoading = true;
  bool _isSending = false;
  Map<String, dynamic>? _taskDetail;
  List<dynamic> _comentarios = [];

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _fetchDetail() async {
    setState(() => _isLoading = true);
    try {
      final res = await _client.getTarea(widget.idTarea);
      final tarea = res['tarea'] is Map<String, dynamic>
          ? res['tarea'] as Map<String, dynamic>
          : res;
      final comments = tarea['comentarios'] ?? res['comentarios'] ?? [];

      if (mounted) {
        setState(() {
          _taskDetail = tarea;
          _comentarios = comments is List ? comments : [];
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _taskDetail = widget.taskSummary;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateState(int nuevoEstado, {String? successMessage}) async {
    setState(() => _isSending = true);
    try {
      final action = {
        'uuid': const Uuid().v4(),
        'tipo': 'tareaEstado',
        'idTarea': widget.idTarea,
        'estado': nuevoEstado,
        'fecHor': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
      };

      await _client.sendActions([action]);
      widget.onTaskUpdated();
      await _fetchDetail();
      if (mounted) {
        SnackbarTop.showSuccess(
          context,
          successMessage ?? 'Estado de la tarea actualizado con éxito.',
        );
      }
    } catch (e) {
      if (mounted) {
        SnackbarTop.showError(context, 'No se pudo actualizar el estado: $e');
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);
    try {
      final action = {
        'uuid': const Uuid().v4(),
        'tipo': 'tareaComentario',
        'idTarea': widget.idTarea,
        'texto': text,
        'fecHor': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
      };

      await _client.sendActions([action]);
      _commentController.clear();
      await _fetchDetail();
      if (mounted) {
        SnackbarTop.showSuccess(context, 'Comentario agregado.');
      }
    } catch (e) {
      if (mounted) {
        SnackbarTop.showError(context, 'Error al comentar: $e');
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showStateOptionsDialog(int currentEstado) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            MediaQuery.of(ctx).padding.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Indicador superior / drag handle
              Center(
                child: Container(
                  width: 38,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Encabezado con Icono, Título y Subtítulo
              Row(
                children: [
                  const Icon(
                    Icons.swap_horiz_rounded,
                    color: Color(0xFF0284C7),
                    size: 26,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Opciones de Estado',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Mover actividad a otra fase del flujo de trabajo',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 14),

              // Opciones interactivas con diseño de tarjeta Apple HIG
              if (currentEstado != 1)
                _buildStateOptionCard(
                  stepLabel: 'Paso 1',
                  title: 'Mover a Abierta',
                  description: 'Reabrir tarea para asignación o seguimiento',
                  icon: Icons.radio_button_unchecked_rounded,
                  accentColor: const Color(0xFF0284C7),
                  backgroundColor: const Color(0xFFF0F9FF),
                  borderColor: const Color(0xFFBAE6FD),
                  onTap: () {
                    Navigator.pop(ctx);
                    _updateState(1,
                        successMessage: 'Tarea reabierta (Paso 1: Abierta).');
                  },
                ),

              if (currentEstado != 2)
                _buildStateOptionCard(
                  stepLabel: 'Paso 2',
                  title: 'Mover a En Proceso',
                  description: 'Marcar como trabajo actualmente en ejecución',
                  icon: Icons.pending_actions_rounded,
                  accentColor: const Color(0xFFD97706),
                  backgroundColor: const Color(0xFFFFFBEB),
                  borderColor: const Color(0xFFFDE68A),
                  onTap: () {
                    Navigator.pop(ctx);
                    _updateState(2,
                        successMessage: 'Tarea iniciada (Paso 2: En Proceso).');
                  },
                ),

              if (currentEstado != 3)
                _buildStateOptionCard(
                  stepLabel: 'Paso 3',
                  title: 'Mover a Resuelta',
                  description: 'Concluir y marcar como actividad finalizada',
                  icon: Icons.check_circle_rounded,
                  accentColor: const Color(0xFF059669),
                  backgroundColor: const Color(0xFFECFDF5),
                  borderColor: const Color(0xFFA7F3D0),
                  onTap: () {
                    Navigator.pop(ctx);
                    _updateState(3,
                        successMessage:
                            'Tarea marcada como Resuelta (Paso 3).');
                  },
                ),

              if (currentEstado != 5)
                _buildStateOptionCard(
                  stepLabel: 'Anular',
                  title: 'Cancelar Tarea',
                  description: 'Descartar o archivar esta actividad',
                  icon: Icons.cancel_outlined,
                  accentColor: const Color(0xFFDC2626),
                  backgroundColor: const Color(0xFFFEF2F2),
                  borderColor: const Color(0xFFFECACA),
                  isDestructive: true,
                  onTap: () {
                    Navigator.pop(ctx);
                    _updateState(5, successMessage: 'Tarea cancelada.');
                  },
                ),

              const SizedBox(height: 6),

              // Botón Volver con degradado institucional Apple
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0284C7).withOpacity(0.24),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Volver',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStateOptionCard({
    required String stepLabel,
    required String title,
    required String description,
    required IconData icon,
    required Color accentColor,
    required Color backgroundColor,
    required Color borderColor,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: accentColor, size: 24),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: isDestructive
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderColor),
                  ),
                  child: Text(
                    stepLabel,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: accentColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getPriorityBg(String prioridad) {
    final lower = prioridad.toLowerCase();
    if (lower.contains('crit') ||
        lower.contains('crít') ||
        lower.contains('urg') ||
        lower == '4') {
      return const Color(0xFFFEE2E2);
    }
    if (lower.contains('alt') || lower == '3') {
      return const Color(0xFFFEF3C7);
    }
    if (lower.contains('med') ||
        lower.contains('norm') ||
        lower == '2') {
      return const Color(0xFFE0F2FE);
    }
    if (lower.contains('baj') ||
        lower.contains('ningun') ||
        lower == '1' ||
        lower == '0') {
      return const Color(0xFFF1F5F9);
    }
    return const Color(0xFFE0F2FE);
  }

  Color _getPriorityColor(String prioridad) {
    final lower = prioridad.toLowerCase();
    if (lower.contains('crit') ||
        lower.contains('crít') ||
        lower.contains('urg') ||
        lower == '4') {
      return const Color(0xFFDC2626);
    }
    if (lower.contains('alt') || lower == '3') {
      return const Color(0xFFD97706);
    }
    if (lower.contains('med') ||
        lower.contains('norm') ||
        lower == '2') {
      return const Color(0xFF0284C7);
    }
    if (lower.contains('baj') || lower == '1') {
      return const Color(0xFF64748B);
    }
    return const Color(0xFF94A3B8);
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final screenHeight = mediaQuery.size.height;
    final clampedScaler = mediaQuery.textScaler.clamp(
      minScaleFactor: 0.85,
      maxScaleFactor: 1.15,
    );

    final data = _taskDetail ?? widget.taskSummary;
    final titulo =
        (data['titulo'] ?? data['title'] ?? 'Detalle de Tarea').toString();
    final descripcion =
        (data['descripcion'] ?? data['description'] ?? '').toString();
    final estadoRaw = data['estado'];
    final estado = int.tryParse(estadoRaw.toString()) ??
        (estadoRaw == 'proceso'
            ? 2
            : estadoRaw == 'resuelta'
                ? 3
                : 1);
    final prioridadRaw =
        (data['prioridad'] ?? data['priority'] ?? 'Normal').toString();
    final prioridadText = _formatPriorityLabel(prioridadRaw);
    final venceRaw = (data['vence'] ?? data['fechaVence'] ?? '').toString();
    final vehiculoEco = (data['vehiculo'] ?? data['eco'] ?? '').toString();

    String venceFormatted = venceRaw;
    if (venceRaw.isNotEmpty) {
      try {
        final parsedDate = DateTime.tryParse(venceRaw);
        if (parsedDate != null) {
          try {
            venceFormatted =
                DateFormat("d 'de' MMMM, yyyy", 'es_MX').format(parsedDate);
          } catch (_) {
            venceFormatted = DateFormat("dd/MM/yyyy").format(parsedDate);
          }
        }
      } catch (_) {}
    }
    final vence = venceFormatted;

    final sheetHeight = screenHeight * 0.92;

    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: clampedScaler),
      child: Container(
        height: sheetHeight,
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          children: [
            // Apple Grabber Pill
            Center(
              child: Container(
                width: 36,
                height: 4.5,
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),

            // Header de la Hoja con doble párrafo y espacios óptimos
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titulo,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.3,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Párrafo 1: Unidad y Nivel de Prioridad en texto
                        Row(
                          children: [
                            if (vehiculoEco.isNotEmpty) ...[
                              Flexible(
                                child: Text(
                                  'Unidad $vehiculoEco',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                '·',
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getPriorityBg(prioridadText),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Prioridad $prioridadText',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _getPriorityColor(prioridadText),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (venceFormatted.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          // Párrafo 2: Fecha de vencimiento amplia y clara
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_rounded,
                                size: 12,
                                color: Color(0xFF64748B),
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  'Vence: $venceFormatted',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // Contenido desplazable ampliado a toda la altura disponible
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. PIPELINE Y FLUJO GUIADO DE PROCESO
                    const Text(
                      'FLUJO DE PROCESO DE LA ACTIVIDAD',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildAppleProcessPipelineCard(estado),
                    const SizedBox(height: 14),

                    // 2. BOTÓN DE ACCIÓN PARA AVANZAR EL PROCESO
                    _buildProcessStepActionButton(estado),
                    const SizedBox(height: 16),

                    // 3. DESCRIPCIÓN E INFORMACIÓN
                    if (descripcion.isNotEmpty) ...[
                      const Text(
                        'INSTRUCCIONES Y DETALLES',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          descripcion,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF334155),
                            height: 1.45,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 4. BITÁCORA Y SEGUIMIENTO (CHAT / ACTIVIDADES)
                    Row(
                      children: [
                        const Text(
                          'BITÁCORA Y SEGUIMIENTO',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B),
                            letterSpacing: 0.8,
                          ),
                        ),
                        if (_comentarios.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${_comentarios.length}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildCommentsListSection(),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ),

            // Input de Comentario Fijo al fondo con SafeArea y diseño Apple elevado
            Container(
              padding: EdgeInsets.fromLTRB(
                16,
                10,
                16,
                math.max(mediaQuery.padding.bottom, 12) + bottomInset,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                border: const Border(
                    top: BorderSide(color: Color(0xFFE2E8F0), width: 1.0)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      cursorColor: const Color(0xFF0284C7),
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        hintText: 'Agregar nota o comentario a la bitácora...',
                        hintStyle: const TextStyle(
                            fontSize: 12, color: Color(0xFF94A3B8)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 11),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                              color: Color(0xFF0284C7), width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _isSending ? null : _addComment,
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: _isSending ? const Color(0xFFE2E8F0) : null,
                        gradient: _isSending
                            ? null
                            : const LinearGradient(
                                colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                        borderRadius: BorderRadius.circular(13),
                        boxShadow: _isSending
                            ? null
                            : [
                                BoxShadow(
                                  color: const Color(0xFF0284C7).withOpacity(0.28),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                      child: Center(
                        child: _isSending
                            ? LoadingAnimationWidget.threeRotatingDots(
                                color: const Color(0xFF94A3B8),
                                size: 18,
                              )
                            : const Icon(Icons.send_rounded,
                                color: Colors.white, size: 19),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- TARJETA DE PIPELINE / FLUJO DE PROCESO APPLE BLINDADO ---
  Widget _buildAppleProcessPipelineCard(int estado) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildStepIndicator(
                step: 1,
                title: 'Abierta',
                subtitle: 'Asignada',
                isActive: estado == 1,
                isCompleted: estado == 2 || estado == 3,
                activeColor: const Color(0xFF0284C7),
              ),
              Container(
                width: 18,
                height: 2.5,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: estado >= 2
                      ? const Color(0xFF0284C7)
                      : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              _buildStepIndicator(
                step: 2,
                title: 'En Proceso',
                subtitle: 'Ejecutando',
                isActive: estado == 2,
                isCompleted: estado == 3,
                activeColor: const Color(0xFFD97706),
              ),
              Container(
                width: 18,
                height: 2.5,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: estado >= 3
                      ? const Color(0xFF059669)
                      : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              _buildStepIndicator(
                step: 3,
                title: 'Resuelta',
                subtitle: 'Concluida',
                isActive: estado == 3,
                isCompleted: estado == 3,
                activeColor: const Color(0xFF059669),
              ),
            ],
          ),
          if (estado == 5) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cancel_outlined,
                      size: 14, color: Color(0xFFDC2626)),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Esta tarea fue cancelada del flujo operativo',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStepIndicator({
    required int step,
    required String title,
    required String subtitle,
    required bool isActive,
    required bool isCompleted,
    required Color activeColor,
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isActive
                  ? activeColor
                  : isCompleted
                      ? const Color(0xFFECFDF5)
                      : const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive
                    ? activeColor
                    : isCompleted
                        ? const Color(0xFFA7F3D0)
                        : const Color(0xFFCBD5E1),
                width: 1.5,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: activeColor.withOpacity(0.32),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: isCompleted && !isActive
                  ? const Icon(Icons.check_rounded,
                      size: 16, color: Color(0xFF059669))
                  : Text(
                      '$step',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color:
                            isActive ? Colors.white : const Color(0xFF64748B),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
              color:
                  isActive ? const Color(0xFF0F172A) : const Color(0xFF64748B),
            ),
          ),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9.5,
              color: isActive ? activeColor : const Color(0xFF94A3B8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // --- BOTÓN PRINCIPAL DE AVANCE DE PROCESO ---
  Widget _buildProcessStepActionButton(int estado) {
    if (estado == 1) {
      // Estado Abierta -> Avanzar a En Proceso
      return Column(
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _isSending
                ? null
                : () => _updateState(2,
                    successMessage: 'Tarea iniciada: se movió a "En Proceso".'),
            child: Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                color: _isSending ? const Color(0xFFE2E8F0) : null,
                gradient: _isSending
                    ? null
                    : const LinearGradient(
                        colors: [Color(0xFFD97706), Color(0xFFB45309)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: _isSending
                    ? null
                    : [
                        BoxShadow(
                          color: const Color(0xFFD97706).withOpacity(0.28),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
              ),
              child: Center(
                child: _isSending
                    ? LoadingAnimationWidget.threeRotatingDots(
                        color: const Color(0xFF94A3B8),
                        size: 24,
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.play_arrow_rounded,
                              color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Iniciar Tarea (Pasar a En Proceso)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildSecondaryOptionsButton(estado),
        ],
      );
    } else if (estado == 2) {
      // Estado En Proceso -> Finalizar y Marcar como Resuelta
      return Column(
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _isSending
                ? null
                : () => _updateState(3,
                    successMessage:
                        '¡Excelente! Tarea finalizada y marcada como "Resuelta".'),
            child: Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                color: _isSending ? const Color(0xFFE2E8F0) : null,
                gradient: _isSending
                    ? null
                    : const LinearGradient(
                        colors: [Color(0xFF059669), Color(0xFF047857)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: _isSending
                    ? null
                    : [
                        BoxShadow(
                          color: const Color(0xFF059669).withOpacity(0.28),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
              ),
              child: Center(
                child: _isSending
                    ? LoadingAnimationWidget.threeRotatingDots(
                        color: const Color(0xFF94A3B8),
                        size: 24,
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_rounded,
                              color: Colors.white, size: 19),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Concluir Tarea (Marcar como Resuelta)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildSecondaryOptionsButton(estado),
        ],
      );
    } else if (estado == 3) {
      // Estado Resuelta
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFA7F3D0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.verified_rounded,
                color: Color(0xFF059669), size: 22),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tarea Resuelta y Verificada',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF065F46),
                    ),
                  ),
                  Text(
                    'Esta actividad ha concluido exitosamente.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: Color(0xFF047857)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              color: _isSending ? const Color(0xFFE2E8F0) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              onPressed: _isSending
                  ? null
                  : () => _updateState(1,
                      successMessage: 'Tarea reabierta para revisión.'),
              child: _isSending
                  ? LoadingAnimationWidget.threeRotatingDots(
                      color: const Color(0xFF94A3B8),
                      size: 16,
                    )
                  : const Text(
                      'Reabrir',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF059669),
                      ),
                    ),
            ),
          ],
        ),
      );
    } else {
      // Estado Cancelada u otro
      return CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: _isSending
            ? null
            : () =>
                _updateState(1, successMessage: 'Tarea reactivada como Abierta.'),
        child: Container(
          width: double.infinity,
          height: 46,
          decoration: BoxDecoration(
            color: _isSending ? const Color(0xFFE2E8F0) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Center(
            child: _isSending
                ? LoadingAnimationWidget.threeRotatingDots(
                    color: const Color(0xFF94A3B8),
                    size: 20,
                  )
                : const Text(
                    'Reactivar Tarea (Volver a Abrir)',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0284C7),
                    ),
                  ),
          ),
        ),
      );
    }
  }

  Widget _buildSecondaryOptionsButton(int estado) {
    return GestureDetector(
      onTap: () => _showStateOptionsDialog(estado),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.tune_rounded, size: 14, color: Color(0xFF64748B)),
            SizedBox(width: 5),
            Flexible(
              child: Text(
                'Opciones avanzadas o cancelar tarea...',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- BITÁCORA Y COMENTARIOS APPLE ---
  Widget _buildCommentsListSection() {
    if (_isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: List.generate(
            2,
            (index) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  AppShimmerBox(width: 34, height: 34, borderRadius: 10),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppShimmerBox.text(width: 120, height: 12),
                        SizedBox(height: 6),
                        AppShimmerBox.text(width: double.infinity, height: 11),
                        SizedBox(height: 4),
                        AppShimmerBox.text(width: 160, height: 11),
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

    if (_comentarios.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Column(
          children: [
            Icon(Icons.chat_bubble_outline_rounded,
                size: 28, color: Color(0xFF94A3B8)),
            SizedBox(height: 8),
            Text(
              'Bitácora sin notas aún',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF475569),
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Escribe abajo para registrar comentarios o evidencias del avance.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _comentarios.map((c) {
        final autor = (c['autor'] ?? c['nombre'] ?? 'Colaborador').toString();
        final texto = (c['texto'] ?? c['comentario'] ?? '').toString();
        final fecha = (c['fecHor'] ?? c['fecha'] ?? '').toString();

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withOpacity(0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE0F2FE), Color(0xFFBAE6FD)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    autor.isNotEmpty ? autor[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0284C7),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            autor,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (fecha.isNotEmpty)
                          Text(
                            fecha.length > 16 ? fecha.substring(0, 16) : fecha,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      texto,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF334155),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

/// Modal Bottom Sheet para Crear Tarea con Apple HIG (Mismo diseño de inputs y tarjetas que Mantenimiento)
class _CreateTaskModal extends StatefulWidget {
  final int? idVehic;
  final VoidCallback onTaskCreated;

  const _CreateTaskModal({this.idVehic, required this.onTaskCreated});

  @override
  State<_CreateTaskModal> createState() => _CreateTaskModalState();
}

class _CreateTaskModalState extends State<_CreateTaskModal> {
  final _tituloCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  final List<Map<String, dynamic>> _prioridades = [
    {'id': '1', 'name': 'Baja', 'color': const Color(0xFF10B981)},
    {'id': '2', 'name': 'Media', 'color': const Color(0xFF0284C7)},
    {'id': '3', 'name': 'Alta', 'color': const Color(0xFFF59E0B)},
    {'id': '4', 'name': 'Crítica', 'color': const Color(0xFFEF4444)},
  ];
  String _selectedPriority = '2'; // 1: Baja, 2: Media, 3: Alta, 4: Crítica

  List<Map<String, dynamic>> _vehiculosDisponibles = [];
  int? _selectedVehicId;
  bool _isLoadingVehiculos = false;

  DateTime _vence = DateTime.now().add(const Duration(days: 3));
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedVehicId = widget.idVehic;
    _loadVehiculos();
  }

  Future<void> _loadVehiculos() async {
    setState(() => _isLoadingVehiculos = true);
    try {
      final list = await MarkApiClient.instance.getVehiculos();
      if (mounted) {
        setState(() {
          _vehiculosDisponibles = list;
          _isLoadingVehiculos = false;
          if (_selectedVehicId == null && list.isNotEmpty) {
            if (list.length == 1) {
              final id = int.tryParse(
                  (list.first['idVehic'] ?? list.first['id'] ?? '0')
                      .toString());
              if (id != null && id > 0) _selectedVehicId = id;
            }
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingVehiculos = false);
    }
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _vence,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0284C7),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _vence = picked);
    }
  }

  Future<void> _submit() async {
    final titulo = _tituloCtrl.text.trim();
    if (titulo.isEmpty) {
      SnackbarTop.showError(context, 'Ingresa el título de la tarea.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final int priorityId = int.tryParse(_selectedPriority) ?? 2;
      final String formattedVence = DateFormat('yyyy-MM-dd').format(_vence);
      final int? vehicId = widget.idVehic ?? _selectedVehicId;

      // 1. Enviar con la estructura canónica idéntica a la verificada en el backend
      final taskAction = {
        'uuid': const Uuid().v4(),
        'tipo': 'tarea',
        if (vehicId != null && vehicId > 0) 'idVehic': vehicId,
        'titulo': titulo,
        if (_descCtrl.text.trim().isNotEmpty)
          'descripcion': _descCtrl.text.trim(),
        'prioridad': _selectedPriority, // '1', '2', '3', '4' idéntico a vehicle_report_sheets
        'idPrioridad': priorityId,
        'vence': formattedVence,
        'fecHor': DateTime.now()
            .toIso8601String()
            .replaceFirst('T', ' ')
            .substring(0, 19),
      };

      var res = await MarkApiClient.instance.sendActions([taskAction]);
      bool isSuccess = res.isNotEmpty && res.first['ok'] == true;

      // 2. Si el servidor rechaza tipo 'tarea' y tenemos una unidad seleccionada,
      // probamos fallback inmediato con tipo 'problema' (el endpoint verificado al 100%)
      if (!isSuccess && vehicId != null && vehicId > 0) {
        final problemAction = {
          'uuid': const Uuid().v4(),
          'tipo': 'problema',
          'idVehic': vehicId,
          'titulo': titulo,
          if (_descCtrl.text.trim().isNotEmpty)
            'descripcion': _descCtrl.text.trim(),
          'prioridad': _selectedPriority,
          'vence': formattedVence,
          'fecHor': DateTime.now()
              .toIso8601String()
              .replaceFirst('T', ' ')
              .substring(0, 19),
        };
        final resProblem =
            await MarkApiClient.instance.sendActions([problemAction]);
        if (resProblem.isNotEmpty && resProblem.first['ok'] == true) {
          res = resProblem;
          isSuccess = true;
        }
      }

      if (!isSuccess && res.isNotEmpty) {
        final first = res.first;
        final avisos = first['avisos'] as List? ?? [];
        final errorMsg = avisos.isNotEmpty
            ? avisos.first['texto']
            : 'Error al registrar la tarea.';
        throw Exception(errorMsg);
      }

      widget.onTaskCreated();
      if (mounted) {
        Navigator.pop(context);
        SnackbarTop.showSuccess(context, 'Tarea creada exitosamente.');
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        SnackbarTop.showError(context, msg);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final screenHeight = mediaQuery.size.height;
    final clampedScaler = mediaQuery.textScaler.clamp(
      minScaleFactor: 0.85,
      maxScaleFactor: 1.15,
    );

    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: clampedScaler),
      child: Container(
        height: screenHeight * 0.92,
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          children: [
            // Apple Grabber Pill
            Center(
              child: Container(
                width: 36,
                height: 4.5,
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 16, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nueva Tarea de Flota',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.4,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Crea una actividad o asignación de trabajo',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // Contenido con Scroll
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16, 16, 16,
                    math.max(mediaQuery.padding.bottom, 16) + bottomInset),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Grupo 1: Datos de la Tarea (Mismo diseño de Mantenimiento)
                    const Text(
                      'ACTIVIDAD Y TÍTULO',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildAppleCard(
                      children: [
                        _buildAppleTextField(
                          controller: _tituloCtrl,
                          label: 'Título de la Tarea *',
                          placeholder:
                              'Ej. Revisar niveles y afinación de REP-06',
                          icon: Icons.edit_note_rounded,
                        ),
                        const SizedBox(height: 14),
                        _buildVehicleSelector(),
                        const SizedBox(height: 14),
                        const Text(
                          'Nivel de Prioridad',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 6),
                        _buildSegmentedPrioritySelector(),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 2. Grupo 2: Programación y Plazo
                    const Text(
                      'FECHA LÍMITE DE CUMPLIMIENTO',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildAppleCard(
                      children: [
                        _buildDatePickerField(),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 3. Grupo 3: Instrucciones y Observaciones
                    const Text(
                      'INSTRUCCIONES Y OBSERVACIONES',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildAppleCard(
                      children: [
                        _buildAppleTextField(
                          controller: _descCtrl,
                          label: 'Descripción de la Actividad (Opcional)',
                          placeholder:
                              'Describe los pasos, refacciones o instrucciones técnicas...',
                          icon: Icons.notes_rounded,
                          maxLines: 3,
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),

                    // Botón Crear Primario Apple (Estilo exacto de EditProfilePage con tono gris durante carga)
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: _isSaving ? const Color(0xFFE2E8F0) : null,
                          gradient: _isSaving
                              ? null
                              : const LinearGradient(
                                  colors: [
                                    Color(0xFF0284C7),
                                    Color(0xFF0369A1),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                          boxShadow: _isSaving
                              ? null
                              : [
                                  BoxShadow(
                                    color: const Color(0xFF0284C7)
                                        .withOpacity(0.32),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                        ),
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xFFE2E8F0),
                            disabledForegroundColor: const Color(0xFF94A3B8),
                            shadowColor: Colors.transparent,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _isSaving
                              ? Center(
                                  child:
                                      LoadingAnimationWidget.threeRotatingDots(
                                    color: const Color(0xFF94A3B8),
                                    size: 24,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_task_rounded,
                                        color: Colors.white, size: 19),
                                    SizedBox(width: 8),
                                    Text(
                                      'Crear y Asignar Tarea',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleSelector() {
    if (widget.idVehic != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.directions_car_rounded,
                size: 18, color: Color(0xFF0284C7)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Unidad asignada: #${widget.idVehic}',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_isLoadingVehiculos) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Color(0xFF0284C7)),
            ),
            SizedBox(width: 10),
            Text(
              'Cargando unidades de flota...',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    if (_vehiculosDisponibles.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 2, bottom: 5),
          child: Text(
            'Unidad o Vehículo (Opcional)',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int?>(
              value: _selectedVehicId,
              isExpanded: true,
              hint: const Text(
                'Selecciona la unidad asignada',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
              ),
              icon: const Icon(Icons.arrow_drop_down_rounded,
                  color: Color(0xFF64748B)),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text(
                    'Sin unidad específica (General)',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                ),
                ..._vehiculosDisponibles.map((v) {
                  final id = int.tryParse(
                          (v['idVehic'] ?? v['id'] ?? '0').toString()) ??
                      0;
                  final eco = (v['economico'] ?? v['eco'] ?? '').toString();
                  final marca = (v['marca'] ?? v['make'] ?? '').toString();
                  final modelo = (v['modelo'] ?? v['model'] ?? '').toString();
                  final placas =
                      (v['placas'] ?? v['plates'] ?? '').toString();
                  final label = [
                    if (eco.isNotEmpty) '[$eco]',
                    '$marca $modelo'.trim(),
                    if (placas.isNotEmpty) '· $placas',
                  ].join(' ').trim();
                  return DropdownMenuItem<int?>(
                    value: id > 0 ? id : null,
                    child: Text(
                      label.isNotEmpty ? label : 'Unidad #$id',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  );
                }),
              ],
              onChanged: (val) => setState(() => _selectedVehicId = val),
            ),
          ),
        ),
      ],
    );
  }

  // Selector Segmentado de Prioridad estilo Apple (idéntico a vehicle_report_sheets)
  Widget _buildSegmentedPrioritySelector() {
    return Row(
      children: _prioridades.map((p) {
        final isSelected = _selectedPriority == p['id'];
        final color = p['color'] as Color;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.5),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () =>
                  setState(() => _selectedPriority = p['id'] as String),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: isSelected ? color : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? color : const Color(0xFFE2E8F0),
                    width: isSelected ? 1.5 : 1.0,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: color.withOpacity(0.28),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    p['name'] as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDatePickerField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 2, bottom: 5),
          child: Text(
            'Fecha Límite',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _pickDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 16,
                  color: Color(0xFF0284C7),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    DateFormat('d MMMM yyyy', 'es_MX').format(_vence),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_drop_down_rounded,
                  color: Color(0xFF64748B),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppleCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildAppleTextField({
    required TextEditingController controller,
    required String label,
    required String placeholder,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 5),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
        ),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          cursorColor: const Color(0xFF0284C7),
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            isDense: true,
            hintText: placeholder,
            hintStyle: const TextStyle(
              fontSize: 12.5,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: maxLines == 1
                ? Icon(icon, size: 17, color: const Color(0xFF0284C7))
                : null,
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFF0284C7), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
