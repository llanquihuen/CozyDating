import 'package:flutter/material.dart';
import '../../../core/services/auth_service.dart';
import 'fun_registration_wizard.dart';

class WelcomeScreen extends StatefulWidget {
  final VoidCallback onAuthenticated;

  const WelcomeScreen({
    super.key,
    required this.onAuthenticated,
  });

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<bool> _performLogin(void Function(void Function()) setSheetState) async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      setSheetState(() {
        _errorMessage = 'Por favor ingresa usuario y contraseña';
      });
      return false;
    }

    setSheetState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await AuthService.login(username: username, password: password);

    if (!mounted) return false;

    setSheetState(() {
      _isLoading = false;
      if (!result.success) {
        _errorMessage = result.errorMessage ?? 'Credenciales incorrectas';
      }
    });

    return result.success;
  }

  Future<void> _openRegistration() async {
    final bool? registered = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (wizardContext) => FunRegistrationWizardScreen(
          onRegistrationSuccess: () {
            if (Navigator.of(wizardContext).canPop()) {
              Navigator.of(wizardContext).pop(true);
            }
          },
        ),
      ),
    );

    if (registered == true && mounted) {
      widget.onAuthenticated();
    }
  }

  Future<void> _showLoginSheet() async {
    final bool? authenticated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1C27),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (builderContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(builderContext).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '🔑 Iniciar Sesión',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.of(sheetContext).pop(false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.redAccent),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _usernameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Usuario o Correo',
                      prefixIcon: const Icon(Icons.person, color: Color(0xFFFFB300)),
                      filled: true,
                      fillColor: const Color(0xFF282538),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock, color: Color(0xFFFFB300)),
                      filled: true,
                      fillColor: const Color(0xFF282538),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFB300),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isLoading
                        ? null
                        : () async {
                            final success = await _performLogin(setSheetState);
                            if (success && sheetContext.mounted) {
                              Navigator.of(sheetContext).pop(true);
                            }
                          },
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : const Text('Entrar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (authenticated == true && mounted) {
      widget.onAuthenticated();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF13111C),
      body: Stack(
        children: [
          // Background ambient gradient
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.3),
                  radius: 1.2,
                  colors: [
                    Color(0xFF2C243B),
                    Color(0xFF13111C),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(height: 10),

                  // Hero Icon & App Branding
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFFFB300).withOpacity(0.15),
                          border: Border.all(color: const Color(0xFFFFB300), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFB300).withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.favorite_rounded,
                          color: Color(0xFFFFB300),
                          size: 64,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Cozy Slow Dating',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Conoce personas afines a través de aventuras cooperativas 2D, sin catálogos superficiales.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13.5,
                          color: Colors.white70,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),

                  // Action Buttons (Registro Divertido & Login)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFB300),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 4,
                        ),
                        onPressed: _openRegistration,
                        icon: const Icon(Icons.stars, color: Colors.black),
                        label: const Text(
                          'Crear Cuenta & Diseñar Personaje',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white30, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: _showLoginSheet,
                        icon: const Icon(Icons.login, size: 18),
                        label: const Text(
                          'Ya tengo una cuenta',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
