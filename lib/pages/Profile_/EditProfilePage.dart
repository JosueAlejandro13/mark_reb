import 'package:bottom_picker/bottom_picker.dart';
import 'package:easy_mask/easy_mask.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:mark_v3/providers/edit_profile_provider.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

// Autor: Josue Hernandez
class EditProfilePage extends ConsumerStatefulWidget {
  final String idCollaborator;
  final String idMainAccount;

  const EditProfilePage({
    super.key,
    required this.idCollaborator,
    required this.idMainAccount,
  });

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _mobilPhoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _dateOfBirthController = TextEditingController();
  final _employeeNumController = TextEditingController();
  final _idJobTitleController = TextEditingController();

  bool _hasInitializedControllers = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(editProfileProvider.notifier).loadUserData(
            collaboratorId: widget.idCollaborator,
            idMainAccount: widget.idMainAccount,
          );
    });
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _mobilPhoneController.dispose();
    _addressController.dispose();
    _dateOfBirthController.dispose();
    _employeeNumController.dispose();
    _idJobTitleController.dispose();
    super.dispose();
  }

  void _populateFields(Map<String, dynamic> data) {
    if (_hasInitializedControllers) return;
    _hasInitializedControllers = true;

    _firstNameController.text = data['firstName']?.toString() ?? '';
    _lastNameController.text = data['LastName']?.toString() ?? '';
    _emailController.text = data['email']?.toString() ?? '';
    _phoneController.text = data['phone']?.toString() ?? '';
    _mobilPhoneController.text = data['mobilPhone']?.toString() ?? '';
    _addressController.text = data['address']?.toString() ?? '';

    final dateOfBirth = data['dateBirth'];
    if (dateOfBirth != null) {
      if (dateOfBirth is DateTime) {
        _dateOfBirthController.text =
            DateFormat('yyyy-MM-dd').format(dateOfBirth);
      } else {
        final parsed = DateTime.tryParse(dateOfBirth.toString());
        if (parsed != null) {
          _dateOfBirthController.text = DateFormat('yyyy-MM-dd').format(parsed);
        }
      }
    }

    _employeeNumController.text = data['employeeNum']?.toString() ?? '';
    _idJobTitleController.text = data['idJobTitle']?.toString() ?? '';
  }

  void _selectDate(BuildContext context) {
    DateTime initialDate;
    try {
      initialDate = _dateOfBirthController.text.isNotEmpty
          ? DateFormat('yyyy-MM-dd').parse(_dateOfBirthController.text)
          : DateTime(2000, 1, 1);
    } catch (_) {
      initialDate = DateTime(2000, 1, 1);
    }

    BottomPicker.date(
      pickerTitle: const Text(
        "Fecha de nacimiento",
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Color(0xFF0F172A),
        ),
      ),
      dismissable: true,
      initialDateTime: initialDate,
      minDateTime: DateTime(1930),
      maxDateTime: DateTime.now(),
      pickerTextStyle: const TextStyle(
        fontSize: 16,
        color: Color(0xFF0F172A),
        fontWeight: FontWeight.w600,
      ),
      onSubmit: (selectedDate) {
        setState(() {
          _dateOfBirthController.text =
              DateFormat('yyyy-MM-dd').format(selectedDate as DateTime);
        });
      },
      displayCloseIcon: true,
      buttonContent:
          const Icon(Icons.check_rounded, color: Colors.white, size: 18),
      buttonStyle: BoxDecoration(
        color: const Color(0xFF0886B5),
        borderRadius: BorderRadius.circular(12),
      ),
      buttonWidth: 50,
      buttonPadding: 8,
    ).show(context);
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    final notifier = ref.read(editProfileProvider.notifier);
    final success = await notifier.saveUserData(
      userId: widget.idCollaborator,
      idMainAccount: widget.idMainAccount,
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      mobilPhone: _mobilPhoneController.text.trim(),
      address: _addressController.text.trim(),
      dateOfBirth: _dateOfBirthController.text.trim(),
      employeeNum: _employeeNumController.text.trim(),
      idJobTitle: _idJobTitleController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      showTopSnackBar(
        Overlay.of(context),
        Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Cambios guardados con éxito.",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      showTopSnackBar(
        Overlay.of(context),
        Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Row(
              children: [
                Icon(Icons.error_outline_rounded,
                    color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Error al guardar cambios. Verifica tus datos e intenta de nuevo.",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(editProfileProvider);

    // Si los datos se cargan desde el provider, inicializar campos
    if (state.userData != null && !_hasInitializedControllers) {
      _populateFields(state.userData!);
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color.fromARGB(255, 250, 250, 250),
            Color.fromARGB(255, 205, 240, 255),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: state.isLoading
              ? Center(
                  child: Lottie.asset(
                    'assets/loading.json',
                    width: 70,
                    height: 70,
                  ),
                )
              : GestureDetector(
                  onTap: () => FocusScope.of(context).unfocus(),
                  behavior: HitTestBehavior.translucent,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Encabezado
                          _buildHeader(context),
                          const SizedBox(height: 12),

                          // CARD 1: INFORMACIÓN PERSONAL
                          _buildSectionCard(
                            icon: Icons.person_rounded,
                            iconColor: const Color(0xFF0886B5),
                            iconBg: const Color(0xFFE0F2FE),
                            title: 'Datos Personales',
                            subtitle: 'Nombre y correo del colaborador',
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildFormField(
                                      controller: _firstNameController,
                                      label: 'Nombre',
                                      icon: Icons.badge_outlined,
                                      validator: (val) =>
                                          val == null || val.trim().isEmpty
                                              ? 'Ingresa tu nombre'
                                              : null,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _buildFormField(
                                      controller: _lastNameController,
                                      label: 'Apellido',
                                      icon: Icons.person_outline_rounded,
                                      validator: (val) =>
                                          val == null || val.trim().isEmpty
                                              ? 'Ingresa tu apellido'
                                              : null,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              _buildFormField(
                                controller: _emailController,
                                label: 'Correo Electrónico',
                                icon: Icons.email_outlined,
                                enabled: false,
                                helperText:
                                    'El correo no puede modificarse directamente',
                              ),
                            ],
                          ),
                          const SizedBox(height: 11),

                          // CARD 2: CONTACTO Y DOMICILIO
                          _buildSectionCard(
                            icon: Icons.phone_android_rounded,
                            iconColor: const Color(0xFFEA580C),
                            iconBg: const Color(0xFFFFF7ED),
                            title: 'Contacto y Ubicación',
                            subtitle:
                                'Números de teléfono y domicilio registrado',
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildMaskedPhoneField(
                                      controller: _phoneController,
                                      label: 'Tel. Fijo',
                                      icon: Icons.phone_outlined,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _buildMaskedPhoneField(
                                      controller: _mobilPhoneController,
                                      label: 'Tel. Móvil',
                                      icon: Icons.phone_iphone_rounded,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              _buildFormField(
                                controller: _addressController,
                                label: 'Dirección Completa',
                                icon: Icons.home_outlined,
                                validator: (val) =>
                                    val == null || val.trim().isEmpty
                                        ? 'Ingresa tu dirección'
                                        : null,
                              ),
                            ],
                          ),
                          const SizedBox(height: 11),

                          // CARD 3: NACIMIENTO Y EMPLEO
                          _buildSectionCard(
                            icon: Icons.work_outline_rounded,
                            iconColor: const Color(0xFF7C3AED),
                            iconBg: const Color(0xFFF3E8FF),
                            title: 'Nacimiento y Empleo',
                            subtitle: 'Fecha de nacimiento y datos asignados',
                            children: [
                              _buildDateField(context),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildFormField(
                                      controller: _employeeNumController,
                                      label: 'No. Empleado',
                                      icon: Icons.numbers_rounded,
                                      enabled: false,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _buildFormField(
                                      controller: _idJobTitleController,
                                      label: 'Puesto / Cargo',
                                      icon: Icons.badge_outlined,
                                      enabled: false,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // BOTÓN DE GUARDAR CAMBIOS
                          _buildSaveButton(state),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  // --- HEADER SUPERIOR ---
  Widget _buildHeader(BuildContext context) {
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
                border: Border.all(color: Colors.black.withOpacity(0.04)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Color(0xFF0F172A),
                  size: 16,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Editar Perfil',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.4,
                ),
              ),
              SizedBox(height: 1),
              Text(
                'Actualiza tus datos personales y de contacto',
                style: TextStyle(
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

  // --- CONTENEDOR DE SECCIÓN (CARD) ---
  Widget _buildSectionCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
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
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(icon, color: iconColor, size: 17),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  // --- CAMPO DE FORMULARIO ESTILIZADO ---
  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool enabled = true,
    String? helperText,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      validator: validator,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: enabled ? const Color(0xFF0F172A) : const Color(0xFF64748B),
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontSize: 12,
          color: enabled ? Colors.grey[600] : Colors.grey[400],
          fontWeight: FontWeight.w500,
        ),
        helperText: helperText,
        helperStyle: TextStyle(fontSize: 10, color: Colors.grey[500]),
        prefixIcon: Icon(
          icon,
          size: 17,
          color: enabled ? const Color(0xFF0886B5) : Colors.grey[400],
        ),
        filled: true,
        fillColor: enabled ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.05)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.05)),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.03)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0886B5), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
      ),
    );
  }

  // --- CAMPO DE TELÉFONO CON MÁSCARA ---
  Widget _buildMaskedPhoneField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.phone,
      inputFormatters: [
        TextInputMask(mask: '(99) 9999-9999', placeholder: '_'),
      ],
      validator: (val) {
        if (val == null || val.trim().isEmpty) {
          return 'Ingresa número';
        }
        return null;
      },
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF0F172A),
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(
          icon,
          size: 17,
          color: const Color(0xFFEA580C),
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.05)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.05)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEA580C), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
      ),
    );
  }

  // --- CAMPO DE FECHA DE NACIMIENTO ---
  Widget _buildDateField(BuildContext context) {
    return TextFormField(
      controller: _dateOfBirthController,
      readOnly: true,
      onTap: () => _selectDate(context),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Por favor seleccione su fecha de nacimiento';
        }
        try {
          final selectedDate = DateTime.parse(value);
          final today = DateTime.now();
          final age = today.year - selectedDate.year;
          final isAdult = (age > 18 ||
              (age == 18 &&
                  (today.month > selectedDate.month ||
                      (today.month == selectedDate.month &&
                          today.day >= selectedDate.day))));

          if (!isAdult) {
            return 'Debes ser mayor de 18 años para continuar';
          }
        } catch (_) {}
        return null;
      },
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF0F172A),
      ),
      decoration: InputDecoration(
        labelText: 'Fecha de Nacimiento',
        labelStyle: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: const Icon(
          Icons.calendar_month_rounded,
          size: 17,
          color: Color(0xFF7C3AED),
        ),
        suffixIcon: const Icon(
          Icons.keyboard_arrow_down_rounded,
          color: Colors.black54,
          size: 18,
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.05)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.05)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
      ),
    );
  }

  // --- BOTÓN GUARDAR CAMBIOS ---
  Widget _buildSaveButton(EditProfileState state) {
    return Container(
      width: double.infinity,
      height: 46,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0886B5),
            Color(0xFF0284C7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0886B5).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: state.isSaving ? null : _handleSave,
          child: Center(
            child: state.isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.save_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Guardar Cambios',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
