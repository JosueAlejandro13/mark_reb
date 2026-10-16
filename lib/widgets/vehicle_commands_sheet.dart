import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mark_v3/services/mark_api_client.dart';
import 'package:mark_v3/widgets/snackbar_top.dart';

/// Modal bottom sheet para envío de comandos telemáticos en vivo (a=comandos y a=comando)
/// Cumple con las especificaciones de las páginas 6, 9 y 14 de la documentación MarkV3.1.
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
    setState(() {
      _selectedCommand = cmd;
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

    final cod = int.tryParse((_selectedCommand!['cod'] ?? _selectedCommand!['id'] ?? '0').toString()) ?? 0;
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
      final mensaje = (res['mensaje'] ?? 'Comando ejecutado exitosamente.').toString();

      if (ok) {
        if (mounted) {
          Navigator.pop(context);
          SnackbarTop.showSuccess(context, mensaje, title: 'Comando Enviado');
        }
      } else {
        final error = (res['error'] ?? 'No se pudo enviar el comando.').toString();
        final codigoMal = res['codigoMal'] == true;
        final bloqueadoMin = res['bloqueadoMin'];

        String displayError = error;
        if (codigoMal) {
          displayError = 'Código de seguridad incorrecto.';
        } else if (bloqueadoMin != null) {
          displayError = 'Demasiados intentos fallidos. Espera $bloqueadoMin min.';
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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.power_settings_new_rounded,
                  color: Color(0xFFDC2626),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Comandos Telemáticos',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.4,
                    ),
                  ),
                  Text(
                    '${widget.vehicleName} · ${widget.plates}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(36.0),
              child: Center(child: CircularProgressIndicator(color: Color(0xFF0284C7))),
            )
          else if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0),
              child: Center(
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13),
                  textAlign: TextAlign.center,
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
                  Icon(Icons.lock_clock_rounded, size: 40, color: Color(0xFF94A3B8)),
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
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            )
          else ...[
            const Text(
              'SELECCIONA UN COMANDO',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF64748B),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),

            ..._comandos.map((cmd) {
              final cod = cmd['cod'] ?? cmd['id'];
              final titulo = (cmd['titulo'] ?? cmd['nombre'] ?? 'Comando $cod').toString();
              final grupo = (cmd['grupo'] ?? 'Control').toString();
              final isSelected = _selectedCommand?['cod'] == cod;

              final isEmergency = titulo.toLowerCase().contains('paro') ||
                  titulo.toLowerCase().contains('bloqueo') ||
                  titulo.toLowerCase().contains('apagar');

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isEmergency ? const Color(0xFFFEF2F2) : const Color(0xFFF0F9FF))
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? (isEmergency ? const Color(0xFFDC2626) : const Color(0xFF0284C7))
                        : const Color(0xFFE2E8F0),
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
                child: ListTile(
                  dense: true,
                  leading: Icon(
                    isEmergency
                        ? Icons.no_crash_rounded
                        : Icons.electrical_services_rounded,
                    color: isEmergency ? const Color(0xFFDC2626) : const Color(0xFF0284C7),
                  ),
                  title: Text(
                    titulo,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected && isEmergency
                          ? const Color(0xFF991B1B)
                          : const Color(0xFF0F172A),
                    ),
                  ),
                  subtitle: Text(
                    'Grupo: $grupo',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                  trailing: isSelected
                      ? Icon(
                          Icons.check_circle_rounded,
                          color: isEmergency ? const Color(0xFFDC2626) : const Color(0xFF0284C7),
                        )
                      : null,
                  onTap: () => _onSelectCommand(cmd),
                ),
              );
            }),

            if (_selectedCommand != null) ...[
              const SizedBox(height: 14),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              const SizedBox(height: 14),

              const Text(
                'CÓDIGO DE SEGURIDAD',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 6,
                decoration: InputDecoration(
                  counterText: '',
                  prefixIcon: const Icon(Icons.pin_rounded, color: Color(0xFF64748B)),
                  hintText: 'Ingresa tu PIN de autorización',
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  errorText: _pinError,
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _isSending ? null : _sendCommand,
                  child: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Transmitir Comando en Vivo',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
