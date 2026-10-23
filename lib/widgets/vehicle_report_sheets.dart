import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:mark_v3/services/ConnectionVehicles_/VehiclesCon_service.dart';
import 'package:mark_v3/widgets/loading_action_button.dart';
import 'package:mark_v3/widgets/snackbar_top.dart';

class VehicleReportProblemSheet extends StatefulWidget {
  final int idVehic;
  final String vehicleName;
  final String plates;

  const VehicleReportProblemSheet({
    super.key,
    required this.idVehic,
    required this.vehicleName,
    required this.plates,
  });

  static Future<void> show(
    BuildContext context, {
    required int idVehic,
    required String vehicleName,
    required String plates,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VehicleReportProblemSheet(
        idVehic: idVehic,
        vehicleName: vehicleName,
        plates: plates,
      ),
    );
  }

  @override
  State<VehicleReportProblemSheet> createState() =>
      _VehicleReportProblemSheetState();
}

class _VehicleReportProblemSheetState extends State<VehicleReportProblemSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _dueDateController = TextEditingController();

  String _selectedPriority = '2'; // 1: Baja, 2: Media, 3: Alta, 4: Crítica
  DateTime? _selectedDueDate;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Vencimiento por defecto sugerido a 3 días
    _selectedDueDate = DateTime.now().add(const Duration(days: 3));
    _dueDateController.text =
        DateFormat('dd / MM / yyyy').format(_selectedDueDate!);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _dueDateController.dispose();
    super.dispose();
  }

  Future<void> _submitProblem() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final formattedDueDate = _selectedDueDate != null
          ? DateFormat('yyyy-MM-dd').format(_selectedDueDate!)
          : null;

      await VehiclesconService().reportarProblemaVehiculo(
        idVehic: widget.idVehic,
        titulo: _titleController.text.trim(),
        descripcion: _descController.text.trim().isNotEmpty
            ? _descController.text.trim()
            : null,
        prioridad: _selectedPriority,
        vence: formattedDueDate,
      );

      if (mounted) {
        Navigator.pop(context);
        SnackbarTop.showSuccess(
          context,
          'Falla reportada. Se ha creado la tarea de mantenimiento para la unidad.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        final msg = e.toString().replaceFirst('Exception: ', '');
        SnackbarTop.showError(context, msg);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: bottomInset + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4.5,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEA580C), Color(0xFFF97316)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.build_circle_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Reportar Falla o Avería',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            '${widget.vehicleName} · ${widget.plates.toUpperCase()}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFED7AA)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 16, color: Color(0xFFEA580C)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'El reporte generará una orden de trabajo visible en Tareas de Flota y avisará a los encargados del vehículo.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF9A3412),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Título de la falla
                _buildFieldLabel('Falla o síntoma observado *'),
                TextFormField(
                  controller: _titleController,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                  decoration: _buildInputDecoration(
                    hint: 'ej. Ruido en frenos / Check engine encendido',
                    prefixIcon: Icons.warning_amber_rounded,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Por favor describe la falla observada.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Selector de Prioridad
                _buildFieldLabel('Prioridad de atención'),
                _buildPrioritySelector(),
                const SizedBox(height: 14),

                // Fecha límite sugerida
                _buildFieldLabel('Fecha de resolución sugerida'),
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDueDate ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      helpText: 'Fecha límite sugerida',
                      cancelText: 'Cancelar',
                      confirmText: 'Aceptar',
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.light(
                              primary: Color(0xFF0284C7),
                              onPrimary: Colors.white,
                              surface: Colors.white,
                              onSurface: Color(0xFF0F172A),
                            ),
                            dialogTheme: DialogThemeData(
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            textButtonTheme: TextButtonThemeData(
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF0284C7),
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                            datePickerTheme: DatePickerThemeData(
                              backgroundColor: Colors.white,
                              headerBackgroundColor: const Color(0xFF0284C7),
                              headerForegroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              dayStyle: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                              dayForegroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
                                if (states.contains(WidgetState.selected)) {
                                  return Colors.white;
                                }
                                if (states.contains(WidgetState.disabled)) {
                                  return const Color(0xFF94A3B8);
                                }
                                return const Color(0xFF0F172A);
                              }),
                              dayBackgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
                                if (states.contains(WidgetState.selected)) {
                                  return const Color(0xFF0284C7);
                                }
                                return null;
                              }),
                              todayBorder: const BorderSide(
                                color: Color(0xFF0284C7),
                                width: 1.5,
                              ),
                              todayForegroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
                                if (states.contains(WidgetState.selected)) {
                                  return Colors.white;
                                }
                                return const Color(0xFF0284C7);
                              }),
                              todayBackgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
                                if (states.contains(WidgetState.selected)) {
                                  return const Color(0xFF0284C7);
                                }
                                return Colors.transparent;
                              }),
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) {
                      setState(() {
                        _selectedDueDate = picked;
                        _dueDateController.text =
                            DateFormat('dd / MM / yyyy').format(picked);
                      });
                    }
                  },
                  child: IgnorePointer(
                    child: TextFormField(
                      controller: _dueDateController,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                      decoration: _buildInputDecoration(
                        hint: 'dd / mm / aaaa',
                        prefixIcon: Icons.calendar_today_rounded,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Descripción
                _buildFieldLabel('Detalles adicionales (opcional)'),
                TextFormField(
                  controller: _descController,
                  maxLines: 3,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF0F172A),
                  ),
                  decoration: _buildInputDecoration(
                    hint:
                        'Indica detalles como cuándo ocurre, ruidos, testigos en tablero o recomendaciones...',
                    prefixIcon: Icons.notes_rounded,
                  ),
                ),
                const SizedBox(height: 24),

                // Botones
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFFF1F5F9),
                          foregroundColor: const Color(0xFF475569),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed:
                            _isSubmitting ? null : () => Navigator.pop(context),
                        child: const Text(
                          'Cancelar',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: LoadingActionButton(
                        text: 'Reportar Falla',
                        icon: Icons.send_rounded,
                        isLoading: _isSubmitting,
                        height: 48,
                        borderRadius: 14,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEA580C), Color(0xFFC2410C)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        onPressed: _submitProblem,
                      ),
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

  Widget _buildPrioritySelector() {
    final priorities = [
      {'id': '1', 'name': 'Baja', 'color': const Color(0xFF10B981)},
      {'id': '2', 'name': 'Media', 'color': const Color(0xFF0284C7)},
      {'id': '3', 'name': 'Alta', 'color': const Color(0xFFEA580C)},
      {'id': '4', 'name': 'Crítica', 'color': const Color(0xFFEF4444)},
    ];

    return Row(
      children: priorities.map((p) {
        final isSelected = _selectedPriority == p['id'];
        final color = p['color'] as Color;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () =>
                  setState(() => _selectedPriority = p['id'] as String),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? color : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? color : const Color(0xFFE2E8F0),
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
                child: Center(
                  child: Text(
                    p['name'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w800 : FontWeight.w600,
                      color:
                          isSelected ? Colors.white : const Color(0xFF475569),
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

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: Color(0xFF475569),
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String hint,
    required IconData prefixIcon,
    Color? prefixIconColor,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        fontSize: 12.5,
        color: Color(0xFF94A3B8),
        fontWeight: FontWeight.w400,
      ),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      prefixIcon: Icon(
        prefixIcon,
        color: prefixIconColor ?? const Color(0xFF0284C7),
        size: 18,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
      ),
    );
  }
}

// ===========================================================================
// MODAL BOTTOM SHEET: INCIDENCIA / PERCANCE VIAL (tipo: incidenciaVehiculo)
// Cumple con las páginas 7, 8, 9 y 11 de la guía oficial MarkV3.1 (@Nelson)
// Se refleja en la métrica de Incidencias en Reportes Operativos y Bitácora.
// ===========================================================================
class VehicleReportIncidentSheet extends StatefulWidget {
  final int idVehic;
  final String vehicleName;
  final String plates;

  const VehicleReportIncidentSheet({
    super.key,
    required this.idVehic,
    required this.vehicleName,
    required this.plates,
  });

  static Future<void> show(
    BuildContext context, {
    required int idVehic,
    required String vehicleName,
    required String plates,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VehicleReportIncidentSheet(
        idVehic: idVehic,
        vehicleName: vehicleName,
        plates: plates,
      ),
    );
  }

  @override
  State<VehicleReportIncidentSheet> createState() =>
      _VehicleReportIncidentSheetState();
}

class _VehicleReportIncidentSheetState
    extends State<VehicleReportIncidentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _obsController = TextEditingController();

  int _selectedTipoId = 1;
  int _selectedSeverity = 1; // 1: Leve, 2: Moderada, 3: Grave
  bool _isSubmitting = false;

  List<Map<String, dynamic>> _tiposIncidencia = [
    {'id': 1, 'nombre': 'Mecánicas y Mantenimiento'},
    {'id': 2, 'nombre': 'Operativas'},
    {'id': 3, 'nombre': 'Seguridad y Emergencias'},
    {'id': 4, 'nombre': 'Rutas y Entregas'},
    {'id': 5, 'nombre': 'Administrativas'},
    {'id': 6, 'nombre': 'Tecnológicas'},
    {'id': 7, 'nombre': 'Conducta del Conductor'},
  ];

  @override
  void initState() {
    super.initState();
    _loadTipos();
  }

  Future<void> _loadTipos() async {
    final list = await VehiclesconService().obtenerTiposIncidencia();
    if (mounted && list.isNotEmpty) {
      setState(() {
        _tiposIncidencia = list;
        if (!_tiposIncidencia.any((t) =>
            (int.tryParse(t['id'].toString()) ?? 1) == _selectedTipoId)) {
          _selectedTipoId =
              int.tryParse(_tiposIncidencia.first['id'].toString()) ?? 1;
        }
      });
    }
  }

  Map<String, dynamic> _getTipoInfo(int id) {
    switch (id) {
      case 1:
        return {
          'icon': Icons.build_rounded,
          'color': const Color(0xFFEA580C),
        };
      case 2:
        return {
          'icon': Icons.local_shipping_rounded,
          'color': const Color(0xFF0284C7),
        };
      case 3:
        return {
          'icon': Icons.warning_amber_rounded,
          'color': const Color(0xFFDC2626),
        };
      case 4:
        return {
          'icon': Icons.alt_route_rounded,
          'color': const Color(0xFF10B981),
        };
      case 5:
        return {
          'icon': Icons.description_rounded,
          'color': const Color(0xFF6366F1),
        };
      case 6:
        return {
          'icon': Icons.devices_rounded,
          'color': const Color(0xFF8B5CF6),
        };
      case 7:
        return {
          'icon': Icons.person_outline_rounded,
          'color': const Color(0xFFD97706),
        };
      default:
        return {
          'icon': Icons.help_outline_rounded,
          'color': const Color(0xFF64748B),
        };
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _obsController.dispose();
    super.dispose();
  }

  Future<void> _submitIncident() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      await VehiclesconService().registrarIncidenciaVehiculo(
        idVehic: widget.idVehic,
        tipoIncidencia: _selectedTipoId,
        severidad: _selectedSeverity,
        nombre: _nameController.text.trim(),
        obs: _obsController.text.trim().isNotEmpty
            ? _obsController.text.trim()
            : null,
      );

      if (mounted) {
        Navigator.pop(context);
        SnackbarTop.showSuccess(
          context,
          'Incidencia vehicular registrada. Se actualizó la bitácora de la unidad.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        final msg = e.toString().replaceFirst('Exception: ', '');
        SnackbarTop.showError(context, msg);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: bottomInset + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4.5,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.car_crash_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Incidencia / Percance Vial',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            '${widget.vehicleName} · ${widget.plates.toUpperCase()}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 16, color: Color(0xFFDC2626)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Registra siniestros, averías o percances en campo. Quedará asentado en el historial y métricas de la unidad.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF991B1B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Tipo de Incidencia Dropdown
                _buildFieldLabel('Tipo de incidencia *'),
                DropdownButtonFormField2<int>(
                  value: _selectedTipoId,
                  isExpanded: true,
                  decoration: _buildInputDecoration(
                    hint: 'Selecciona el tipo',
                    prefixIcon:
                        _getTipoInfo(_selectedTipoId)['icon'] as IconData,
                    prefixIconColor:
                        _getTipoInfo(_selectedTipoId)['color'] as Color,
                  ).copyWith(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 11,
                      horizontal: 8,
                    ),
                  ),
                  items: _tiposIncidencia.map((item) {
                    final id = int.tryParse(item['id'].toString()) ?? 1;
                    final nombre = (item['nombre'] ?? '').toString();
                    final info = _getTipoInfo(id);
                    final iconData = info['icon'] as IconData;
                    final color = info['color'] as Color;
                    final isSelected = _selectedTipoId == id;
                    return DropdownMenuItem<int>(
                      value: id,
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(iconData, size: 15, color: color),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              nombre,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? const Color(0xFF0F172A)
                                    : const Color(0xFF334155),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isSelected)
                            Icon(Icons.check_rounded, size: 17, color: color),
                        ],
                      ),
                    );
                  }).toList(),
                  selectedItemBuilder: (context) {
                    return _tiposIncidencia.map((item) {
                      final nombre = (item['nombre'] ?? '').toString();
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          nombre,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList();
                  },
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedTipoId = val);
                  },
                  buttonStyleData: const ButtonStyleData(
                    padding: EdgeInsets.only(right: 8),
                  ),
                  iconStyleData: const IconStyleData(
                    icon: Icon(
                      Icons.arrow_drop_down_rounded,
                      color: Color(0xFF64748B),
                      size: 24,
                    ),
                  ),
                  dropdownStyleData: DropdownStyleData(
                    maxHeight: 280,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withOpacity(0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                  menuItemStyleData: const MenuItemStyleData(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    height: 42,
                  ),
                ),
                const SizedBox(height: 14),

                // Resumen / Título de la incidencia
                _buildFieldLabel('Resumen / Nombre del percance *'),
                TextFormField(
                  controller: _nameController,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                  decoration: _buildInputDecoration(
                    hint: 'ej. Ponchadura en autopista / Cristal estrellado',
                    prefixIcon: Icons.label_important_outline_rounded,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Ingresa un nombre o resumen de la incidencia.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Severidad (1-3)
                _buildFieldLabel('Nivel de severidad'),
                _buildSeveritySelector(),
                const SizedBox(height: 14),

                // Observaciones adicionales
                _buildFieldLabel('Observaciones / Lugar del hecho'),
                TextFormField(
                  controller: _obsController,
                  maxLines: 3,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF0F172A),
                  ),
                  decoration: _buildInputDecoration(
                    hint:
                        'Indica detalles como ubicación aproximada, afectación o si requirió grúa/asistencia...',
                    prefixIcon: Icons.location_on_outlined,
                  ),
                ),
                const SizedBox(height: 24),

                // Botones
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFFF1F5F9),
                          foregroundColor: const Color(0xFF475569),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed:
                            _isSubmitting ? null : () => Navigator.pop(context),
                        child: const Text(
                          'Cancelar',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: LoadingActionButton(
                        text: 'Registrar Incidencia',
                        icon: Icons.check_rounded,
                        isLoading: _isSubmitting,
                        height: 48,
                        borderRadius: 14,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        onPressed: _submitIncident,
                      ),
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

  Widget _buildSeveritySelector() {
    final severities = [
      {'val': 1, 'name': '1 · Leve', 'color': const Color(0xFF10B981)},
      {'val': 2, 'name': '2 · Moderada', 'color': const Color(0xFFEA580C)},
      {'val': 3, 'name': '3 · Grave', 'color': const Color(0xFFEF4444)},
    ];

    return Row(
      children: severities.map((s) {
        final val = s['val'] as int;
        final isSelected = _selectedSeverity == val;
        final color = s['color'] as Color;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _selectedSeverity = val),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? color : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? color : const Color(0xFFE2E8F0),
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
                child: Center(
                  child: Text(
                    s['name'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w800 : FontWeight.w600,
                      color:
                          isSelected ? Colors.white : const Color(0xFF475569),
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

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: Color(0xFF475569),
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String hint,
    required IconData prefixIcon,
    Color? prefixIconColor,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        fontSize: 12.5,
        color: Color(0xFF94A3B8),
        fontWeight: FontWeight.w400,
      ),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      prefixIcon: Icon(
        prefixIcon,
        color: prefixIconColor ?? const Color(0xFF0284C7),
        size: 18,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
      ),
    );
  }
}
