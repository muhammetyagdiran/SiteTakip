import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';
import '../theme/app_theme.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;
  final BoxBorder? border;

  const GlassCard({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius,
    this.onTap,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final isModern = themeService.isModern;

    if (!isModern) {
      return Container(
        width: width,
        height: height,
        margin: margin,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: borderRadius ?? BorderRadius.circular(16),
          border: border ?? Border.all(color: const Color(0xFFE1E8EF), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: borderRadius ?? BorderRadius.circular(16),
            child: Padding(
              padding: padding ?? const EdgeInsets.all(20),
              child: child,
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius ?? BorderRadius.circular(24),
          child: Container(
            width: width,
            height: height,
            padding: padding ?? const EdgeInsets.all(20),
            margin: margin,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: borderRadius ?? BorderRadius.circular(24),
              border: border ?? Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1.5,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class GradientBackground extends StatelessWidget {
  final Widget child;

  const GradientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final isModern = themeService.isModern;

    if (!isModern) {
      return Container(
        color: const Color(0xFFF5F7FA),
        child: SafeArea(child: child),
      );
    }

    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
          ),
        ),
        Positioned(
          top: -100,
          right: -100,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF3B82F6).withOpacity(0.15),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
              child: Container(color: Colors.transparent),
            ),
          ),
        ),
        Positioned(
          bottom: -150,
          left: -150,
          child: Container(
            width: 400,
            height: 400,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF8B5CF6).withOpacity(0.15),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
              child: Container(color: Colors.transparent),
            ),
          ),
        ),
        SafeArea(child: child),
      ],
    );
  }
}

class GlassButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget child;
  final bool isPrimary;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;

  const GlassButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.isPrimary = true,
    this.width,
    this.height,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final isModern = themeService.isModern;

    if (!isModern) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isPrimary ? AppColors.mgmtAccent : Colors.white,
          border: isPrimary ? null : Border.all(color: const Color(0xFFE1E8EF)),
          boxShadow: isPrimary ? [
            BoxShadow(
              color: AppColors.mgmtAccent.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ] : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: width ?? double.infinity,
              height: height ?? 56,
              padding: padding,
              alignment: Alignment.center,
              child: child,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: isPrimary 
            ? const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isPrimary ? null : Colors.white.withOpacity(0.1),
        boxShadow: isPrimary
            ? [
                BoxShadow(
                  color: const Color(0xFF3B82F6).withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: width ?? double.infinity,
            height: height ?? 56,
            padding: padding,
            alignment: Alignment.center,
            child: child,
          ),
        ),
      ),
    );
  }
}
