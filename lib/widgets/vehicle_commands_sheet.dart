import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mark_v3/services/mark_api_client.dart';
import 'package:mark_v3/widgets/snackbar_top.dart';

/// Modal bottom sheet para envío de comandos telemáticos en vivo (a=comandos y a=comando)
class VehicleCommandsSheet extends StatefulWidget {
  final int idVehic;
  final String vehicleName;
  final String plates;

  const VehicleCommandsSheet({
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
      builder: (ctx) => VehicleCommandsSheet(
        idVehic: idVehic,
        vehicleName: vehicleName,
        plates: plates,
      ),
    );
  }

  @override
  State<VehicleCommandsSheet> createState() => _VehicleCommandsSheetState();
}

class _VehicleCommandsSheetState extends State<VehicleCommandsSheet> {
  final MarkApiClient _client = MarkApiClient.instance;

  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _comandos = [];

  Map<String, dynamic>? _selectedCommand;
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSending = false;
  String? _pinError;

  @override
  void initState() {
    super.initState();
    _fetchCommands();
  }

  @override
  void dispose() {
    _pinController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchCommands() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await _client.getComandos(widget.idVehic);
      if (mounted) {
        setState(() {
          _comandos = list;
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

  void _onSelectCommand(Map<String, dynamic> cmd) {
    final cod = cmd['cod'] ?? cmd['id'];
    setState(() {
      if ((_selectedCommand?['cod'] ?? _selectedCommand?['id']) == cod) {
        // Tocar el mismo comando lo deselecciona
        _selectedCommand = null;
      } else {
        _selectedCommand = cmd;
      }
      _pinController.clear();
      _pinError = null;
    });
  }

  Future<void> _sendCommand() async {
    if (_selectedCommand == null) return;
    final pin = _pinController.text.trim();
    if (pin.isEmpty) {
      setState(() => _pinError = 'Ingresa tu código de seguridad.');
      return;
    }

    final cod = int.tryParse(
            (_selectedCommand!['cod'] ?? _selectedCommand!['id'] ?? '0')
                .toString()) ??
        0;
    if (cod <= 0) {
      setState(() => _pinError = 'Código de comando no válido.');
      return;
    }

    setState(() {
      _isSending = true;
      _pinError = null;
    });

    try {
      final res = await _client.enviarComando(
        idVehic: widget.idVehic,
        cod: cod,
        codigo: pin,
      );

      final ok = res['ok'] == true;
      final mensaje =
          (res['mensaje'] ?? 'Comando ejecutado exitosamente.').toString();

      if (ok) {
        if (mounted) {
          Navigator.pop(context);
          SnackbarTop.showSuccess(context, mensaje, title: 'Comando Enviado');
        }
      } else {
        final error =
            (res['error'] ?? 'No se pudo enviar el comando.').toString();
        final codigoMal = res['codigoMal'] == true;
        final bloqueadoMin = res['bloqueadoMin'];

        String displayError = error;
        if (codigoMal) {
          displayError = 'Código de seguridad incorrecto.';
        } else if (bloqueadoMin != null) {
          displayError =
              'Demasiados intentos fallidos. Espera $bloqueadoMin min.';
        }

        if (mounted) {
          setState(() {
            _pinError = displayError;
            _isSending = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _pinError = 'Error de conexión: $e';
          _isSending = false;
        });
      }
    }
  }

  _CmdVisualMeta _resolveCommandMeta(String titulo) {
    final t = titulo.toLowerCase();
    if (t.contains('paro') ||
        t.contains('apagar') ||
        t.contains('bloqueo') ||
        t.contains('inmoviliz') ||
        t.contains('cortar')) {
      return const _CmdVisualMeta(
        icon: Icons.no_crash_rounded,
        color: Color(0xFFDC2626),
        bgColor: Color(0xFFFEF2F2),
        isEmergency: true,
      );
    }
    if (t.contains('ubicar') ||
        t.contains('localiz') ||
        t.contains('posici') ||
        t.contains('rastr') ||
        t.contains('donde')) {
      return const _CmdVisualMeta(
        icon: Icons.my_location_rounded,
        color: Color(0xFF0284C7),
        bgColor: Color(0xFFF0F9FF),
      );
    }
    if (t.contains('reiniciar') ||
        t.contains('reset') ||
        t.contains('reboot') ||
        t.contains('gps')) {
      return const _CmdVisualMeta(
        icon: Icons.restart_alt_rounded,
        color: Color(0xFF4F46E5),
        bgColor: Color(0xFFEEF2FF),
      );
    }
    if (t.contains('bater') ||
        t.contains('energ') ||
        t.contains('voltaj') ||
        t.contains('respaldo')) {
      return const _CmdVisualMeta(
        icon: Icons.battery_charging_full_rounded,
        color: Color(0xFF059669),
        bgColor: Color(0xFFECFDF5),
      );
    }
    if (t.contains('salida') ||
        t.contains('abrir') ||
        t.contains('puerta') ||
        t.contains('chapa') ||
        t.contains('seguro') ||
        t.contains('teclado')) {
      return const _CmdVisualMeta(
        icon: Icons.meeting_room_rounded,
        color: Color(0xFFD97706),
        bgColor: Color(0xFFFFFBEB),
      );
    }
    if (t.contains('sirena') ||
        t.contains('claxon') ||
        t.contains('alarma') ||
        t.contains('audio') ||
        t.contains('bocina')) {
      return const _CmdVisualMeta(
        icon: Icons.volume_up_rounded,
        color: Color(0xFF7C3AED),
        bgColor: Color(0xFFF5F3FF),
      );
    }
    if (t.contains('activar') ||
        t.contains('encender') ||
        t.contains('habilitar') ||
        t.contains('arranque')) {
      return const _CmdVisualMeta(
        icon: Icons.flash_on_rounded,
        color: Color(0xFF2563EB),
        bgColor: Color(0xFFEFF6FF),
      );
    }
    return const _CmdVisualMeta(
      icon: Icons.electrical_services_rounded,
      color: Color(0xFF0284C7),
      bgColor: Color(0xFFF0F9FF),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.88;

    final query = _searchQuery.trim().toLowerCase();
    final filteredComandos = query.isEmpty
        ? _comandos
        : _comandos.where((cmd) {
            final tit =
                (cmd['titulo'] ?? cmd['nombre'] ?? '').toString().toLowerCase();
            final grp = (cmd['grupo'] ?? '').toString().toLowerCase();
            return tit.contains(query) || grp.contains(query);
          }).toList();

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle & Header estático
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Column(
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
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Comandos',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              '${widget.vehicleName} · ${widget.plates}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF64748B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),

            // Contenido desplazable con scroll suave
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  bottomInset + 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40.0),
                        child: Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFF0284C7)),
                        ),
                      )
                    else if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24.0),
                        child: Center(
                          child: Column(
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                color: Color(0xFFEF4444),
                                size: 36,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _errorMessage!,
                                style: const TextStyle(
                                    color: Color(0xFFEF4444), fontSize: 13),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              TextButton.icon(
                                onPressed: _fetchCommands,
                                icon:
                                    const Icon(Icons.refresh_rounded, size: 16),
                                label: const Text('Reintentar'),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (_comandos.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.lock_clock_rounded,
                                size: 40, color: Color(0xFF94A3B8)),
                            SizedBox(height: 10),
                            Text(
                              'Sin comandos disponibles',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF334155),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Este equipo GPS no tiene comandos habilitados o tu perfil no cuenta con permisos.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 11.5, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      // Buscador estilo reports_page (Apple HIG)
                      if (_comandos.length > 2) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 3),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFFE2E8F0),
                              width: 1.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    const Color(0xFF0A1E34).withOpacity(0.04),
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
                                    hintText:
                                        'Buscar comando telemático o grupo...',
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
                                    contentPadding:
                                        EdgeInsets.symmetric(vertical: 10),
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
                        ),
                      ],

