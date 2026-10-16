import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mark_v3/services/mark_api_client.dart';

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

  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _reportData;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _hasta = now;
    _desde = now.subtract(const Duration(days: 7));
    _fetchReport();
  }

  Future<void> _fetchReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final desdeStr = DateFormat('yyyy-MM-dd').format(_desde);
      final hastaStr = DateFormat('yyyy-MM-dd').format(_hasta);

      final data = await _client.getReportes(
        desde: desdeStr,
        hasta: hastaStr,
        idVehic: widget.idVehic,
      );

      if (mounted) {
        setState(() {
          _reportData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 120)),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _desde, end: _hasta),
    );

    if (picked != null) {
      final diff = picked.end.difference(picked.start).inDays;
      if (diff > 31) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('El rango máximo de consulta es de 31 días.'),
              backgroundColor: Color(0xFFEF4444),
            ),
          );
        }
        return;
      }
      setState(() {
        _desde = picked.start;
        _hasta = picked.end;
      });
      _fetchReport();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final f = DateFormat('dd/MM/yyyy');

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 19,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reportes Operativos',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                letterSpacing: -0.5,
              ),
            ),
            Text(
              'Telemetría, combustible y rendimiento',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w400,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0284C7)),
            onPressed: _fetchReport,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Selector de Rango de Fechas
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: InkWell(
                onTap: _selectDateRange,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month_rounded,
                          size: 18, color: Color(0xFF0284C7)),
                      const SizedBox(width: 10),
                      Text(
                        'Rango: ${f.format(_desde)} — ${f.format(_hasta)}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.swap_horiz_rounded,
                          size: 18, color: Color(0xFF64748B)),
                    ],
                  ),
                ),
              ),
            ),

            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFF0284C7)),
                    )
                  : _errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.analytics_outlined,
                                    size: 48, color: Color(0xFFEF4444)),
                                const SizedBox(height: 12),
                                Text(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: Color(0xFF64748B), fontSize: 13),
                                ),
                                const SizedBox(height: 14),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0284C7),
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: _fetchReport,
                                  child: const Text('Reintentar'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _buildReportContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportContent() {
    final rawData = _reportData ?? {};
    final vehiculos = rawData['vehiculos'] ?? rawData['data'] ?? [];

    if (vehiculos is List && vehiculos.isNotEmpty) {
      return ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: vehiculos.length,
        itemBuilder: (context, i) {
          final v = vehiculos[i];
          if (v is! Map<String, dynamic>) return const SizedBox.shrink();
          return _buildVehicleReportCard(v);
        },
      );
    }

    // Si viene como resumen global directo
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildMetricsGrid(rawData),
          const SizedBox(height: 16),
          _buildDetailTile(Icons.alt_route_rounded, 'Viajes Registrados',
              '${rawData['viajes'] ?? 0} viajes'),
          _buildDetailTile(Icons.speed_rounded, 'Velocidad Máxima',
              '${rawData['velocidadMaxima'] ?? rawData['velMax'] ?? 0} km/h'),
          _buildDetailTile(Icons.local_gas_station_rounded, 'Consumo de Combustible',
              '${rawData['combustible'] ?? 0} l'),
          _buildDetailTile(Icons.warning_amber_rounded, 'Alertas Generadas',
              '${rawData['alertas'] ?? 0} eventos'),
          _buildDetailTile(Icons.report_problem_outlined, 'Incidencias',
              '${rawData['incidencias'] ?? 0} incidencias'),
        ],
      ),
    );
  }

  Widget _buildVehicleReportCard(Map<String, dynamic> v) {
    final eco = (v['economico'] ?? v['eco'] ?? v['vehiculo'] ?? 'Unidad').toString();
    final placas = (v['placas'] ?? '').toString();
    final distancia = (v['distancia'] ?? v['km'] ?? '0').toString();
    final horasMov = (v['horasMovimiento'] ?? v['movimiento'] ?? '0').toString();
    final horasRalenti = (v['horasRalenti'] ?? v['ralenti'] ?? '0').toString();
    final rendimiento = (v['rendimiento'] ?? 'N/A').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.03),
            blurRadius: 8,
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
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.directions_car_rounded,
                    color: Color(0xFF0369A1), size: 18),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    eco,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  if (placas.isNotEmpty)
                    Text(
                      'Placas: $placas',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildMiniMetric('Distancia', '$distancia km', Icons.straighten_rounded),
              _buildMiniMetric('En Movimiento', '$horasMov h', Icons.timer_outlined),
              _buildMiniMetric('Ralentí', '$horasRalenti h', Icons.pause_circle_outline),
              _buildMiniMetric('Rendimiento', rendimiento, Icons.eco_outlined),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetric(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 15, color: const Color(0xFF0284C7)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(Map<String, dynamic> data) {
    final dist = data['distancia']?.toString() ?? '0';
    final horas = data['horasMovimiento']?.toString() ?? '0';

    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            'Distancia Total',
            '$dist km',
            Icons.route_rounded,
            const [Color(0xFF0284C7), Color(0xFF38BDF8)],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            'Horas Activas',
            '$horas h',
            Icons.access_time_filled_rounded,
            const [Color(0xFF0F172A), Color(0xFF334155)],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(
      String title, String value, IconData icon, List<Color> colors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colors.first.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          Text(
            title,
            style: const TextStyle(fontSize: 11, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailTile(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF0284C7)),
          const SizedBox(width: 12),
          Text(label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}
