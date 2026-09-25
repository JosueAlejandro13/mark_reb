import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:mark_v3/services/ConnectionProfile_/ProfileCon_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

//Autor: Josue Hernandez
class ChangePasswordPage extends StatefulWidget {
  final String userId;
  final String usuario;
  final String idMainAccount;

  const ChangePasswordPage(
      {super.key,
      required this.userId,
      required this.usuario,
      required this.idMainAccount});

  @override
  // ignore: library_private_types_in_public_api
  _ChangePasswordPageState createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String? _currentPasswordError;
  String? _newPasswordError;
  String? _confirmPasswordError;
  String _passwordStrengthMessage = '';
  Color _passwordStrengthColor = Colors.grey;
  bool _passwordsMatch = false;
  double _passwordStrength = 0.0;

  bool _isCurrentPasswordVisible = false;
  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

// Funcion para cambiar la contraseña
  Future<void> _changePassword() async {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    if (_formKey.currentState?.validate() ?? false) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: screenWidth * 30,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    "Guardando cambios        ",
                    style: TextStyle(fontSize: screenWidth * 0.033),
                  ),
                ),
                const SizedBox(width: 17),
                Lottie.asset(
                  'assets/loading.json',
                  height: screenHeight * 0.08,
                  width: screenHeight * 0.08,
                  repeat: true,
                ),
              ],
            ),
          ),
        ),
      );

      try {
        final result = await ProfileconService().updatePassword(
          usuario: widget.usuario,
          idMainAccount: widget.idMainAccount,
          currentPassword: _currentPasswordController.text,
          newPassword: _newPasswordController.text,
        );
        if (result) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isBiometricEnabled', false);
          await prefs.setString('password', _newPasswordController.text);
          await prefs.setBool('isPasswordSet', true);
          showTopSnackBar(
            Overlay.of(context),
            Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 0, 155, 85),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Contraseña actualizada con éxito. Biométricos deshabilitados.",
                        style: TextStyle(
                          fontSize: screenWidth * 0.034,
                          color: Colors.white,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );

          Navigator.pop(context);
        } else {
          final screenWidth = MediaQuery.of(context).size.width;
          showTopSnackBar(
            Overlay.of(context),
            Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Error. La contraseña actual es incorrecta.",
                        style: TextStyle(
                          fontSize: screenWidth * 0.034,
                          color: Colors.white,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      } catch (e) {
        showTopSnackBar(
          Overlay.of(context),
          Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Error al guardar cambios. Intente nuevamente más tarde.",
                      style: TextStyle(
                        fontSize: screenWidth * 0.034,
                        color: Colors.white,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      } finally {
        Navigator.of(context).pop();
      }
    }
  }

  // Fuerza de la contraseña
  void _checkPasswordStrength(String password) {
    double strength = 0;

    if (password.length >= 6) strength += 0.25;
    if (password.length >= 8) strength += 0.25;
    if (RegExp(r'[A-Z]').hasMatch(password)) strength += 0.2;
    if (RegExp(r'[0-9]').hasMatch(password)) strength += 0.15;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) strength += 0.15;

    setState(() {
      _passwordStrength = (strength >= 1.0) ? 1.0 : strength.clamp(0.0, 1.0);

      if (_passwordStrength >= 0.75) {
        _passwordStrengthMessage = 'Contraseña Segura';
        _passwordStrengthColor = Colors.green;
      } else if (_passwordStrength >= 0.4) {
        _passwordStrengthMessage = 'Contraseña Moderada';
        _passwordStrengthColor = Colors.orange;
      } else {
        _passwordStrengthMessage = 'Contraseña Débil';
        _passwordStrengthColor = Colors.red;
      }
    });
  }

  // Verifica si las contraseñas coinciden
  void _checkPasswordsMatch() {
    setState(() {
      _passwordsMatch =
          _confirmPasswordController.text == _newPasswordController.text;
    });
  }

  // Validación de la contraseña actual
  @override
  void initState() {
    super.initState();

    _currentPasswordController.addListener(() {
      if (_currentPasswordError != null) {
        setState(() {
          _currentPasswordError = null;
        });
      }
    });

    _newPasswordController.addListener(() {
      if (_newPasswordError != null) {
        setState(() {
          _newPasswordError = null;
        });
      }
      _checkPasswordStrength(_newPasswordController.text);

      _checkPasswordsMatch();
    });

    _confirmPasswordController.addListener(() {
      if (_confirmPasswordError != null) {
        setState(() {
          _confirmPasswordError = null;
        });
      }
      _checkPasswordsMatch();
    });
  }

  @override
  Widget build(BuildContext context) {
    double appBarHeight = 30.0;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(appBarHeight),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios,
              color: Color.fromARGB(255, 0, 0, 0),
              size: 19,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            AnimatedContainer(
              duration: const Duration(seconds: 5),
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
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Text(
                        'Cambiar Contraseña',
                        style: TextStyle(
                          fontSize: screenWidth * 0.050,
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Text(
                        'La contraseña debe tener al menos 8 caracteres, incluir una letra mayúscula, un número y un carácter especial.',
                        style: TextStyle(
                          fontSize: screenWidth * 0.030,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: <Widget>[
                              Padding(
                                padding: const EdgeInsets.all(1.0),
                                child: Container(
                                  padding: const EdgeInsets.all(20.0),
                                  child: Column(
                                    children: [
                                      TextFormField(
                                        controller: _currentPasswordController,
                                        obscureText: !_isCurrentPasswordVisible,
                                        style: TextStyle(
                                            fontSize: screenWidth * 0.031),
                                        decoration: InputDecoration(
                                          labelText: 'Contraseña Actual',
                                          labelStyle: TextStyle(
                                              fontSize: screenWidth * 0.031),
                                          errorText: _currentPasswordError,
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          filled: true, // Fondo lleno
                                          fillColor: Colors.white,
                                          prefixIcon: const Icon(Icons.lock),
                                          suffixIcon: IconButton(
                                            icon: Icon(
                                              _isCurrentPasswordVisible
                                                  ? Icons.visibility
                                                  : Icons.visibility_off,
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                _isCurrentPasswordVisible =
                                                    !_isCurrentPasswordVisible;
                                              });
                                            },
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 20.0),
                                      TextFormField(
                                        controller: _newPasswordController,
                                        obscureText: !_isNewPasswordVisible,
                                        onChanged: _checkPasswordStrength,
                                        style: TextStyle(
                                            fontSize: screenWidth * 0.031),
                                        decoration: InputDecoration(
                                          labelText: 'Nueva Contraseña',
                                          labelStyle: TextStyle(
                                              fontSize: screenWidth * 0.031),
                                          errorText: _newPasswordError,
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          filled: true, // Fondo lleno
                                          fillColor: Colors.white,
                                          prefixIcon:
                                              const Icon(Icons.lock_outline),
                                          suffixIcon: IconButton(
                                            icon: Icon(
                                              _isNewPasswordVisible
                                                  ? Icons.visibility
                                                  : Icons.visibility_off,
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                _isNewPasswordVisible =
                                                    !_isNewPasswordVisible;
                                              });
                                            },
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: 8.0),
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(top: 8.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            LinearProgressIndicator(
                                              value: _passwordStrength,
                                              backgroundColor: Colors.grey[300],
                                              color: _passwordStrengthColor,
                                              minHeight: 8,
                                            ),
                                            const SizedBox(height: 4),
                                            Center(
                                              child: Text(
                                                _passwordStrengthMessage,
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  color: _passwordStrengthColor,
                                                  fontSize: screenWidth * 0.031,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 20.0),
                                      TextFormField(
                                        controller: _confirmPasswordController,
                                        obscureText: !_isConfirmPasswordVisible,
                                        style: TextStyle(
                                            fontSize: screenWidth * 0.031),
                                        decoration: InputDecoration(
                                          labelText:
                                              'Confirmar Nueva Contraseña',
                                          labelStyle: TextStyle(
                                              fontSize: screenWidth * 0.031),
                                          errorText: _confirmPasswordError,
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          filled: true, // Fondo lleno
                                          fillColor: Colors.white,
                                          prefixIcon:
                                              const Icon(Icons.lock_outline),
                                          suffixIcon: IconButton(
                                            icon: Icon(
                                              _isConfirmPasswordVisible
                                                  ? Icons.visibility
                                                  : Icons.visibility_off,
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                _isConfirmPasswordVisible =
                                                    !_isConfirmPasswordVisible;
                                              });
                                            },
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(top: 8.0),
                                        child: Text(
                                          _passwordsMatch
                                              ? 'Las contraseñas coinciden'
                                              : 'Las contraseñas no coinciden',
                                          style: TextStyle(
                                            color: _passwordsMatch
                                                ? Colors.green
                                                : Colors.red,
                                            fontSize: screenWidth * 0.031,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 24.0),
                                      ElevatedButton(
                                        onPressed: _passwordsMatch
                                            ? () {
                                                if (_currentPasswordController
                                                    .text.isEmpty) {
                                                  final screenWidth =
                                                      MediaQuery.of(context)
                                                          .size
                                                          .width;
                                                  showTopSnackBar(
                                                    Overlay.of(context),
                                                    Material(
                                                      color: Colors.transparent,
                                                      child: Container(
                                                        margin: const EdgeInsets
                                                            .symmetric(
                                                            horizontal: 20),
                                                        padding:
                                                            const EdgeInsets
                                                                .all(16),
                                                        decoration:
                                                            BoxDecoration(
                                                          color:
                                                              Color(0xFF0886B5),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(12),
                                                        ),
                                                        child: Row(
                                                          children: [
                                                            const Icon(
                                                                Icons.error,
                                                                color: Colors
                                                                    .white,
                                                                size: 24),
                                                            const SizedBox(
                                                                width: 12),
                                                            Expanded(
                                                              child: Text(
                                                                "La contraseña actual no puede estar vacía.",
                                                                style:
                                                                    TextStyle(
                                                                  fontSize:
                                                                      screenWidth *
                                                                          0.034,
                                                                  color: Colors
                                                                      .white,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .normal,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                } else if (_passwordStrength >=
                                                    0.4) {
                                                  _showConfirmChangeDialog();
                                                } else {
                                                  showTopSnackBar(
                                                    Overlay.of(context),
                                                    Material(
                                                      color: Colors.transparent,
                                                      child: Container(
                                                        margin: const EdgeInsets
                                                            .symmetric(
                                                            horizontal: 20),
                                                        padding:
                                                            const EdgeInsets
                                                                .all(16),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: const Color(
                                                              0xFF0886B5),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(12),
                                                        ),
                                                        child: Row(
                                                          children: [
                                                            const Icon(
                                                                Icons.error,
                                                                color: Colors
                                                                    .white,
                                                                size: 24),
                                                            const SizedBox(
                                                                width: 12),
                                                            Expanded(
                                                              child: Text(
                                                                "La contraseña no es segura. Por favor, elija una contraseña más segura.",
                                                                style:
                                                                    TextStyle(
                                                                  fontSize:
                                                                      screenWidth *
                                                                          0.034,
                                                                  color: Colors
                                                                      .white,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .normal,
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
                                            : null,
                                        style: ElevatedButton.styleFrom(
                                          foregroundColor: Colors.white,
                                          backgroundColor:
                                              const Color(0xFF0886B5),
                                          minimumSize: const Size(200, 12),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 24, vertical: 12),
                                          textStyle: TextStyle(
                                              fontSize: screenWidth * 0.030),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                        child: Text(
                                          'Cambiar Contraseña',
                                          style: TextStyle(
                                              fontSize: screenWidth * 0.030),
                                        ),
                                      )
                                    ],
                                  ),
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

  Future<void> _showConfirmChangeDialog() async {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
            titlePadding: EdgeInsets.zero,
            title: Stack(children: [
              Padding(
                padding: EdgeInsets.only(top: 23, left: 24),
                child: Text(
                  'Confirmar Contraseña',
                  style: TextStyle(
                      fontSize: screenWidth * 0.040,
                      fontWeight: FontWeight.w500),
                ),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 246, 246, 246),
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox(
                    width: screenHeight * 0.040,
                    height: screenHeight * 0.040,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      iconSize: screenHeight * 0.025,
                      icon: Icon(Icons.close_rounded, color: Colors.black),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 45),
            ]),
            content: Text(
              '¿Estás seguro de que deseas cambiar tu contraseña?',
              style: TextStyle(fontSize: screenWidth * 0.030),
            ),
            actions: [
              TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: Colors.grey,
                  foregroundColor: Colors.white,
                  elevation: 6,
                  shadowColor: Colors.grey.withOpacity(0.3),
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Cancelar',
                    style: TextStyle(fontSize: screenWidth * 0.030)),
              ),
              ElevatedButton(
                child: Text('Confirmar',
                    style: TextStyle(fontSize: screenWidth * 0.030)),
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ]);
      },
    );
    if (confirmed == true) {
      _changePassword();
    }
  }
}
