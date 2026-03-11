import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/theme_service.dart';
import 'package:site_takip/l10n/app_localizations.dart';
import 'web_owner_home_content.dart';
import 'web_site_list_screen.dart';
import 'web_request_list_screen.dart';
import 'web_announcement_list_screen.dart';
import 'web_dues_management_screen.dart';
import 'web_user_management_screen.dart';
import 'web_income_expense_screen.dart';
import 'web_survey_management_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class WebOwnerDashboard extends StatefulWidget {
  const WebOwnerDashboard({super.key});

  @override
  State<WebOwnerDashboard> createState() => _WebOwnerDashboardState();
}

class _WebOwnerDashboardState extends State<WebOwnerDashboard> {
  int _currentIndex = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    // Re-use the existing screens but wrap them or just display them in the content area
    _pages = [
      WebOwnerHomeContent(onTabSelected: (index) => setState(() => _currentIndex = index)),
      WebSiteListScreen(onBack: () => setState(() => _currentIndex = 0)),
      WebRequestListScreen(onBack: () => setState(() => _currentIndex = 0)),
      WebAnnouncementListScreen(onBack: () => setState(() => _currentIndex = 0)),
      WebDuesManagementScreen(onBack: () => setState(() => _currentIndex = 0)),
      WebUserManagementScreen(onBack: () => setState(() => _currentIndex = 0)),
      WebIncomeExpenseScreen(onBack: () => setState(() => _currentIndex = 0)),
      WebSurveyManagementScreen(onBack: () => setState(() => _currentIndex = 0)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final themeService = Provider.of<ThemeService>(context);
    final authService = Provider.of<AuthService>(context);
    final isModern = themeService.isModern;
    final primaryColor = isModern ? const Color(0xFF3B82F6) : const Color(0xFF2563EB); // mgmtAccent roughly
    final bgColor = isModern ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final sidebarColor = isModern ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 250,
            color: sidebarColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Branding
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.apartment, color: primaryColor),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'SiteTakip Web',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isModern ? Colors.white : Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                
                // Navigation Links
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    children: [
                      _buildNavItem(0, Icons.dashboard_outlined, Icons.dashboard, l10n.overview, isModern, primaryColor),
                      _buildNavItem(1, Icons.business_outlined, Icons.business, l10n.sites, isModern, primaryColor),
                      _buildNavItem(2, Icons.forum_outlined, Icons.forum, l10n.requests, isModern, primaryColor),
                      _buildNavItem(3, Icons.campaign_outlined, Icons.campaign, l10n.announcements, isModern, primaryColor),
                      _buildNavItem(4, Icons.receipt_long_outlined, Icons.receipt_long, l10n.dues, isModern, primaryColor),
                      _buildNavItem(5, Icons.people_outline, Icons.people, l10n.userManagement, isModern, primaryColor),
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        child: Text(
                          'DİĞER İŞLEMLER',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isModern ? Colors.white54 : Colors.black45,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      _buildNavItem(6, Icons.account_balance_wallet_outlined, Icons.account_balance_wallet, 'Gelir / Gider', isModern, primaryColor),
                      _buildNavItem(7, Icons.poll_outlined, Icons.poll, 'Anketler', isModern, primaryColor),
                    ],
                  ),
                ),
                
                const Divider(height: 1),
                
                // Bottom Profile Area
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.grey,
                            child: Icon(Icons.person, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  authService.currentUser?.fullName ?? 'Sistem Sahibi',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isModern ? Colors.white : Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'Yönetici',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isModern ? Colors.white54 : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            icon: Icon(isModern ? Icons.light_mode : Icons.dark_mode),
                            color: isModern ? Colors.white70 : Colors.black54,
                            tooltip: 'Tema Değiştir',
                            onPressed: () => themeService.toggleTheme(),
                          ),
                          IconButton(
                            icon: const Icon(Icons.logout),
                            color: Colors.redAccent,
                            tooltip: l10n.logout,
                            onPressed: () async {
                              await authService.logout();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Main Content Area
          Expanded(
            child: ClipRect(
              child: _pages[_currentIndex],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData iconOutlined, IconData iconFilled, String label, bool isModern, Color primaryColor) {
    final isSelected = _currentIndex == index;
    final textColor = isModern ? Colors.white : Colors.black87;
    final inactiveIconColor = isModern ? Colors.white54 : Colors.black54;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            setState(() {
              _currentIndex = index;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? primaryColor.withOpacity(0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? primaryColor.withOpacity(0.3) : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isSelected ? iconFilled : iconOutlined,
                  color: isSelected ? primaryColor : inactiveIconColor,
                  size: 22,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? primaryColor : textColor,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 15,
                    ),
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
