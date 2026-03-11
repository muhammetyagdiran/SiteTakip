import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/supabase_service.dart';
import 'package:site_takip/l10n/app_localizations.dart';
import 'resident_management_screen.dart';
import 'manager_request_list_screen.dart';
import 'manager_announcement_list_screen.dart';
import 'dues_management_screen.dart';
import 'site_structure_screen.dart';
import 'income_expense_screen.dart';
import 'survey_management_screen.dart';
import '../../widgets/glass_widgets.dart';
import '../../theme/app_theme.dart';
import 'dart:ui';
import 'package:intl/intl.dart';
import '../../services/theme_service.dart';

class ManagerDashboard extends StatefulWidget {
  const ManagerDashboard({super.key});

  @override
  State<ManagerDashboard> createState() => _ManagerDashboardState();
}

class _ManagerDashboardState extends State<ManagerDashboard> {
  int _currentIndex = 0;
  String? _siteId;
  String? _siteName;
  bool _isLoadingSite = true;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _fetchAssignedSite();
  }

  Future<void> _fetchAssignedSite() async {
    setState(() => _isLoadingSite = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUser?.id;
      if (userId == null) return;

      final response = await SupabaseService.client
          .from('sites')
          .select('id, name')
          .eq('manager_id', userId)
          .maybeSingle();

      if (response != null) {
        setState(() {
          _siteId = response['id'];
          _siteName = response['name'];
        });
      }
    } catch (e) {
      print('Error fetching assigned site: $e');
    } finally {
      setState(() => _isLoadingSite = false);
      _initPages();
    }
  }

  void _initPages() {
    _pages = [
      ManagerHomeContent(
        siteId: _siteId, 
        siteName: _siteName,
        onTabChanged: (index) => setState(() => _currentIndex = index),
      ),
      ResidentManagementScreen(siteId: _siteId, onBack: () => setState(() => _currentIndex = 0)),
      ManagerRequestListScreen(siteId: _siteId, onBack: () => setState(() => _currentIndex = 0)),
      DuesManagementScreen(siteId: _siteId, onBack: () => setState(() => _currentIndex = 0)),
      ManagerAnnouncementListScreen(siteId: _siteId, onBack: () => setState(() => _currentIndex = 0)),
      IncomeExpenseScreen(siteId: _siteId, onBack: () => setState(() => _currentIndex = 0)),
      SurveyManagementScreen(siteId: _siteId, onBack: () => setState(() => _currentIndex = 0)),
      SiteStructureScreen(siteId: _siteId, onBack: () => setState(() => _currentIndex = 0)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      extendBody: true,
      body: _isLoadingSite 
          ? const Center(child: CircularProgressIndicator())
          : _siteId == null
              ? _buildNoSiteMessage(l10n)
              : _pages[_currentIndex],
      bottomNavigationBar: _siteId == null ? null : _buildBottomNavBar(l10n),
    );
  }

  Widget _buildNoSiteMessage(AppLocalizations l10n) {
    final authService = Provider.of<AuthService>(context, listen: false);
    return GradientBackground(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: GlassCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.domain_disabled, size: 64, color: Colors.orangeAccent),
                const SizedBox(height: 24),
                Text(
                  l10n.noAssignedSite,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, color: Colors.white),
                ),
                const SizedBox(height: 32),
                GlassButton(
                  onPressed: () => authService.logout(),
                  child: Text(l10n.logout),
                ),
              ],
            ),
          ),
        ),
      ),
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
          children: List.generate(5, (index) {
            final isActive = _currentIndex == index || (index == 0 && _currentIndex >= 5);
            final icons = [
              [Icons.dashboard_outlined, Icons.dashboard],
              [Icons.people_outline, Icons.people],
              [Icons.forum_outlined, Icons.forum],
              [Icons.monetization_on_outlined, Icons.monetization_on],
              [Icons.campaign_outlined, Icons.campaign],
            ];
            final labels = [
              l10n.dashboard,
              l10n.residents,
              l10n.requests,
              l10n.dues,
              l10n.announcements,
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

class ManagerHomeContent extends StatefulWidget {
  final String? siteId;
  final String? siteName;
  final Function(int)? onTabChanged;
  const ManagerHomeContent({super.key, this.siteId, this.siteName, this.onTabChanged});

  @override
  State<ManagerHomeContent> createState() => _ManagerHomeContentState();
}

class _ManagerHomeContentState extends State<ManagerHomeContent> {
  int _residentCount = 0;
  int _requestCount = 0;
  int _delayedDuesCount = 0;
  double _totalBalance = 0.0;
  List<dynamic> _recentAnnouncements = [];
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    if (widget.siteId == null) return;
    setState(() => _isLoadingStats = true);
    try {
      // 1. Resident Count (Filtered by Site via Join)
      final dynamic residentQuery = SupabaseService.client
          .from('profiles')
          .select('id, apartments!inner(blocks!inner(site_id))')
          .eq('role', 'resident')
          .filter('deleted_at', 'is', null) // Soft delete filter
          .eq('apartments.blocks.site_id', widget.siteId as String);
      final residents = await residentQuery;
      _residentCount = (residents as List).length;

      // 2. Pending Requests Count (Filtered by Site via Join)
      final dynamic requestQuery = SupabaseService.client
          .from('requests')
          .select('id, apartments!inner(blocks!inner(site_id))')
          .filter('deleted_at', 'is', null) // Soft delete filter
          .neq('status', 'completed')
          .eq('apartments.blocks.site_id', widget.siteId as String);
      final requests = await requestQuery;
      _requestCount = (requests as List).length;

      // 3. Delayed Dues Count (Unpaid AND past due date)
      final now = DateTime.now().toIso8601String();
      final dynamic duesQuery = SupabaseService.client
          .from('dues')
          .select('id, apartments!inner(blocks!inner(site_id))')
          .filter('deleted_at', 'is', null)
          .neq('status', 'paid')
          .lt('due_date', now)
          .eq('apartments.blocks.site_id', widget.siteId as String);
      final dues = await duesQuery;
      _delayedDuesCount = (dues as List).length;
      
      // 4. Fetch Total Balance (income - expense for this site)
      final transactionsResp = await SupabaseService.client
          .from('income_expense')
          .select('amount, type')
          .eq('site_id', widget.siteId as String);
      
      double balance = 0;
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
      _totalBalance = balance;

      // 5. Fetch recent announcements for this site
      final announcementsResp = await SupabaseService.client
          .from('announcements')
          .select('title, content, created_at')
          .eq('site_id', widget.siteId as String)
          .order('created_at', ascending: false)
          .limit(5);
      _recentAnnouncements = announcementsResp as List;

    } catch (e) {
      print('Error fetching stats: $e');
    } finally {
      if (mounted) setState(() => _isLoadingStats = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final themeService = Provider.of<ThemeService>(context);
    final isModern = themeService.isModern;
    final authService = Provider.of<AuthService>(context, listen: false);
    final userName = authService.currentUser?.fullName ?? "";
    final displaySiteName = widget.siteName ?? "";
    final formatter = NumberFormat.currency(locale: 'tr_TR', symbol: 'TL', decimalDigits: 0);

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
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.business_rounded, color: Colors.white70, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                displaySiteName,
                                style: const TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () => themeService.toggleTheme(),
                          icon: Icon(isModern 
                            ? Icons.light_mode_outlined 
                            : Icons.dark_mode_outlined,
                            color: Colors.white70,
                            size: 20,
                          ),
                        ),
                        IconButton(
                          onPressed: _fetchStats,
                          icon: const Icon(Icons.refresh, color: Colors.white70, size: 20),
                        ),
                        IconButton(
                          onPressed: () => authService.logout(),
                          icon: const Icon(Icons.logout, color: Colors.redAccent, size: 20),
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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBalanceCard(context, l10n),
                  const SizedBox(height: 16),
                  
                  // Stats Row
                  if (_isLoadingStats)
                    const Center(child: LinearProgressIndicator())
                  else
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildInfoCard(
                                l10n.residents, 
                                _residentCount.toString(), 
                                Icons.people_rounded, 
                                [const Color(0xFF67E8F9), const Color(0xFF7DD3FC)],
                                isModern,
                                onTap: () => widget.onTabChanged?.call(1),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildInfoCard(
                                l10n.requests, 
                                _requestCount.toString(), 
                                Icons.forum_rounded, 
                                [const Color(0xFF818CF8), const Color(0xFFA78BFA)],
                                isModern,
                                onTap: () => widget.onTabChanged?.call(2),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _buildInfoCard(
                          l10n.delayedDues, 
                          _delayedDuesCount.toString(), 
                          Icons.money_off_rounded, 
                          [const Color(0xFFFB7185), const Color(0xFFFDA4AF)],
                          isModern,
                          fullWidth: true,
                          onTap: () => widget.onTabChanged?.call(3),
                        ),
                      ],
                    ),
                  
                  const SizedBox(height: 24),
                  
                  // Management Tools Header
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
                  
                  // Tools Grid
                  Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildToolCard(
                              context,
                              l10n.siteYapisi.split(' ')[0],
                              Icons.account_tree_rounded,
                              AppColors.secondary,
                              () {
                                if (widget.onTabChanged != null) {
                                  widget.onTabChanged!(7); // Index for SiteStructureScreen
                                }
                              },
                              isModern,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildToolCard(
                              context,
                              l10n.residentList,
                              Icons.people_alt_rounded,
                              AppColors.primary,
                              () => widget.onTabChanged?.call(1),
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
                              l10n.incomeExpense,
                              Icons.account_balance_wallet_rounded,
                              Colors.greenAccent,
                              () => widget.onTabChanged?.call(5),
                              isModern,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildToolCard(
                              context,
                              l10n.surveys,
                              Icons.poll_rounded,
                              Colors.orangeAccent,
                              () => widget.onTabChanged?.call(6),
                              isModern,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Announcements Section
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
                          onPressed: () => widget.onTabChanged?.call(4),
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
                                Expanded(
                                  child: Text(
                                    ann['content'] ?? '',
                                    style: TextStyle(
                                      color: isModern ? Colors.white70 : AppColors.mgmtTextBody,
                                      fontSize: 11,
                                    ),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
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

  Widget _buildInfoCard(String label, String value, IconData icon, List<Color> gradient, bool isModern, {VoidCallback? onTap, bool fullWidth = false}) {
    final textColor = isModern ? Colors.white : AppColors.mgmtTextHeading;
    final subTextColor = isModern ? Colors.white.withOpacity(0.8) : AppColors.mgmtTextBody;
    final iconColor = isModern ? Colors.white : gradient[0];
    final iconBgColor = isModern ? Colors.white.withOpacity(0.15) : gradient[0].withOpacity(0.12);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: fullWidth ? double.infinity : null,
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
          mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
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
            if (fullWidth) const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 16),
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

  Widget _buildBalanceCard(BuildContext context, AppLocalizations l10n) {
    final isModern = Provider.of<ThemeService>(context, listen: false).isModern;
    final formatter = NumberFormat.currency(locale: 'tr_TR', symbol: 'TL', decimalDigits: 0);
    final color = _totalBalance >= 0 ? Colors.greenAccent : Colors.pinkAccent;

    return InkWell(
      onTap: () => widget.onTabChanged?.call(5),
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
              child: _isLoadingStats 
                ? const SizedBox(height: 38, child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))))
                : Text(
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
}
