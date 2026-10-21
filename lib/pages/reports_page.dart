import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mark_v3/pages/Error_/ConnectionErrorPage.dart';
import 'package:mark_v3/pages/Error_/ServerErrorPage.dart';
import 'package:mark_v3/pages/Error_/unexpectedErrorPage.dart';
import 'package:mark_v3/services/mark_api_client.dart';
import 'package:mark_v3/widgets/app_skeleton.dart';
import 'package:mark_v3/widgets/snackbar_top.dart';

/// Pantalla de Reportes Operativos con Apple Human Interface Guidelines
class ReportsPage extends ConsumerStatefulWidget {
  final int? idVehic;

  const ReportsPage({super.key, this.idVehic});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  final MarkApiClient _client = MarkApiClient.instance;

  late DateTime _desde;
  late DateTime _hasta;
  int _selectedPresetIndex = 1; // 0: Hoy, 1: 7 días, 2: 15 días, 3: Mes

  bool _isLoading = true;
  String? _errorMessage;
  Object? _lastError;
  Map<String, dynamic>? _reportData;

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
  List<Map<String, dynamic>> _vehiclesList = [];
  List<Map<String, dynamic>> _fleetVehicles = [];
  List<Map<String, dynamic>> _fleetAlerts = [];
  List<Map<String, dynamic>> _fleetTasks = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _hasta = now;
    _desde = now.subtract(const Duration(days: 7));
    _fetchReport();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  double _parseNum(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    final s = val.toString().replaceAll(RegExp(r'[^\d.-]'), '');
    return double.tryParse(s) ?? 0.0;
  }

  List<Map<String, dynamic>> _extractVehiclesList(Map<String, dynamic> raw) {
    for (final key in [
      'reportes',
      'vehiculos',
      'data',
      'unidades',
      'items',
      'lista',
      'registros',
      'detalles',
      'reporte',
      'dias',
    ]) {
      final val = raw[key];
      if (val is List && val.isNotEmpty) {
        return val.whereType<Map<String, dynamic>>().toList();
      }
    }

    final mapValues = raw.values.whereType<Map<String, dynamic>>().toList();
    if (mapValues.isNotEmpty &&
        mapValues.any((m) =>
            m.containsKey('idVehic') ||
            m.containsKey('economico') ||
            m.containsKey('distancia') ||
            m.containsKey('km'))) {
      return mapValues;
    }

    return [];
  }