                      // Título de la sección y contador
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'SELECCIONA UN COMANDO',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64748B),
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            _searchQuery.trim().isEmpty
                                ? '${_comandos.length} disponible${_comandos.length == 1 ? '' : 's'}'
                                : '${filteredComandos.length} de ${_comandos.length}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      if (filteredComandos.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              vertical: 24, horizontal: 20),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
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
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.search_off_rounded,
                                  color: Color(0xFF94A3B8),
                                  size: 26,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Sin resultados para "$_searchQuery"',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Verifica el nombre del comando o grupo telemático.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        // GRID DE 2 COLUMNAS (2 COMANDOS POR FILA)
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filteredComandos.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            mainAxisExtent: 74,
                          ),
                          itemBuilder: (context, index) {
                            final cmd = filteredComandos[index];
                            final cod = cmd['cod'] ?? cmd['id'];
                            final titulo = (cmd['titulo'] ??
                                    cmd['nombre'] ??
                                    'Comando $cod')
                                .toString();
                            final rawGrupo =
                                (cmd['grupo'] ?? '').toString().trim();
                            final grupo = (rawGrupo.isNotEmpty &&
                                    rawGrupo.toLowerCase() != 'control')
                                ? rawGrupo
                                : '';

                            final isSelected = _selectedCommand != null &&
                                ((_selectedCommand!['cod'] ??
                                        _selectedCommand!['id']) ==
                                    cod);
                            final meta = _resolveCommandMeta(titulo);

                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _onSelectCommand(cmd),
                                borderRadius: BorderRadius.circular(14),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? (meta.isEmergency
                                            ? const Color(0xFFFEF2F2)
                                            : const Color(0xFFF0F9FF))
                                        : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isSelected
                                          ? (meta.isEmergency
                                              ? const Color(0xFFDC2626)
                                              : const Color(0xFF0284C7))
                                          : const Color(0xFFE2E8F0),
                                      width: isSelected ? 1.8 : 1.0,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: (meta.isEmergency
                                                      ? const Color(0xFFDC2626)
                                                      : const Color(0xFF0284C7))
                                                  .withOpacity(0.12),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? (meta.isEmergency
                                                  ? const Color(0xFFFEE2E2)
                                                  : const Color(0xFFE0F2FE))
                                              : meta.bgColor,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          meta.icon,
                                          size: 19,
                                          color: isSelected
                                              ? (meta.isEmergency
                                                  ? const Color(0xFFDC2626)
                                                  : const Color(0xFF0284C7))
                                              : meta.color,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              titulo,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: isSelected
                                                    ? FontWeight.w800
                                                    : FontWeight.w600,
                                                color: isSelected &&
                                                        meta.isEmergency
                                                    ? const Color(0xFF991B1B)
                                                    : isSelected
                                                        ? const Color(
                                                            0xFF0369A1)
                                                        : const Color(
                                                            0xFF0F172A),
                                                height: 1.15,
                                              ),
                                            ),
                                            if (grupo.isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                grupo,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w500,
                                                  color: isSelected
                                                      ? const Color(0xFF64748B)
                                                      : const Color(0xFF94A3B8),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(left: 2),
                                          child: Icon(
                                            Icons.check_circle_rounded,
                                            size: 16,
                                            color: meta.isEmergency
                                                ? const Color(0xFFDC2626)
                                                : const Color(0xFF0284C7),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                      // SECCIÓN DE AUTORIZACIÓN PIN CUANDO HAY SELECCIÓN
                      if (_selectedCommand != null) ...[
                        const SizedBox(height: 16),
                        Builder(
                          builder: (context) {
                            final cod = _selectedCommand!['cod'] ??
                                _selectedCommand!['id'];
                            final selectedTitulo =
                                (_selectedCommand!['titulo'] ??
                                        _selectedCommand!['nombre'] ??
                                        'Comando $cod')
                                    .toString();
                            final selectedMeta =
                                _resolveCommandMeta(selectedTitulo);

                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: selectedMeta.isEmergency
                                    ? const Color(0xFFFFF1F2)
                                    : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: selectedMeta.isEmergency
                                      ? const Color(0xFFFECDD3)
                                      : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        selectedMeta.isEmergency
                                            ? Icons.warning_amber_rounded
                                            : Icons.lock_outline_rounded,
                                        size: 18,
                                        color: selectedMeta.isEmergency
                                            ? const Color(0xFFDC2626)
                                            : const Color(0xFF0284C7),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Comando: $selectedTitulo',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: selectedMeta.isEmergency
                                                ? const Color(0xFF991B1B)
                                                : const Color(0xFF0F172A),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () => setState(
                                            () => _selectedCommand = null),
                                        borderRadius: BorderRadius.circular(12),
                                        child: const Padding(
                                          padding: EdgeInsets.all(4),
                                          child: Icon(
                                            Icons.close_rounded,
                                            size: 16,
                                            color: Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (selectedMeta.isEmergency) ...[
                                    const SizedBox(height: 6),
                                    const Text(
                                      '⚠️ Atención: Este comando apagará el motor del vehículo en tiempo real. Actúa con precaución.',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFFB91C1C),
                                        height: 1.25,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  const Text(
                                    'CÓDIGO DE SEGURIDAD',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF64748B),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _pinController,
                                    obscureText: true,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly
                                    ],
                                    maxLength: 6,
                                    decoration: InputDecoration(
                                      isDense: true,
                                      counterText: '',
                                      prefixIcon: const Icon(
                                        Icons.pin_rounded,
                                        color: Color(0xFF64748B),
                                        size: 20,
                                      ),
                                      hintText:
                                          'Ingresa tu PIN de autorización',
                                      hintStyle: const TextStyle(
                                        fontSize: 12.5,
                                        color: Color(0xFF94A3B8),
                                      ),
                                      errorText: _pinError,
                                      filled: true,
                                      fillColor: Colors.white,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 12,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                            color: Color(0xFFCBD5E1)),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                            color: Color(0xFFCBD5E1)),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: selectedMeta.isEmergency
                                              ? const Color(0xFFDC2626)
                                              : const Color(0xFF0284C7),
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            selectedMeta.isEmergency
                                                ? const Color(0xFFDC2626)
                                                : const Color(0xFF0284C7),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 13),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        elevation: 0,
                                      ),
                                      onPressed:
                                          _isSending ? null : _sendCommand,
                                      child: _isSending
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                const Icon(Icons.send_rounded,
                                                    size: 16),
                                                const SizedBox(width: 8),
                                                Text(
                                                  selectedMeta.isEmergency
                                                      ? 'Transmitir Paro de Motor'
                                                      : 'Transmitir Comando en Vivo',
                                                  style: const TextStyle(
                                                    fontSize: 13.5,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CmdVisualMeta {
  final IconData icon;
  final Color color;
  final Color bgColor;
  final bool isEmergency;

  const _CmdVisualMeta({
    required this.icon,
    required this.color,
    required this.bgColor,
    this.isEmergency = false,
  });
}
