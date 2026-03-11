import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/theme_service.dart';
import 'package:site_takip/l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/glass_widgets.dart';
import '../../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
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
      body: GradientBackground(
        child: Stack(
          children: [
            Positioned(
              top: 10,
              right: 10,
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
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Hero(
                      tag: 'app_logo',
                      child: Container(
                        padding: const EdgeInsets.all(20),
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
                        child: const Icon(Icons.apartment_rounded, size: 56, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'SiteTakip',
                      style: GoogleFonts.outfit(
                        color: headingColor,
                        fontSize: 42,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.welcome,
                      style: GoogleFonts.outfit(
                        color: bodyColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 48),
                    GlassCard(
                      child: Column(
                        children: [
                          _buildGlassInput(
                            controller: _emailController,
                            label: l10n.email,
                            icon: Icons.email_outlined,
                            isModern: isModern,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 16),
                          _buildGlassInput(
                            controller: _passwordController,
                            label: l10n.password,
                            icon: Icons.lock_outline,
                            isPassword: true,
                            isModern: isModern,
                          ),
                          const SizedBox(height: 24),
                          if (authService.isLoading)
                            const CircularProgressIndicator()
                          else
                            GlassButton(
                              onPressed: () async {
                                try {
                                  final success = await authService.login(
                                    _emailController.text,
                                    _passwordController.text,
                                  );
                                  if (!success && mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(l10n.loginFailed),
                                        backgroundColor: Colors.redAccent,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                                        margin: const EdgeInsets.all(16),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    );
                                  }
                                }
                              },
                              child: Text(
                                l10n.login,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {},
                      style: TextButton.styleFrom(
                        foregroundColor: bodyColor.withOpacity(0.8),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      child: Text(
                        l10n.forgotPassword,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    required bool isModern,
    TextInputType? keyboardType,
  }) {
    final primaryColor = isModern ? const Color(0xFF3B82F6) : AppColors.mgmtAccent;
    final textColor = isModern ? Colors.white : AppColors.mgmtTextHeading;
    final labelColor = isModern ? Colors.white.withOpacity(0.5) : AppColors.mgmtTextBody;

    return Container(
      decoration: BoxDecoration(
        color: isModern ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isModern ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.2)),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: keyboardType,
        style: TextStyle(color: textColor, fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: labelColor, fontSize: 14),
          prefixIcon: Icon(icon, color: primaryColor, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }
}