  Future<void> _fetchReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _lastError = null;
    });

    try {
      final desdeStr = DateFormat('yyyy-MM-dd').format(_desde);
      final hastaStr = DateFormat('yyyy-MM-dd').format(_hasta);

      final results = await Future.wait([
        _client
            .getReportes(
          desde: desdeStr,
          hasta: hastaStr,
          idVehic: widget.idVehic,
        )
            .catchError((e) {
          debugPrint('Error en getReportes: $e');
          return <String, dynamic>{};
        }),
        _client.getVehiculos().catchError((e) {
          debugPrint('Error en getVehiculos: $e');
          return <Map<String, dynamic>>[];
        }),
        _client.getAlertas(idVehic: widget.idVehic).catchError((e) {
          debugPrint('Error en getAlertas: $e');
          return <Map<String, dynamic>>[];
        }),
        _client.getTareas(idVehic: widget.idVehic).catchError((e) {
          debugPrint('Error en getTareas: $e');
          return <Map<String, dynamic>>[];
        }),
      ]);

      final reportData = results[0] as Map<String, dynamic>;
      final fleetVehicles = results[1] as List<Map<String, dynamic>>;
      final fleetAlerts = results[2] as List<Map<String, dynamic>>;
      final fleetTasks = results[3] as List<Map<String, dynamic>>;

      final extracted = _extractVehiclesList(reportData);

      // Si el reporte directo trajo vehículos, los usamos; si no, enriquecemos con los vehículos de flota
      List<Map<String, dynamic>> finalVehicles = [];
      if (extracted.isNotEmpty) {
        finalVehicles = extracted;
      } else if (fleetVehicles.isNotEmpty) {
        finalVehicles = fleetVehicles.map((fv) {
          return {
            'idVehic': fv['idVehic'],
            'economico': fv['economico'] ?? fv['eco'] ?? 'Unidad',
            'placas': fv['placas'] ?? '',
            'marca': fv['marca'] ?? '',
            'modelo': fv['modelo'] ?? '',
            'distancia': fv['distancia'] ?? fv['km'] ?? 0,
            'horasMovimiento': fv['horasMovimiento'] ?? fv['movimiento'] ?? 0,
            'horasRalenti': fv['horasRalenti'] ?? fv['ralenti'] ?? 0,
            'rendimiento': fv['rendimiento'] ?? 'N/A',
            'viajes': fv['viajes'] ?? 0,
            'velocidadMaxima': fv['velocidad'] ?? 0,
            'alertas': fv['alertas'] ?? 0,
            'odometro': fv['odometro'] ?? fv['odometroKm'] ?? 0,
          };
        }).toList();
      }

      if (mounted) {
        setState(() {
          _reportData = reportData;
          _vehiclesList = finalVehicles;
          _fleetVehicles = fleetVehicles;
          _fleetAlerts = fleetAlerts;
          _fleetTasks = fleetTasks;
          _isLoading = false;
        });
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

  void _applyPreset(int index) {
    final now = DateTime.now();
    DateTime newDesde;
    DateTime newHasta = now;

    switch (index) {
      case 0: // Hoy
        newDesde = DateTime(now.year, now.month, now.day);
        break;
      case 1: // 7 días
        newDesde = now.subtract(const Duration(days: 7));
        break;
      case 2: // 15 días
        newDesde = now.subtract(const Duration(days: 15));
        break;
      case 3: // Mes actual
        newDesde = DateTime(now.year, now.month, 1);
        break;
      default:
        newDesde = now.subtract(const Duration(days: 7));
    }

    setState(() {
      _selectedPresetIndex = index;
      _desde = newDesde;
      _hasta = newHasta;
    });
    _fetchReport();
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 120)),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _desde, end: _hasta),
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
      final diff = picked.end.difference(picked.start).inDays;
      if (diff > 31) {
        if (mounted) {
          SnackbarTop.showWarning(
              context, 'El rango máximo de consulta es de 31 días.');
        }
        return;
      }
      setState(() {
        _selectedPresetIndex = -1; // Rango manual personalizado
        _desde = picked.start;
        _hasta = picked.end;
      });
      _fetchReport();
    }
  }

  void _showVehicleDetailModal(Map<String, dynamic> v) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _VehicleReportDetailSheet(
        vehicle: v,
        desde: _desde,
        hasta: _hasta,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Si la carga falló, desplegar pantalla oficial de error (Conexión, Servidor o Inesperado)
    if (!_isLoading && _errorMessage != null) {
      if (_isNetworkError(_lastError ?? _errorMessage)) {
        return ConnectionErrorPage(onRetry: _fetchReport);
      } else if (_isServerError(_lastError ?? _errorMessage)) {
        return ServerErrorPage(onRetry: _fetchReport);
      } else {
        return Unexpectederrorpage(onRetry: _fetchReport);
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
                'Reportes Operativos',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.4,
                ),
              ),
              SizedBox(height: 1),
              Text(
                'Telemetría, combustible y rendimiento',
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
        body: SafeArea(
          child: _isLoading
              ? AppSkeleton.reports()
              : RefreshIndicator(
                  onRefresh: _fetchReport,
                  color: const Color(0xFF0284C7),
                  backgroundColor: Colors.white,
                  displacement: 28,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 1. Selector de Rango y Filtros Rápidos
                              _buildDateFilterSection(),
                              const SizedBox(height: 16),

                              // 2. Tarjetas KPI Métricas Clave
                              _buildKpiMetricsGrid(),
                              const SizedBox(height: 16),

                              // 3. Tarjeta Inset de Detalles Operativos
                              _buildOperationalDetailsCard(),
                              const SizedBox(height: 16),

                              // 4. Desglose por Vehículo
                              _buildVehiclesSection(),
                            ],
                          ),
                        ),
                ),
        ),
      ),
    );
  }

  // --- SELECTOR DE RANGO Y CHIPS RÁPIDOS APPLE ---
  Widget _buildDateFilterSection() {
    final f = DateFormat('d MMM yyyy', 'es_MX');
    final diffDays = _hasta.difference(_desde).inDays + 1;

    final presets = ['Hoy', '7 Días', '15 Días', 'Este Mes'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selector Principal Inset Grouped
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _selectDateRange,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.calendar_month_rounded,
                          size: 20,
                          color: Color(0xFF0284C7),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Período Consultado',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${f.format(_desde)} — ${f.format(_hasta)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        '$diffDays d',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: Color(0xFF94A3B8),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Filtros Rápidos Segmentados Estilo Apple Capsule
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: List.generate(presets.length, (index) {
              final isSelected = _selectedPresetIndex == index;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => _applyPreset(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6.5),
                    decoration: BoxDecoration(
                      color:
                          isSelected ? const Color(0xFF0284C7) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF0284C7)
                            : const Color(0xFFE2E8F0),
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color:
                                    const Color(0xFF0284C7).withOpacity(0.24),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      presets[index],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w600,
                        color:
                            isSelected ? Colors.white : const Color(0xFF475569),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  double _getComputedFuel() {
    final rawData = _reportData ?? {};
    final totales = rawData['totales'] is Map
        ? rawData['totales'] as Map
        : rawData['resumen'] is Map
            ? rawData['resumen'] as Map
            : rawData;

    double comb = _parseNum(
        totales['combustible'] ?? totales['litros'] ?? totales['consumo']);
    if (comb == 0 && _vehiclesList.isNotEmpty) {
      for (final v in _vehiclesList) {
        comb += _parseNum(v['combustible'] ?? v['litros'] ?? v['consumo']);
      }
    }
    return comb;
  }

  // --- TARJETAS KPI DE TELEMETRÍA APPLE DINÁMICAS ---
  Widget _buildKpiMetricsGrid() {
    final rawData = _reportData ?? {};
    final totales = rawData['totales'] is Map<String, dynamic>
        ? rawData['totales'] as Map<String, dynamic>
        : rawData['resumen'] is Map<String, dynamic>
            ? rawData['resumen'] as Map<String, dynamic>
            : rawData;

    double distVal = _parseNum(
        totales['distancia'] ?? totales['km'] ?? totales['distanciaKm']);
    double horasMovVal = _parseNum(totales['horasMovimiento'] ??
        totales['movimiento'] ??
        totales['horasMov']);
    double horasRalentiVal = _parseNum(
        totales['horasRalenti'] ?? totales['ralenti'] ?? totales['horasRal']);
    String rendimientoVal = (totales['rendimiento'] ?? '').toString();

    // Sumarizar dinámicamente si el backend no entregó totales a nivel raíz
    if (distVal == 0 && horasMovVal == 0 && _vehiclesList.isNotEmpty) {
      for (final v in _vehiclesList) {
        distVal += _parseNum(v['distancia'] ?? v['km'] ?? v['distanciaKm']);
        horasMovVal +=
            _parseNum(v['horasMovimiento'] ?? v['movimiento'] ?? v['horasMov']);
        horasRalentiVal +=
            _parseNum(v['horasRalenti'] ?? v['ralenti'] ?? v['horasRal']);
      }
    }

    // Calcular rendimiento promedio
    if (rendimientoVal.isEmpty ||
        rendimientoVal == '0' ||
        rendimientoVal == 'N/A') {
      final totalComb = _getComputedFuel();
      if (distVal > 0 && totalComb > 0) {
        rendimientoVal = '${(distVal / totalComb).toStringAsFixed(1)} km/L';
      } else {
        double sumRend = 0;
        int countRend = 0;
        for (final v in _vehiclesList) {
          final r = _parseNum(v['rendimiento']);
          if (r > 0) {
            sumRend += r;
            countRend++;
          }
        }
        if (countRend > 0) {
          rendimientoVal = '${(sumRend / countRend).toStringAsFixed(1)} km/L';
        } else {
          rendimientoVal = 'N/A';
        }
      }
    }

    final distStr = distVal > 0
        ? (distVal % 1 == 0
            ? distVal.toInt().toString()
            : distVal.toStringAsFixed(1))
        : '0';
    final movStr = horasMovVal > 0
        ? (horasMovVal % 1 == 0
            ? horasMovVal.toInt().toString()
            : horasMovVal.toStringAsFixed(1))
        : '0';
    final ralStr = horasRalentiVal > 0
        ? (horasRalentiVal % 1 == 0
            ? horasRalentiVal.toInt().toString()
            : horasRalentiVal.toStringAsFixed(1))
        : '0';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('MÉTRICAS CLAVE DEL PERÍODO'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildAppleMetricCard(
                title: 'Distancia Total',
                value: '$distStr km',
                icon: Icons.route_rounded,
                iconBg: const Color(0xFFE0F2FE),
                iconColor: const Color(0xFF0284C7),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildAppleMetricCard(
                title: 'En Movimiento',
                value: '$movStr h',
                icon: Icons.timer_outlined,
                iconBg: const Color(0xFFECFDF5),
                iconColor: const Color(0xFF059669),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildAppleMetricCard(
                title: 'Tiempo en Ralentí',
                value: '$ralStr h',
                icon: Icons.pause_circle_outline_rounded,
                iconBg: const Color(0xFFFFFBEB),
                iconColor: const Color(0xFFD97706),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildAppleMetricCard(
                title: 'Rendimiento Prom.',
                value: rendimientoVal,
                icon: Icons.eco_outlined,
                iconBg: const Color(0xFFF3E8FF),
                iconColor: const Color(0xFF9333EA),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAppleMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
  }) {
    return Container(
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
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(child: Icon(icon, color: iconColor, size: 18)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.4,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  // --- DETALLES OPERATIVOS INSET GROUPED APPLE ---
  Widget _buildOperationalDetailsCard() {
    final rawData = _reportData ?? {};
    final totales = rawData['totales'] is Map
        ? rawData['totales'] as Map
        : rawData['resumen'] is Map
            ? rawData['resumen'] as Map
            : rawData;

    double viajes = _parseNum(totales['viajes'] ??
        totales['totalViajes'] ??
        totales['viajesRealizados']);
    double velMax = _parseNum(totales['velocidadMaxima'] ??
        totales['velMax'] ??
        totales['velocidad_maxima']);
    double comb = _getComputedFuel();
    double alertas = _parseNum(totales['alertas'] ?? totales['totalAlertas']);
    double incidencias =
        _parseNum(totales['incidencias'] ?? totales['totalIncidencias']);

    if (viajes == 0 && velMax == 0 && _vehiclesList.isNotEmpty) {
      for (final v in _vehiclesList) {
        viajes += _parseNum(v['viajes'] ?? v['totalViajes']);
        final vMax =
            _parseNum(v['velocidadMaxima'] ?? v['velMax'] ?? v['velocidad']);
        if (vMax > velMax) velMax = vMax;
        alertas += _parseNum(v['alertas'] ?? v['totalAlertas']);
        incidencias += _parseNum(v['incidencias'] ?? v['totalIncidencias']);
      }
    }

    if (alertas == 0 && _fleetAlerts.isNotEmpty) {
      alertas = _fleetAlerts.length.toDouble();
    }
    if (incidencias == 0 && _fleetTasks.isNotEmpty) {
      incidencias = _fleetTasks
          .where((t) {
            final p = (t['prioridad'] ?? '').toString().toLowerCase();
            return p == 'urgente' || p == 'alta' || p == 'crítica';
          })
          .length
          .toDouble();
    }

    final viajesStr = viajes.toInt().toString();
    final velMaxStr = velMax > 0
        ? (velMax % 1 == 0
            ? velMax.toInt().toString()
            : velMax.toStringAsFixed(1))
        : '0';
    final combStr = comb > 0
        ? (comb % 1 == 0 ? comb.toInt().toString() : comb.toStringAsFixed(1))
        : '0';
    final alertasStr = alertas.toInt().toString();
    final incidenciasStr = incidencias.toInt().toString();

    final details = [
      (
        Icons.alt_route_rounded,
        'Viajes Realizados',
        '$viajesStr viajes',
        const Color(0xFF0284C7)
      ),
      (
        Icons.speed_rounded,
        'Velocidad Máxima',
        '$velMaxStr km/h',
        const Color(0xFFEA580C)
      ),
      (
        Icons.local_gas_station_rounded,
        'Consumo Estimado',
        '$combStr L',
        const Color(0xFF0D9488)
      ),
      (
        Icons.warning_amber_rounded,
        'Alertas Telemáticas',
        '$alertasStr eventos',
        const Color(0xFFD97706)
      ),
      (
        Icons.report_problem_outlined,
        'Incidencias Operativas',
        '$incidenciasStr registros',
        const Color(0xFFDC2626)
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('DESGLOSE OPERATIVO'),
        const SizedBox(height: 8),
        Container(
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
            children: List.generate(details.length, (i) {
              final item = details[i];
              final isLast = i == details.length - 1;

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 11),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: item.$4.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Icon(item.$1, size: 17, color: item.$4),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item.$2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            item.$3,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isLast)
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  // --- SECCIÓN DESGLOSE POR VEHÍCULO ---
  Widget _buildVehiclesSection() {
    final f = DateFormat('d MMM', 'es_MX');

    if (_vehiclesList.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 18),
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
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Center(
                child: Icon(
                  Icons.route_outlined,
                  size: 26,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Sin recorridos registrados en este período',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E293B),
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'No se detectó actividad de telemetría entre ${f.format(_desde)} y ${f.format(_hasta)}.\nPrueba ampliando el rango de consulta:',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CupertinoButton(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  color: const Color(0xFF0284C7),
                  borderRadius: BorderRadius.circular(10),
                  onPressed: () => _applyPreset(2), // 15 días
                  child: const Text(
                    'Ver 15 Días',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 8),
                CupertinoButton(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  onPressed: () => _applyPreset(3), // Este mes
                  child: const Text(
                    'Ver Este Mes',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0284C7),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final filteredVehicles = _vehiclesList.where((v) {
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.trim().toLowerCase();
      final eco =
          (v['economico'] ?? v['eco'] ?? v['vehiculo'] ?? '').toString().toLowerCase();
      final placas = (v['placas'] ?? '').toString().toLowerCase();
      final marca = (v['marca'] ?? '').toString().toLowerCase();
      final modelo = (v['modelo'] ?? '').toString().toLowerCase();
      final chofer =
          (v['conductor'] ?? v['operador'] ?? v['chofer'] ?? '').toString().toLowerCase();
      return eco.contains(q) ||
          placas.contains(q) ||
          marca.contains(q) ||
          modelo.contains(q) ||
          chofer.contains(q);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'UNIDADES EN REPORTE',
          badgeText: _searchQuery.trim().isEmpty
              ? '${_vehiclesList.length}'
              : '${filteredVehicles.length} de ${_vehiclesList.length}',
          badgeColor: const Color(0xFF0284C7),
        ),
        const SizedBox(height: 10),
        _buildVehicleSearchBar(),
        const SizedBox(height: 10),
        if (filteredVehicles.isEmpty)
          _buildNoSearchResultsView()
        else
          ...filteredVehicles.map((v) => _buildVehicleReportCard(v)),
      ],
    );
  }

  // --- BUSCADOR ESTILO APPLE HIG ---
  Widget _buildVehicleSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A1E34).withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.search_rounded,
            color: Color(0xFF0284C7),
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              autofocus: false,
              cursorColor: const Color(0xFF0284C7),
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w500,
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
              decoration: const InputDecoration(
                hintText: 'Buscar por económico, placas, marca o modelo...',
                hintStyle: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          if (_searchQuery.trim().isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                });
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Color(0xFFE2E8F0),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: Color(0xFF475569),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --- VISTA SIN RESULTADOS DE BÚSQUEDA ---
  Widget _buildNoSearchResultsView() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 0.9,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search_off_rounded,
              color: Color(0xFF94A3B8),
              size: 28,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Sin resultados para "$_searchQuery"',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Verifica el número económico, placas o modelo ingresado.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 14),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            onPressed: () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
              });
            },
            child: const Text(
              'Limpiar búsqueda',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0284C7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- TARJETA DE REPORTE POR VEHÍCULO RESPONSIVA APPLE ---
  Widget _buildVehicleReportCard(Map<String, dynamic> v) {
    final eco =
        (v['economico'] ?? v['eco'] ?? v['vehiculo'] ?? 'Unidad').toString();
    final placas = (v['placas'] ?? '').toString();
    final marca = (v['marca'] ?? '').toString();
    final modelo = (v['modelo'] ?? '').toString();
    final distancia = (v['distancia'] ?? v['km'] ?? '0').toString();
    final horasMov =
        (v['horasMovimiento'] ?? v['movimiento'] ?? '0').toString();
    final horasRalenti = (v['horasRalenti'] ?? v['ralenti'] ?? '0').toString();
    final rendimiento = (v['rendimiento'] ?? 'N/A').toString();

    final subtitulo = [
      if (marca.isNotEmpty) marca,
      if (modelo.isNotEmpty) modelo,
      if (placas.isNotEmpty) placas,
    ].join(' · ');

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
          onTap: () => _showVehicleDetailModal(v),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0284C7).withOpacity(0.20),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.directions_car_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            eco,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            subtitulo.isNotEmpty
                                ? subtitulo
                                : 'Unidad en servicio',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: Color(0xFFCBD5E1),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildMiniMetric(
                      label: 'Distancia',
                      value: '$distancia km',
                      icon: Icons.straighten_rounded,
                      color: const Color(0xFF0284C7),
                    ),
                    const SizedBox(width: 6),
                    _buildMiniMetric(
                      label: 'Movimiento',
                      value: '$horasMov h',
                      icon: Icons.timer_outlined,
                      color: const Color(0xFF059669),
                    ),
                    const SizedBox(width: 6),
                    _buildMiniMetric(
                      label: 'Ralentí',
                      value: '$horasRalenti h',
                      icon: Icons.pause_circle_outline,
                      color: const Color(0xFFD97706),
                    ),
                    const SizedBox(width: 6),
                    _buildMiniMetric(
                      label: 'Rendimiento',
                      value: rendimiento,
                      icon: Icons.eco_outlined,
                      color: const Color(0xFF9333EA),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniMetric({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
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
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // --- ENCABEZADOS DE SECCIÓN APPLE ---
  Widget _buildSectionHeader(String title,
      {String? badgeText, Color? badgeColor}) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4, top: 4),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
              letterSpacing: 0.8,
            ),
          ),
          if (badgeText != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color:
                    (badgeColor ?? const Color(0xFF0284C7)).withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                badgeText,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: badgeColor ?? const Color(0xFF0284C7),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- VISTA DE ERROR ---
}

/// Hoja de Detalle para un Vehículo Seleccionado estilo Apple
class _VehicleReportDetailSheet extends StatelessWidget {
  final Map<String, dynamic> vehicle;
  final DateTime desde;
  final DateTime hasta;

  const _VehicleReportDetailSheet({
    required this.vehicle,
    required this.desde,
    required this.hasta,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final clampedScaler = mediaQuery.textScaler.clamp(
      minScaleFactor: 0.85,
      maxScaleFactor: 1.15,
    );

    final f = DateFormat('d MMM yyyy', 'es_MX');
    final eco = (vehicle['economico'] ??
            vehicle['eco'] ??
            vehicle['vehiculo'] ??
            'Unidad')
        .toString();
    final placas = (vehicle['placas'] ?? '').toString();
    final marca = (vehicle['marca'] ?? '').toString();
    final modelo = (vehicle['modelo'] ?? '').toString();
    final anio = (vehicle['anio'] ?? '').toString();

    final distancia = (vehicle['distancia'] ?? vehicle['km'] ?? '0').toString();
    final horasMov =
        (vehicle['horasMovimiento'] ?? vehicle['movimiento'] ?? '0').toString();
    final horasRalenti =
        (vehicle['horasRalenti'] ?? vehicle['ralenti'] ?? '0').toString();
    final rendimiento = (vehicle['rendimiento'] ?? 'N/A').toString();
    final viajes = (vehicle['viajes'] ?? 0).toString();
    final velMax =
        (vehicle['velocidadMaxima'] ?? vehicle['velMax'] ?? 0).toString();
    final alertas = (vehicle['alertas'] ?? 0).toString();

    final subtitulo = [
      if (marca.isNotEmpty) marca,
      if (modelo.isNotEmpty) modelo,
      if (anio.isNotEmpty) anio,
      if (placas.isNotEmpty) '[$placas]',
    ].join(' ');

    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: clampedScaler),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: mediaQuery.size.height * 0.90,
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          10,
          20,
          math.max(mediaQuery.padding.bottom, 20),
        ),
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4.5,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          eco,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitulo.isNotEmpty
                              ? subtitulo
                              : 'Telemetría de la unidad',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFBAE6FD)),
                      ),
                      child: Text(
                        '${f.format(desde)} - ${f.format(hasta)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0369A1),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Tarjeta de métricas
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _buildRow('Distancia recorrida', '$distancia km'),
                    const Divider(height: 14, color: Color(0xFFF1F5F9)),
                    _buildRow('Horas en movimiento', '$horasMov h'),
                    const Divider(height: 14, color: Color(0xFFF1F5F9)),
                    _buildRow('Horas en ralentí', '$horasRalenti h'),
                    const Divider(height: 14, color: Color(0xFFF1F5F9)),
                    _buildRow('Rendimiento promedio', rendimiento),
                    const Divider(height: 14, color: Color(0xFFF1F5F9)),
                    _buildRow('Viajes registrados', '$viajes viajes'),
                    const Divider(height: 14, color: Color(0xFFF1F5F9)),
                    _buildRow('Velocidad máxima', '$velMax km/h'),
                    const Divider(height: 14, color: Color(0xFFF1F5F9)),
                    _buildRow('Alertas generadas', '$alertas eventos'),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0284C7).withOpacity(0.30),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'Cerrar',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.2,
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

  Widget _buildRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }
}
