import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/supabase_service.dart';
import '../../services/theme_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/theme_service.dart';
import 'package:site_takip/l10n/app_localizations.dart';
import 'user_management_screen.dart';
import 'site_list_screen.dart';
import '../manager/manager_request_list_screen.dart';
import '../manager/manager_announcement_list_screen.dart';
import '../manager/dues_management_screen.dart';
import '../manager/income_expense_screen.dart';
import '../manager/survey_management_screen.dart';
import '../../widgets/glass_widgets.dart';
import '../../theme/app_theme.dart';
import 'dart:ui';

class OwnerDashboard extends StatefulWidget {
  const OwnerDashboard({super.key});

  @override
  State<OwnerDashboard> createState() => _OwnerDashboardState();
}

class _OwnerDashboardState extends State<OwnerDashboard> {
  int _currentIndex = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const OwnerHomeContent(),
      SiteListScreen(onBack: () => setState(() => _currentIndex = 0)),
      ManagerRequestListScreen(onBack: () => setState(() => _currentIndex = 0)),
      ManagerAnnouncementListScreen(onBack: () => setState(() => _currentIndex = 0)),
      DuesManagementScreen(onBack: () => setState(() => _currentIndex = 0)),
      UserManagementScreen(onBack: () => setState(() => _currentIndex = 0)),
      IncomeExpenseScreen(onBack: () => setState(() => _currentIndex = 0)),
      SurveyManagementScreen(onBack: () => setState(() => _currentIndex = 0)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      extendBody: true,
      body: _currentIndex == 0 
          ? OwnerHomeContent(onTabSelected: (index) => setState(() => _currentIndex = index))
          : _pages[_currentIndex],
      bottomNavigationBar: _buildBottomNavBar(l10n),
    );
  }

  Widget _buildBottomNavBar(AppLocalizations l10n) {
    final themeService = Provider.of<ThemeService>(context);
    final isModern = themeService.isModern;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final activeColor = isModern ? AppColors.primary : AppColors.mgmtAccent;
    final inactiveColor = isModern 
        ? const Color(0xFF94A3B8) // slate-400
        : const Color(0xFF64748B); // slate-500

    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding > 0 ? bottomPadding : 12),
      decoration: BoxDecoration(
        color: isModern ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isModern ? 0.3 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
        border: isModern 
            ? Border.all(color: Colors.white.withOpacity(0.08))
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(6, (index) {
            final isActive = _currentIndex == index || (index == 0 && _currentIndex >= 6);
            final icons = [
              [Icons.dashboard_outlined, Icons.dashboard],
              [Icons.business_outlined, Icons.business],
              [Icons.forum_outlined, Icons.forum],
              [Icons.campaign_outlined, Icons.campaign],
              [Icons.receipt_long_outlined, Icons.receipt_long],
              [Icons.people_outline, Icons.people],
            ];
            final labels = [
              l10n.overview,
              l10n.sites,
              l10n.requests,
              l10n.announcements,
              l10n.dues,
              l10n.userManagement,
            ];
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _currentIndex = index),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: EdgeInsets.symmetric(
                        horizontal: isActive ? 12 : 8,
                        vertical: isActive ? 6 : 4,
                      ),
                      decoration: BoxDecoration(
                        color: isActive 
                            ? activeColor.withOpacity(0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        isActive ? icons[index][1] : icons[index][0],
                        color: isActive ? activeColor : inactiveColor,
                        size: isActive ? 26 : 24,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      labels[index],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isActive ? activeColor : inactiveColor,
                        fontSize: isActive ? 12 : 11,
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class OwnerHomeContent extends StatefulWidget {
  final Function(int)? onTabSelected;
  const OwnerHomeContent({super.key, this.onTabSelected});

  @override
  State<OwnerHomeContent> createState() => _OwnerHomeContentState();
}

class _OwnerHomeContentState extends State<OwnerHomeContent> {
  bool _isLoading = true;
  int _siteCount = 0;
  int _residentCount = 0;
  double _totalBalance = 0.0;
  List<dynamic> _recentAnnouncements = [];

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    setState(() => _isLoading = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final ownerId = authService.currentUser?.id;
      if (ownerId == null) return;

      // 1. Fetch site count (not deleted, owned by current owner)
      final sitesResp = await SupabaseService.client
          .from('sites')
          .select('id')
          .eq('owner_id', ownerId)
          .filter('deleted_at', 'is', null);
      
      // 2. Get site IDs
      final siteIds = (sitesResp as List).map((s) => s['id'] as String).toList();

      // 3. Fetch resident count (profiles with role=resident in owner's sites)
      List<dynamic> residentsResp = [];
      if (siteIds.isNotEmpty) {
        residentsResp = await SupabaseService.client
            .from('profiles')
            .select('id')
            .eq('role', 'resident')
            .inFilter('site_id', siteIds)
            .filter('deleted_at', 'is', null);
      }

      // 4. Fetch total balance (income - expense across all sites)
      double balance = 0;
      if (siteIds.isNotEmpty) {
        final transactionsResp = await SupabaseService.client
            .from('income_expense')
            .select('amount, type')
            .inFilter('site_id', siteIds);
        
        if (transactionsResp != null) {
          for (var t in transactionsResp as List) {
            final double amt = (t['amount'] ?? 0).toDouble();
            if (t['type'] == 'income') {
              balance += amt;
            } else {
              balance -= amt;
            }
          }
        }
      }

      // 5. Fetch recent announcements across all sites
      if (siteIds.isNotEmpty) {
        final announcementsResp = await SupabaseService.client
            .from('announcements')
            .select('title, content, created_at, site_id, sites(name)')
            .inFilter('site_id', siteIds)
            .order('created_at', ascending: false)
            .limit(5);
        
        _recentAnnouncements = announcementsResp as List;
      }

      if (mounted) {
        setState(() {
          _siteCount = siteIds.length;
          _residentCount = (residentsResp as List).length;
          _totalBalance = balance;
          _recentAnnouncements = _recentAnnouncements;
        });
      }
    } catch (e) {
      print('Error fetching owner stats: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final themeService = Provider.of<ThemeService>(context);
    final isModern = themeService.isModern;
    final authService = Provider.of<AuthService>(context, listen: false);
    final userName = authService.currentUser?.fullName ?? l10n.systemOwner;

    final incomeFormatter = NumberFormat.currency(locale: 'tr_TR', symbol: 'TL', decimalDigits: 0);

    return GradientBackground(
      child: Column(
        children: [
          // Custom modern header
          Container(
            padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 12, 12, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isModern 
                    ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                    : [AppColors.mgmtPrimary, const Color(0xFF0D2B4E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: greeting + actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.welcome,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            userName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () => context.read<ThemeService>().toggleTheme(),
                          icon: Icon(context.watch<ThemeService>().isModern 
                            ? Icons.light_mode_outlined 
                            : Icons.dark_mode_outlined,
                            color: Colors.white70,
                            size: 20,
                          ),
                          tooltip: 'Tema Değiştir',
                          visualDensity: VisualDensity.compact,
                        ),
                        IconButton(
                          onPressed: _fetchStats,
                          icon: const Icon(Icons.refresh, color: Colors.white70, size: 20),
                          visualDensity: VisualDensity.compact,
                        ),
                        PopupMenuButton<String>(
                          offset: const Offset(0, 45),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          color: isModern ? const Color(0xFF1E293B) : Colors.white,
                          onSelected: (value) {
                            if (value == 'logout') {
                              authService.logout();
                            } else if (value == 'settings') {
                              // TODO: Navigate to settings
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'settings',
                              child: Row(
                                children: [
                                  Icon(Icons.settings_outlined, size: 18, color: isModern ? Colors.white70 : AppColors.mgmtTextBody),
                                  const SizedBox(width: 10),
                                  Text('Ayarlar', style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading)),
                                ],
                              ),
                            ),
                            const PopupMenuDivider(),
                            PopupMenuItem(
                              value: 'logout',
                              child: Row(
                                children: [
                                  Icon(Icons.logout, size: 18, color: Colors.redAccent.withOpacity(0.8)),
                                  const SizedBox(width: 10),
                                  const Text('Çıkış Yap', style: TextStyle(color: Colors.redAccent)),
                                ],
                              ),
                            ),
                          ],
                          child: _buildProfileAvatar(userName, isModern),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Body content
          Expanded(
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildBalanceCard(context, incomeFormatter),
                          const SizedBox(height: 12),
                          IntrinsicHeight(
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildInfoCard(
                                    l10n.sites, 
                                    _siteCount.toString(), 
                                    Icons.business_rounded, 
                                    [const Color(0xFF818CF8), const Color(0xFFA78BFA)],
                                    isModern,
                                    onTap: () => widget.onTabSelected?.call(1),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildInfoCard(
                                    l10n.residents, 
                                    _residentCount.toString(), 
                                    Icons.people_alt_rounded, 
                                    [const Color(0xFF67E8F9), const Color(0xFF7DD3FC)],
                                    isModern,
                                    onTap: () => widget.onTabSelected?.call(1),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Container(
                                width: 4,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: isModern ? AppColors.primary : AppColors.mgmtAccent,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                l10n.managementTools, 
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: isModern ? Colors.white : AppColors.mgmtTextHeading,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                )
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildToolCard(
                                      context,
                                      l10n.incomeExpense,
                                      Icons.account_balance_wallet_rounded,
                                      Colors.greenAccent,
                                      () => widget.onTabSelected?.call(6),
                                      isModern,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _buildToolCard(
                                      context,
                                      l10n.surveys,
                                      Icons.poll_rounded,
                                      Colors.amberAccent,
                                      () => widget.onTabSelected?.call(7),
                                      isModern,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildToolCard(
                                      context,
                                      l10n.userManagement,
                                      Icons.manage_accounts_rounded,
                                      Colors.pinkAccent,
                                      () => widget.onTabSelected?.call(5),
                                      isModern,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _buildToolCard(
                                      context,
                                      l10n.sites,
                                      Icons.location_city_rounded,
                                      Colors.lightBlueAccent,
                                      () => widget.onTabSelected?.call(1),
                                      isModern,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          if (_recentAnnouncements.isNotEmpty) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 4,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        color: isModern ? AppColors.primary : AppColors.mgmtAccent,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      l10n.announcements, 
                                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                        color: isModern ? Colors.white : AppColors.mgmtTextHeading,
                                        fontWeight: FontWeight.bold,
                                      )
                                    ),
                                  ],
                                ),
                                TextButton(
                                  onPressed: () => widget.onTabSelected?.call(3),
                                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                  child: Text(
                                    'Hepsini Gör', 
                                    style: TextStyle(
                                      fontSize: 12, 
                                      color: isModern ? AppColors.primary : AppColors.mgmtAccent,
                                      fontWeight: FontWeight.w600,
                                    )
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 85,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _recentAnnouncements.length,
                                separatorBuilder: (context, index) => const SizedBox(width: 12),
                                itemBuilder: (context, index) {
                                  final ann = _recentAnnouncements[index];
                                  final siteName = ann['sites']?['name'] ?? '';
                                  final date = DateTime.parse(ann['created_at']);
                                  final dateStr = DateFormat('dd MMM').format(date);

                                  return Container(
                                    width: 240,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isModern ? Colors.white.withOpacity(0.05) : Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isModern ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                                      ),
                                      boxShadow: isModern ? null : [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.03),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        )
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                ann['title'] ?? '',
                                                style: TextStyle(
                                                  color: isModern ? Colors.white : AppColors.mgmtTextHeading,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              dateStr,
                                              style: TextStyle(
                                                color: isModern ? Colors.white60 : AppColors.mgmtTextBody,
                                                fontSize: 10,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          ann['content'] ?? '',
                                          style: TextStyle(
                                            color: isModern ? Colors.white70 : AppColors.mgmtTextBody,
                                            fontSize: 11,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const Spacer(),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.business_rounded, 
                                              size: 10, 
                                              color: isModern ? AppColors.primary : AppColors.mgmtAccent
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                siteName,
                                                style: TextStyle(
                                                  color: isModern ? AppColors.primary : AppColors.mgmtAccent,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(BuildContext context, NumberFormat formatter) {
    final themeService = Provider.of<ThemeService>(context, listen: false);
    final isModern = themeService.isModern;
    final color = _totalBalance >= 0 ? Colors.greenAccent : Colors.pinkAccent;

    return InkWell(
      onTap: () => widget.onTabSelected?.call(6),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: isModern 
                ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                : [AppColors.mgmtPrimary, AppColors.mgmtPrimary.withOpacity(0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isModern ? 0.2 : 0.1),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Toplam Net Bakiye',
                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.w500),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.account_balance_wallet_rounded, color: color, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 6),
            FittedBox(
              child: Text(
                formatter.format(_totalBalance),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String label, String value, IconData icon, List<Color> gradient, bool isModern, {VoidCallback? onTap}) {
    final textColor = isModern ? Colors.white : AppColors.mgmtTextHeading;
    final subTextColor = isModern ? Colors.white.withOpacity(0.8) : AppColors.mgmtTextBody;
    final iconColor = isModern ? Colors.white : gradient[0];
    final iconBgColor = isModern ? Colors.white.withOpacity(0.15) : gradient[0].withOpacity(0.12);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: isModern ? null : Colors.white,
          gradient: isModern ? LinearGradient(
            colors: gradient.map((c) => c.withOpacity(0.15)).toList(),
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ) : null,
          border: Border.all(color: isModern ? gradient[0].withOpacity(0.15) : gradient[0].withOpacity(0.25)),
          boxShadow: isModern ? null : [
            BoxShadow(
              color: gradient[0].withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    label,
                    style: TextStyle(color: subTextColor, fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolCard(BuildContext context, String label, IconData icon, Color color, VoidCallback onTap, bool isModern) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: isModern ? Colors.white : AppColors.mgmtTextHeading,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileAvatar(String fullName, bool isModern) {
    String initials = '';
    final parts = fullName.trim().split(' ');
    if (parts.isNotEmpty) initials += parts[0][0].toUpperCase();
    if (parts.length > 1) initials += parts[parts.length - 1][0].toUpperCase();
    if (initials.isEmpty) initials = '?';

    return CircleAvatar(
      radius: 17,
      backgroundColor: isModern 
          ? AppColors.primary.withOpacity(0.3) 
          : AppColors.mgmtAccent.withOpacity(0.15),
      child: Text(
        initials,
        style: TextStyle(
          color: isModern ? Colors.white : AppColors.mgmtAccent,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
