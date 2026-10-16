import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:mark_v3/services/mark_api_client.dart';
import 'package:mark_v3/widgets/snackbar_top.dart';

class MaintenancePage extends ConsumerStatefulWidget {
  final Map<String, dynamic> vehicle;

  const MaintenancePage({super.key, required this.vehicle});

  @override
  ConsumerState<MaintenancePage> createState() => _MaintenancePageState();
}

class _MaintenancePageState extends ConsumerState<MaintenancePage> {
  final MarkApiClient _client = MarkApiClient.instance;

  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic> _vehicleFicha = {};
  List<dynamic> _ultimosServicios = [];
  List<dynamic> _preventivosPendientes = [];

  int get _idVehic =>
      int.tryParse((widget.vehicle['idVehic'] ?? widget.vehicle['id'] ?? '0').toString()) ?? 0;

  @override
  void initState() {
    super.initState();
    _loadFicha();
  }

  Future<void> _loadFicha() async {
    if (_idVehic <= 0) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Identificador de vehículo no válido.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final ficha = await _client.getVehiculo(_idVehic);
      final servicios = ficha['ultimosServicios'] ?? ficha['servicios'] ?? [];
      final preventivos = ficha['preventivosPendientes'] ?? ficha['preventivos'] ?? [];

      if (mounted) {
        setState(() {
          _vehicleFicha = ficha;
          _ultimosServicios = servicios is List ? servicios : [];
          _preventivosPendientes = preventivos is List ? preventivos : [];
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

  void _showAddServiceModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddServiceModal(
        idVehic: _idVehic,
        onServiceAdded: _loadFicha,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final eco = widget.vehicle['economic'] ?? widget.vehicle['eco'] ?? 'Vehículo';
    final plates = widget.vehicle['plates'] ?? widget.vehicle['placas'] ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF0F172A), size: 19),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mantenimiento · $eco',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.4,
              ),
            ),
            if (plates.toString().isNotEmpty)
              Text(
                'Placas: $plates',
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0284C7)),
            onPressed: _loadFicha,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0284C7),
        elevation: 4,
        onPressed: _showAddServiceModal,
        icon: const Icon(Icons.build_circle_rounded, color: Colors.white),
        label: const Text(
          'Registrar Servicio',
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF0284C7)))
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.build_rounded, size: 48, color: Color(0xFFEF4444)),
                          const SizedBox(height: 12),
                          Text(_errorMessage!, textAlign: TextAlign.center),
                          const SizedBox(height: 14),
                          ElevatedButton(
                            onPressed: _loadFicha,
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 85),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Preventivos Pendientes
                        if (_preventivosPendientes.isNotEmpty) ...[
                          const Text(
                            'PREVENTIVOS PENDIENTES',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64748B),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ..._preventivosPendientes.map((prev) {
                            final nombre = (prev['nombre'] ?? prev['servicio'] ?? 'Servicio').toString();
                            final kmFaltan = (prev['kmFaltan'] ?? prev['km'] ?? '0').toString();
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFFBEB),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFFDE68A)),
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
                                            color: Color(0xFF92400E),
                                          ),
                                        ),
                                        Text(
                                          'Faltan: $kmFaltan km para el mantenimiento',
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            color: Color(0xFFB45309),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 16),
                        ],

                        // Historial de Servicios
                        const Text(
                          'HISTORIAL DE SERVICIOS REALIZADOS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),

                        if (_ultimosServicios.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: const Column(
                              children: [
                                Icon(Icons.build_circle_outlined,
                                    size: 44, color: Color(0xFF94A3B8)),
                                SizedBox(height: 10),
                                Text(
                                  'Sin servicios registrados',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'No se han capturado mantenimientos previos en esta unidad.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          )
                        else
                          ..._ultimosServicios.map((s) {
                            final titulo = (s['taller'] ?? s['proveedor'] ?? s['servicio'] ?? 'Mantenimiento').toString();
                            final fecha = (s['inicio'] ?? s['fecha'] ?? '').toString();
                            final costo = s['costo'] ?? s['monto'];
                            final obs = (s['obs'] ?? s['descripcion'] ?? '').toString();

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
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
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE0F2FE),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.build_rounded,
                                        size: 18, color: Color(0xFF0284C7)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          titulo,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        if (fecha.isNotEmpty)
                                          Text(
                                            'Fecha: $fecha',
                                            style: const TextStyle(
                                                fontSize: 11, color: Color(0xFF64748B)),
                                          ),
                                        if (obs.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            obs,
                                            style: const TextStyle(
                                                fontSize: 12, color: Color(0xFF334155)),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (costo != null)
                                    Text(
                                      '\$$costo',
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF047857),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _AddServiceModal extends StatefulWidget {
  final int idVehic;
  final VoidCallback onServiceAdded;

  const _AddServiceModal({required this.idVehic, required this.onServiceAdded});

  @override
  State<_AddServiceModal> createState() => _AddServiceModalState();
}

class _AddServiceModalState extends State<_AddServiceModal> {
  final _proveedorCtrl = TextEditingController();
  final _manoObraCtrl = TextEditingController();
  final _refaccionesCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();

  int _origen = 0; // 0 correctivo · 1 inspección · 4 preventivo
  DateTime _inicio = DateTime.now();
  DateTime _fin = DateTime.now();
  bool _isSaving = false;

  @override
  void dispose() {
    _proveedorCtrl.dispose();
    _manoObraCtrl.dispose();
    _refaccionesCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final taller = _proveedorCtrl.text.trim();
    if (taller.isEmpty) {
      SnackbarTop.showError(context, 'Ingresa el nombre del proveedor o taller.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final manoObra = double.tryParse(_manoObraCtrl.text.trim()) ?? 0.0;
      final refacciones = double.tryParse(_refaccionesCtrl.text.trim()) ?? 0.0;

      final action = {
        'uuid': const Uuid().v4(),
        'tipo': 'servicio',
        'idVehic': widget.idVehic,
        'idProveedor': 1, // ID por omisión o seleccionado
        'inicio': DateFormat('yyyy-MM-dd').format(_inicio),
        'fin': DateFormat('yyyy-MM-dd').format(_fin),
        'manoObra': manoObra,
        'refacciones': refacciones,
        'origen': _origen,
        'obs': _obsCtrl.text.trim(),
        'fecHor': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
      };

      await MarkApiClient.instance.sendActions([action]);
      widget.onServiceAdded();
      if (mounted) {
        Navigator.pop(context);
        SnackbarTop.showSuccess(context, 'Servicio registrado correctamente.');
      }
    } catch (e) {
      if (mounted) {
        SnackbarTop.showError(context, 'Error al registrar servicio: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
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
            const Text(
              'Registrar Servicio de Mantenimiento',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _proveedorCtrl,
              decoration: InputDecoration(
                labelText: 'Proveedor / Taller mecánico *',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: _origen,
              decoration: InputDecoration(
                labelText: 'Tipo de Mantenimiento',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: const [
                DropdownMenuItem(value: 0, child: Text('Correctivo (Reparación)')),
                DropdownMenuItem(value: 4, child: Text('Preventivo (Afinación/Frenos/Aceite)')),
                DropdownMenuItem(value: 1, child: Text('Derivado de Inspección')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _origen = val);
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _manoObraCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Mano de Obra (\$)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _refaccionesCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Refacciones (\$)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _obsCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Observaciones / Trabajos realizados',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isSaving ? null : _submit,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'Guardar Servicio',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
