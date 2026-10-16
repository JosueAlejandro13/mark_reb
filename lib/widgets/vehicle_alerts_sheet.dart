import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:mark_v3/services/mark_api_client.dart';
import 'package:mark_v3/widgets/snackbar_top.dart';

/// Modal bottom sheet para consulta y atención de alertas telemáticas del vehículo (a=alertas y acción: alerta)
/// Cumple con las páginas 5, 8, 11 y 14 de la documentación MarkV3.1.
class VehicleAlertsSheet extends StatefulWidget {
  final int? idVehic;
  final String title;

  const VehicleAlertsSheet({
    super.key,
    this.idVehic,
    this.title = 'Alertas del GPS',
  });

  static Future<void> show(BuildContext context, {int? idVehic, String? title}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VehicleAlertsSheet(
        idVehic: idVehic,
        title: title ?? 'Alertas del GPS',
      ),
    );
  }

  @override
  State<VehicleAlertsSheet> createState() => _VehicleAlertsSheetState();
}

class _VehicleAlertsSheetState extends State<VehicleAlertsSheet> {
  final MarkApiClient _client = MarkApiClient.instance;

  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _alertas = [];

  @override
  void initState() {
    super.initState();
    _fetchAlerts();
  }

  Future<void> _fetchAlerts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await _client.getAlertas(
        idVehic: widget.idVehic,
        limite: 50,
      );
      if (mounted) {
        setState(() {
          _alertas = list;
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

  Future<void> _atenderAlerta(Map<String, dynamic> alerta) async {
    final idAlerta = int.tryParse((alerta['idAlerta'] ?? alerta['id'] ?? '0').toString()) ?? 0;
    if (idAlerta <= 0) return;

    try {
      final action = {
        'uuid': const Uuid().v4(),
        'tipo': 'alerta',
        'idAlerta': idAlerta,
        'obs': 'Atendida desde la App',
        'fecHor': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
      };

      await _client.sendActions([action]);
      if (mounted) {
        SnackbarTop.showSuccess(context, 'Alerta marcada como atendida.');
      }
      _fetchAlerts();
    } catch (e) {
      if (mounted) {
        SnackbarTop.showError(context, 'Error al marcar alerta: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
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
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.notifications_active_rounded,
                  color: Color(0xFFD97706),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.4,
                    ),
                  ),
                  const Text(
                    'Alertas del equipo GPS sin atender',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0284C7)),
                onPressed: _fetchAlerts,
              ),
            ],
          ),
          const SizedBox(height: 14),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0284C7)))
                : _errorMessage != null
                    ? Center(
                        child: Text(_errorMessage!,
                            style: const TextStyle(color: Color(0xFFEF4444))),
                      )
                    : _alertas.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_outline_rounded,
                                    size: 48, color: Color(0xFF10B981)),
                                SizedBox(height: 10),
                                Text(
                                  'Sin alertas pendientes',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Todas las alertas de telemetría están atendidas.',
                                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            itemCount: _alertas.length,
                            itemBuilder: (context, i) {
                              final item = _alertas[i];
                              final nombre = (item['nombre'] ?? item['alerta'] ?? item['tipo'] ?? 'Alerta GPS').toString();
                              final fecha = (item['fecha'] ?? '').toString();
                              final vel = item['velocidad']?.toString() ?? '0';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.warning_amber_rounded,
                                        color: Color(0xFFD97706), size: 22),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            nombre,
                                            style: const TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            '$fecha · Vel: $vel km/h',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    TextButton(
                                      style: TextButton.styleFrom(
                                        foregroundColor: const Color(0xFF0284C7),
                                      ),
                                      onPressed: () => _atenderAlerta(item),
                                      child: const Text('Atender',
                                          style: TextStyle(fontWeight: FontWeight.w700)),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
