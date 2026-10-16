import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:mark_v3/services/mark_api_client.dart';
import 'package:mark_v3/widgets/snackbar_top.dart';

class TasksPage extends ConsumerStatefulWidget {
  final int? idVehic;
  final int? initialTaskId;

  const TasksPage({super.key, this.idVehic, this.initialTaskId});

  @override
  ConsumerState<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends ConsumerState<TasksPage> {
  final MarkApiClient _client = MarkApiClient.instance;

  String _filterEstado = 'abiertas'; // 'abiertas' | 'todas' | '1' | '2' | '3' | '5'
  String _filterMias = 'todas'; // 'todas' | 'creadas' | 'asignadas'

  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _tareas = [];

  @override
  void initState() {
    super.initState();
    _loadTareas();
  }

  Future<void> _loadTareas() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
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
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Color _getStatusColor(dynamic estado) {
    final s = estado?.toString() ?? '1';
    switch (s) {
      case '1':
      case 'abierta':
        return const Color(0xFF0284C7); // Sky blue
      case '2':
      case 'proceso':
        return const Color(0xFFF59E0B); // Amber
      case '3':
      case 'resuelta':
        return const Color(0xFF10B981); // Emerald
      case '5':
      case 'cancelada':
        return const Color(0xFFEF4444); // Rose
      default:
        return const Color(0xFF64748B);
    }
  }

  String _getStatusText(dynamic estado) {
    final s = estado?.toString() ?? '1';
    switch (s) {
      case '1':
        return 'Abierta';
      case '2':
        return 'En Proceso';
      case '3':
        return 'Resuelta';
      case '5':
        return 'Cancelada';
      default:
        return 'Estado $s';
    }
  }

  void _showTaskDetailSheet(Map<String, dynamic> item) async {
    final idTarea = int.tryParse((item['idTarea'] ?? item['id'] ?? '0').toString()) ?? 0;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
              'Tareas de Flota',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                letterSpacing: -0.5,
              ),
            ),
            Text(
              'Gestión de actividades y órdenes de trabajo',
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
            tooltip: 'Refrescar',
            onPressed: _loadTareas,
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0284C7),
        elevation: 4,
        onPressed: _showCreateTaskSheet,
        icon: const Icon(Icons.add_task_rounded, color: Colors.white),
        label: const Text(
          'Nueva Tarea',
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filtros rápidos estilo Apple Segmented
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildFilterChip('Abiertas', _filterEstado == 'abiertas', () {
                      setState(() => _filterEstado = 'abiertas');
                      _loadTareas();
                    }),
                    const SizedBox(width: 8),
                    _buildFilterChip('Todas', _filterEstado == 'todas', () {
                      setState(() => _filterEstado = 'todas');
                      _loadTareas();
                    }),
                    const SizedBox(width: 8),
                    _buildFilterChip('En Proceso', _filterEstado == '2', () {
                      setState(() => _filterEstado = '2');
                      _loadTareas();
                    }),
                    const SizedBox(width: 8),
                    _buildFilterChip('Resueltas', _filterEstado == '3', () {
                      setState(() => _filterEstado = '3');
                      _loadTareas();
                    }),
                    const SizedBox(width: 12),
                    Container(height: 20, width: 1, color: const Color(0xFFCBD5E1)),
                    const SizedBox(width: 12),
                    _buildFilterChip('Asignadas a mí', _filterMias == 'asignadas', () {
                      setState(() =>
                          _filterMias = _filterMias == 'asignadas' ? 'todas' : 'asignadas');
                      _loadTareas();
                    }),
                  ],
                ),
              ),
            ),

            // Contenido principal
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
                                const Icon(Icons.error_outline_rounded,
                                    size: 48, color: Color(0xFFEF4444)),
                                const SizedBox(height: 12),
                                Text(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: Color(0xFF64748B), fontSize: 13),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0284C7),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: _loadTareas,
                                  child: const Text('Reintentar'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _tareas.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.assignment_turned_in_outlined,
                                      size: 56, color: Colors.grey.shade400),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'No hay tareas en esta categoría',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF334155),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Todo el trabajo operativo está al día.',
                                    style: TextStyle(
                                        fontSize: 12.5, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                              itemCount: _tareas.length,
                              itemBuilder: (context, index) {
                                final item = _tareas[index];
                                return _buildTaskCard(item);
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0284C7) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF0284C7).withOpacity(0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> item) {
    final titulo = (item['titulo'] ?? item['title'] ?? 'Sin título').toString();
    final descripcion = (item['descripcion'] ?? item['description'] ?? '').toString();
    final estado = item['estado'] ?? item['status'] ?? 1;
    final prioridad = (item['prioridad'] ?? item['priority'] ?? 'Normal').toString();
    final vence = (item['vence'] ?? item['dueDate'] ?? '').toString();
    final vehiculoEco = (item['economico'] ?? item['vehiculo'] ?? '').toString();

    final statusColor = _getStatusColor(estado);
    final statusText = _getStatusText(estado);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.9),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showTaskDetailSheet(item),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (prioridad.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          prioridad,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (vehiculoEco.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.directions_car_rounded,
                                size: 11, color: Color(0xFF0369A1)),
                            const SizedBox(width: 4),
                            Text(
                              vehiculoEco,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0369A1),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const Spacer(),
                    const Icon(Icons.chevron_right_rounded,
                        size: 18, color: Color(0xFF94A3B8)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
                if (descripcion.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    descripcion,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                      height: 1.3,
                    ),
                  ),
                ],
                if (vence.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded,
                          size: 12, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 5),
                      Text(
                        'Vence: $vence',
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
          ),
        ),
      ),
    );
  }
}

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

  Future<void> _updateState(int nuevoEstado) async {
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
        SnackbarTop.showSuccess(context, 'Estado de la tarea actualizado.');
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

  @override
  Widget build(BuildContext context) {
    final data = _taskDetail ?? widget.taskSummary;
    final titulo = (data['titulo'] ?? data['title'] ?? 'Detalle de Tarea').toString();
    final descripcion = (data['descripcion'] ?? data['description'] ?? '').toString();
    final estado = int.tryParse((data['estado'] ?? 1).toString()) ?? 1;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
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

          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          if (descripcion.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              descripcion,
              style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
            ),
          ],

          const SizedBox(height: 16),

          // Acciones de cambio de estado (Ronda 133)
          const Text(
            'CAMBIAR ESTADO',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildActionBtn('Abierta (1)', estado == 1, () => _updateState(1)),
                const SizedBox(width: 8),
                _buildActionBtn('En Proceso (2)', estado == 2, () => _updateState(2)),
                const SizedBox(width: 8),
                _buildActionBtn('Resuelta (3)', estado == 3, () => _updateState(3)),
                const SizedBox(width: 8),
                _buildActionBtn('Cancelada (5)', estado == 5, () => _updateState(5)),
              ],
            ),
          ),

          const SizedBox(height: 18),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 12),

          // Comentarios de la tarea
          const Text(
            'BITÁCORA Y COMENTARIOS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0284C7)))
                : _comentarios.isEmpty
                    ? const Center(
                        child: Text(
                          'No hay comentarios aún.',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _comentarios.length,
                        itemBuilder: (ctx, i) {
                          final c = _comentarios[i];
                          final autor = (c['autor'] ?? c['nombre'] ?? 'Usuario').toString();
                          final texto = (c['texto'] ?? c['comentario'] ?? '').toString();
                          final fecha = (c['fecha'] ?? '').toString();

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      autor,
                                      style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F172A)),
                                    ),
                                    Text(
                                      fecha,
                                      style: const TextStyle(
                                          fontSize: 10, color: Color(0xFF94A3B8)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  texto,
                                  style: const TextStyle(
                                      fontSize: 12, color: Color(0xFF334155)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),

          // Input para nuevo comentario
          Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              top: 8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'Escribe un comentario...',
                      hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _isSending ? null : _addComment,
                  icon: _isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded, color: Color(0xFF0284C7)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBtn(String label, bool isCurrent, VoidCallback onTap) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isCurrent ? const Color(0xFF0284C7) : const Color(0xFFF1F5F9),
        foregroundColor: isCurrent ? Colors.white : const Color(0xFF334155),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      onPressed: _isSending ? null : onTap,
      child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

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
  String _prioridad = 'Normal';
  DateTime _vence = DateTime.now().add(const Duration(days: 3));
  bool _isSaving = false;

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final titulo = _tituloCtrl.text.trim();
    if (titulo.isEmpty) {
      SnackbarTop.showError(context, 'El título de la tarea es obligatorio.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final action = {
        'uuid': const Uuid().v4(),
        'tipo': 'tarea',
        'titulo': titulo,
        if (_descCtrl.text.trim().isNotEmpty) 'descripcion': _descCtrl.text.trim(),
        'prioridad': _prioridad,
        'vence': DateFormat('yyyy-MM-dd').format(_vence),
        if (widget.idVehic != null) 'idVehic': widget.idVehic,
        'fecHor': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
      };

      await MarkApiClient.instance.sendActions([action]);
      widget.onTaskCreated();
      if (mounted) {
        Navigator.pop(context);
        SnackbarTop.showSuccess(context, 'Tarea creada exitosamente.');
      }
    } catch (e) {
      if (mounted) {
        SnackbarTop.showError(context, 'Error al crear tarea: $e');
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
            'Nueva Tarea de Flota',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _tituloCtrl,
            decoration: InputDecoration(
              labelText: 'Título de la tarea *',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Descripción / Instrucciones (opcional)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _prioridad,
                  decoration: InputDecoration(
                    labelText: 'Prioridad',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Baja', child: Text('Baja')),
                    DropdownMenuItem(value: 'Normal', child: Text('Normal')),
                    DropdownMenuItem(value: 'Alta', child: Text('Alta')),
                    DropdownMenuItem(value: 'Urgente', child: Text('Urgente')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _prioridad = val);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _vence,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setState(() => _vence = picked);
                  },
                  icon: const Icon(Icons.event_rounded, size: 18),
                  label: Text(
                    DateFormat('dd/MM/yyyy').format(_vence),
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ),
              ),
            ],
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
                      'Guardar Tarea',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
