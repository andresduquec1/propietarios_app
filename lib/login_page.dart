import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'home_page.dart';
import 'search_page.dart';
import 'api_service.dart';
import 'data_repository.dart';

import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _towerController = TextEditingController();
  final TextEditingController _apartmentController = TextEditingController();
  final TextEditingController _unitCodeController = TextEditingController();
  
  bool _isPasswordVisible = false;
  bool _isRegisterMode = false;
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final ApiService _apiService = ApiService();
  final DataRepository _repository = DataRepository();

  bool _isLoading = false;
  bool _isLoadingUnits = false;
  bool _isPressed = false;
  List<Map<String, dynamic>> _availableUnits = [];
  int? _selectedUnitId;
  bool _isAcceptedTerms = false;

  @override
  void initState() {
    super.initState();
    _fetchUnits();
  }

  Future<void> _launchPolicy() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.gavel_rounded, color: Colors.indigo),
            SizedBox(width: 10),
            Text('Tratamiento de Datos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'En cumplimiento de la Ley 1581 de 2012 (Habeas Data) en Colombia, le informamos que al registrarse:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                '1. Sus datos personales (nombre, correo, teléfono y ubicación) serán utilizados exclusivamente para la gestión administrativa de la copropiedad.\n\n'
                '2. La información se almacenará de forma segura en nuestros servidores y solo será accesible por personal autorizado.\n\n'
                '3. Usted tiene derecho a actualizar, rectificar o solicitar la eliminación de sus datos en cualquier momento a través del perfil de usuario.\n\n'
                '4. Al continuar, usted autoriza de manera voluntaria, previa e informada el tratamiento de sus datos personales.',
                textAlign: TextAlign.justify,
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton.icon(
                  onPressed: () async {
                    final Uri url = Uri.parse('https://www.sic.gov.co/sobre-la-proteccion-de-datos-personales');
                    if (!await launchUrl(url)) {
                      _showMsg('No se pudo abrir el enlace');
                    }
                  },
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('Ver regulación completa (SIC)', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ENTENDIDO', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchUnits() async {
    setState(() => _isLoadingUnits = true);
    try {
      // Try to get units from API
      final response = await _apiService.getUnits();
      final List<dynamic> units = response['data'] ?? [];
      
      if (units.isNotEmpty) {
        await _dbHelper.saveUnits(units);
      }
      
      // Load from local DB
      final localUnits = await _dbHelper.getUnits();
      setState(() {
        _availableUnits = localUnits;
        _isLoadingUnits = false;
      });
    } catch (e) {
      print("Error al cargar unidades: $e");
      setState(() => _isLoadingUnits = false);
    }
  }

  void _login() async {
    String email = _emailController.text;
    String password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showMsg('Por favor, completa todos los campos');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await _repository.login(email, password);
      if (response != null) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => HomePage(userEmail: email)),
        );
      } else {
        _showMsg('Correo o contraseña incorrectos');
      }
    } catch (e) {
      if (e.toString().contains('inactiva')) {
        _showInactiveAccountDialog();
      } else {
        _showMsg('Error al iniciar sesión: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showInactiveAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 10),
            Text('Cuenta Inactiva'),
          ],
        ),
        content: const Text(
          'Tu cuenta aún no ha sido activada.\n\nPor favor, contacta al propietario o a un residente actual de tu apartamento para que active tu cuenta desde su aplicación.',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ENTENDIDO'),
          ),
        ],
      ),
    );
  }

  void _register() async {
    String email = _emailController.text;
    String password = _passwordController.text;
    String firstName = _firstNameController.text;
    String lastName = _lastNameController.text;
    String unitCode = _unitCodeController.text.trim();

    if (email.isEmpty || password.isEmpty || firstName.isEmpty || lastName.isEmpty || unitCode.isEmpty) {
      _showMsg('Todos los campos son obligatorios, incluido el código de unidad');
      return;
    }

    if (!_isAcceptedTerms) {
      _showMsg('Debes aceptar la política de tratamiento de datos personales');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final unit = await _apiService.findUnitByCode(unitCode);

      if (unit == null) {
        _showMsg('El código de unidad no es válido');
        setState(() => _isLoading = false);
        return;
      }

      // Preparar datos para la API (necesita 'name') y local
      Map<String, dynamic> userData = {
        'name': '$firstName $lastName',
        'firstName': firstName,
        'lastName': lastName,
        'phone': _phoneController.text,
        'tower': _towerController.text,
        'apartment': _apartmentController.text,
        'unit_id': unit['id'],
      };

      bool success = await _repository.register(email, password, userData);

      if (success) {
        _showMsg('Usuario registrado con éxito en el servidor');
        setState(() {
          _isRegisterMode = false;
          _isAcceptedTerms = false; // Reset for next time
        });
      } else {
        _showMsg('Error al registrar usuario. Posiblemente el correo ya existe o falla de conexión.');
      }
    } catch (e) {
      _showMsg('Error al registrar: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildTermsCheckbox() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            height: 24,
            width: 24,
            child: Checkbox(
              value: _isAcceptedTerms,
              activeColor: Colors.indigo,
              onChanged: (val) => setState(() => _isAcceptedTerms = val!),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(color: Colors.blueGrey[600], fontSize: 13),
                children: [
                  const TextSpan(text: 'Acepto la '),
                  TextSpan(
                    text: 'Política de Tratamiento de Datos Personales',
                    style: const TextStyle(
                      color: Colors.indigo,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: TapGestureRecognizer()..onTap = _launchPolicy,
                  ),
                  const TextSpan(text: ' según la regulación de Colombia.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showForgotPasswordDialog() {
    final TextEditingController resetEmailController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Recuperar Contraseña', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Ingresa tu correo electrónico y te enviaremos un código para restablecer tu contraseña.',
              style: TextStyle(fontSize: 14, color: Colors.blueGrey),
            ),
            const SizedBox(height: 20),
            _buildTextField(resetEmailController, 'Correo Electrónico', Icons.email_outlined, type: TextInputType.emailAddress),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              if (resetEmailController.text.isNotEmpty) {
                // Aquí se llamaría a la API en el futuro
                Navigator.pop(context);
                _showMsg('Si el correo está registrado, recibirás las instrucciones en breve.');
              } else {
                _showMsg('Por favor, ingresa tu correo');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('ENVIAR'),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {TextInputType type = TextInputType.text}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: type,
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.blueGrey[400], fontSize: 14),
          prefixIcon: Icon(icon, color: Colors.indigo[400], size: 22),
          hintText: label,
          hintStyle: TextStyle(color: Colors.blueGrey[200], fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _passwordController,
        obscureText: !_isPasswordVisible,
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          labelText: 'Contraseña',
          labelStyle: TextStyle(color: Colors.blueGrey[400], fontSize: 14),
          prefixIcon: Icon(Icons.lock_outline_rounded, color: Colors.indigo[400], size: 22),
          suffixIcon: IconButton(
            icon: Icon(
              _isPasswordVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
              color: Colors.blueGrey[300],
              size: 20,
            ),
            onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
          ),
          hintText: 'Contraseña',
          hintStyle: TextStyle(color: Colors.blueGrey[200], fontSize: 14),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Header
                TweenAnimationBuilder(
                  duration: const Duration(milliseconds: 800),
                  tween: Tween<double>(begin: 0, end: 1),
                  builder: (context, double value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 20 * (1 - value)),
                        child: child,
                      ),
                    );
                  },
                  child: Column(
                    children: [
                      Container(
                        padding: const Offset(0, 0) == const Offset(0, 0) ? const EdgeInsets.all(20) : EdgeInsets.zero,
                        decoration: BoxDecoration(
                          color: Colors.indigo[50],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.home_work_rounded, size: 50, color: Colors.indigo[600]),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _isRegisterMode ? 'Crear cuenta' : '¡Bienvenido de nuevo!',
                        style: const TextStyle(
                          fontSize: 28, 
                          fontWeight: FontWeight.bold, 
                          color: Color(0xFF1A237E),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isRegisterMode 
                          ? 'Regístrate para gestionar tu residencia' 
                          : 'Ingresa tus credenciales para continuar',
                        style: TextStyle(fontSize: 15, color: Colors.blueGrey[400]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // Form
                if (_isRegisterMode) ...[
                  _buildTextField(_firstNameController, 'Nombres', Icons.person_outline_rounded),
                  const SizedBox(height: 16),
                  _buildTextField(_lastNameController, 'Apellidos', Icons.person_outline_rounded),
                  const SizedBox(height: 16),
                  _buildTextField(_phoneController, 'Número de Celular', Icons.phone_android_rounded, type: TextInputType.number),
                  const SizedBox(height: 16),
                ],
                
                _buildTextField(_emailController, 'Correo Electrónico', Icons.alternate_email_rounded, type: TextInputType.emailAddress),
                const SizedBox(height: 16),
                _buildPasswordField(),
                
                /* // Opción oculta temporalmente
                if (!_isRegisterMode) 
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        // Navegar a pantalla de recuperación o mostrar diálogo
                        _showForgotPasswordDialog();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.indigo[600],
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: const Text(
                        '¿Olvidaste tu contraseña?',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                */

                if (_isRegisterMode) ...[
                  const SizedBox(height: 16),
                  _buildTextField(_unitCodeController, 'Código de Unidad Residencial', Icons.business_rounded),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildTextField(_towerController, 'Torre', Icons.apartment_rounded)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildTextField(_apartmentController, 'Apto', Icons.door_front_door_outlined)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildTermsCheckbox(),
                ],
                
                const SizedBox(height: 32),
                
                // Primary Action Button
                GestureDetector(
                  onTapDown: (_) => setState(() => _isPressed = true),
                  onTapUp: (_) => setState(() => _isPressed = false),
                  onTapCancel: () => setState(() => _isPressed = false),
                  child: AnimatedScale(
                    scale: _isPressed ? 0.96 : 1.0,
                    duration: const Duration(milliseconds: 100),
                    child: Container(
                      width: double.infinity,
                      height: 58,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3949AB), Color(0xFF1A237E)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.indigo.withOpacity(_isPressed ? 0.1 : 0.3),
                            blurRadius: _isPressed ? 4 : 12,
                            offset: Offset(0, _isPressed ? 2 : 6),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : (_isRegisterMode ? _register : _login),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _isLoading 
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            )
                          : Text(
                              _isRegisterMode ? 'REGISTRARSE' : 'INICIAR SESIÓN', 
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1),
                            ),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Toggle Mode
                TextButton(
                  onPressed: () => setState(() => _isRegisterMode = !_isRegisterMode),
                  style: TextButton.styleFrom(foregroundColor: Colors.indigo[700]),
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(color: Colors.blueGrey[600], fontSize: 14),
                      children: [
                        TextSpan(text: _isRegisterMode ? '¿Ya tienes una cuenta? ' : '¿No tienes una cuenta? '),
                        TextSpan(
                          text: _isRegisterMode ? 'Inicia sesión' : 'Regístrate aquí',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
