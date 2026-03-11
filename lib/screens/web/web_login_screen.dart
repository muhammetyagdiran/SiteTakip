import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/theme_service.dart';
import 'package:site_takip/l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/glass_widgets.dart';
import '../../theme/app_theme.dart';

class WebLoginScreen extends StatefulWidget {
  const WebLoginScreen({super.key});

  @override
  State<WebLoginScreen> createState() => _WebLoginScreenState();
}

class _WebLoginScreenState extends State<WebLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final themeService = Provider.of<ThemeService>(context);
    final authService = Provider.of<AuthService>(context);
    final isModern = themeService.isModern;
    final primaryColor = isModern ? const Color(0xFF3B82F6) : AppColors.mgmtAccent;
    final headingColor = isModern ? Colors.white : AppColors.mgmtTextHeading;
    final bodyColor = isModern ? Colors.white.withOpacity(0.6) : AppColors.mgmtTextBody;

    return Scaffold(
      body: Row(
        children: [
          // Left Side - Branding / Graphic
          Expanded(
            flex: 5,
            child: GradientBackground(
              child: Stack(
                children: [
                   // Decorative Elements
                  Positioned(
                    top: -100,
                    left: -100,
                    child: Container(
                      width: 400,
                      height: 400,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isModern ? Colors.white.withOpacity(0.03) : AppColors.mgmtPrimary.withOpacity(0.05),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -150,
                    right: -50,
                    child: Container(
                      width: 500,
                      height: 500,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isModern ? Colors.white.withOpacity(0.02) : AppColors.mgmtAccent.withOpacity(0.05),
                      ),
                    ),
                  ),
                  // Content
                  Padding(
                    padding: const EdgeInsets.all(60.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: isModern 
                                  ? [const Color(0xFF3B82F6), const Color(0xFF8B5CF6)]
                                  : [AppColors.mgmtPrimary, AppColors.mgmtAccent],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.apartment_rounded, size: 64, color: Colors.white),
                        ),
                        const SizedBox(height: 40),
                        Text(
                          'SiteTakip\nYönetim Sistemi',
                          style: TextStyle(
                            color: isModern ? Colors.white : AppColors.mgmtTextHeading,
                            fontSize: 56,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.5,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Modern, güvenli ve kolay apartman/site yönetimi.\nTüm işlemleriniz tek ekranda.',
                          style: TextStyle(
                            color: isModern ? Colors.white.withOpacity(0.8) : AppColors.mgmtTextBody,
                            fontSize: 20,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.5,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Right Side - Login Form
          Expanded(
            flex: 4,
            child: Container(
              color: isModern ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              child: Stack(
                children: [
                  Positioned(
                    top: 24,
                    right: 24,
                    child: IconButton(
                      onPressed: () => themeService.toggleTheme(),
                      icon: Icon(
                        isModern ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                        color: headingColor.withOpacity(0.5),
                      ),
                      tooltip: isModern ? 'Classic Mode' : 'Modern Mode',
                    ),
                  ),
                  Center(
                    child: SingleChildScrollView(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 450),
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              l10n.welcome,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: headingColor,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Lütfen yönetici bilgilerinizi girin',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isModern ? bodyColor : AppColors.mgmtTextBody,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 48),
                            
                            // Form Error Area (Moved above fields for better visibility)
                            // if (authService.errorMessage != null) 
                            //  could be added if auth service exposed state, but we handle via snackbar for now.

                            _buildInput(
                              key: const ValueKey('email_input'),
                              controller: _emailController,
                              label: l10n.email,
                              icon: Icons.email_outlined,
                              isModern: isModern,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 20),
                            _buildInput(
                              key: const ValueKey('password_input'),
                              controller: _passwordController,
                              label: l10n.password,
                              icon: Icons.lock_outline,
                              isPassword: true,
                              isModern: isModern,
                            ),
                            
                            const SizedBox(height: 16),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {},
                                style: TextButton.styleFrom(
                                  foregroundColor: primaryColor,
                                  textStyle: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                child: Text(l10n.forgotPassword),
                              ),
                            ),
                            
                            const SizedBox(height: 32),
                            if (authService.isLoading)
                              const Center(child: CircularProgressIndicator())
                            else
                              ElevatedButton(
                                onPressed: () async {
                                  if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Lütfen e-posta adresinizi ve şifrenizi girin.'),
                                        backgroundColor: Colors.orange,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                    return;
                                  }

                                  try {
                                    final success = await authService.login(
                                      _emailController.text.trim(),
                                      _passwordController.text,
                                    );
                                    if (!success && mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(l10n.loginFailed),
                                          backgroundColor: Colors.redAccent,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      String errorMessage = e.toString();
                                      if (errorMessage.contains('Invalid login credentials')) {
                                        errorMessage = 'E-posta adresi veya şifre hatalı.';
                                      } else if (errorMessage.contains('Email not confirmed')) {
                                        errorMessage = 'Lütfen e-posta adresinizi doğrulayın.';
                                      } else if (errorMessage.contains('SocketException')) {
                                        errorMessage = 'İnternet bağlantınızı kontrol edin.';
                                      } else if (errorMessage.startsWith('Exception: ')) {
                                        errorMessage = errorMessage.replaceFirst('Exception: ', '');
                                      }
                                      
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(errorMessage),
                                          backgroundColor: Colors.redAccent,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 20),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: isModern ? 0 : 4,
                                  shadowColor: primaryColor.withOpacity(0.4),
                                  textStyle: const TextStyle(
                                    fontSize: 18, 
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                child: Text(l10n.login),
                              ),
                          ], // End of Column children
                        ),
                      ),
                    ),
                  ),
                ], // End of Stack children
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput({
    Key? key,
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    required bool isModern,
    TextInputType? keyboardType,
  }) {
    final primaryColor = isModern ? const Color(0xFF3B82F6) : AppColors.mgmtAccent;
    final textColor = isModern ? Colors.white : AppColors.mgmtTextHeading;
    final bgColor = isModern ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isModern ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.3);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: isModern ? [] : [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        key: key,
        controller: controller,
        obscureText: isPassword,
        keyboardType: keyboardType,
        style: TextStyle(color: textColor, fontSize: 16),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: isModern ? Colors.white54 : AppColors.mgmtTextBody, fontSize: 15),
          prefixIcon: Icon(icon, color: primaryColor, size: 22),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        ),
      ),
    );
  }
}
