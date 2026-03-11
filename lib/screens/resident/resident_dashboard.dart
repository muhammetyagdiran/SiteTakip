import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import 'package:site_takip/l10n/app_localizations.dart';
import 'resident_request_list_screen.dart';
import 'announcement_list_screen.dart';
import 'resident_dues_screen.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_widgets.dart';
import '../../services/theme_service.dart';
import '../manager/income_expense_screen.dart';
import 'resident_survey_screen.dart';
import '../../services/supabase_service.dart';

class ResidentDashboard extends StatefulWidget {
  const ResidentDashboard({super.key});

  @override
  State<ResidentDashboard> createState() => _ResidentDashboardState();
}

class _ResidentDashboardState extends State<ResidentDashboard> {
  int _currentIndex = 0;
  String? _siteId;
  String? _siteName;
  bool _isLoadingSite = true;

  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _fetchSiteInfo();
  }

  Future<void> _fetchSiteInfo() async {
    setState(() => _isLoadingSite = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUser?.id;
      if (userId == null) return;

      final aptData = await SupabaseService.client
          .from('apartments')
          .select('id, blocks(site_id, sites(name))')
          .eq('resident_id', userId)
          .maybeSingle();

      if (aptData != null && aptData['blocks'] != null) {
        final site = aptData['blocks']['sites'];
        setState(() {
          _siteId = aptData['blocks']['site_id'];
          _siteName = site != null ? site['name'] : null;
        });
      }
    } catch (e) {
      print('Error fetching resident site info: $e');
    } finally {
      if (mounted) {
        _initPages();
        setState(() => _isLoadingSite = false);
      }
    }
  }

  void _initPages() {
    _pages = [
      ResidentHomeContent(
        siteId: _siteId,
        siteName: _siteName,
        onTabSelected: (index) => setState(() => _currentIndex = index)
      ),
      AnnouncementListScreen(onBack: () => setState(() => _currentIndex = 0)),
      ResidentDuesScreen(onBack: () => setState(() => _currentIndex = 0)),
      ResidentRequestListScreen(onBack: () => setState(() => _currentIndex = 0)),
      IncomeExpenseScreen(siteId: _siteId, onBack: () => setState(() => _currentIndex = 0)),
      ResidentSurveyScreen(siteId: _siteId, onBack: () => setState(() => _currentIndex = 0)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      extendBody: true,
      body: _isLoadingSite 
          ? const Center(child: CircularProgressIndicator())
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
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

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
          children: List.generate(4, (index) {
            final isActive = _currentIndex == index || (index == 0 && _currentIndex >= 4);
            final icons = [
              [Icons.dashboard_outlined, Icons.dashboard],
              [Icons.campaign_outlined, Icons.campaign],
              [Icons.receipt_long_outlined, Icons.receipt_long],
              [Icons.forum_outlined, Icons.forum],
            ];
            final labels = [
              l10n.home,
              l10n.announcements,
              l10n.dues,
              l10n.requests,
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

class ResidentHomeContent extends StatefulWidget {
  final String? siteId;
  final String? siteName;
  final Function(int)? onTabSelected;
  const ResidentHomeContent({super.key, this.siteId, this.siteName, this.onTabSelected});

  @override
  State<ResidentHomeContent> createState() => _ResidentHomeContentState();
}

class _ResidentHomeContentState extends State<ResidentHomeContent> {
  int _activeRequestCount = 0;
  int _unpaidDuesCount = 0;
  List<dynamic> _recentAnnouncements = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    setState(() => _isLoading = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUser?.id;
      if (userId == null || widget.siteId == null) return;

      // 1. Unpaid Dues
      final aptData = await SupabaseService.client
          .from('apartments')
          .select('id')
          .eq('resident_id', userId)
          .maybeSingle();

      if (aptData != null) {
        final duesResponse = await SupabaseService.client
            .from('dues')
            .select('id')
            .filter('deleted_at', 'is', null)
            .eq('apartment_id', aptData['id'])
            .neq('status', 'paid');
        _unpaidDuesCount = (duesResponse as List).length;
      }

      // 2. Active Requests
      final requestsResponse = await SupabaseService.client
          .from('requests')
          .select('id')
          .filter('deleted_at', 'is', null)
          .eq('resident_id', userId)
          .neq('status', 'completed');
      _activeRequestCount = (requestsResponse as List).length;

      // 3. Recent Announcements
      if (widget.siteId != null) {
        final announcementsResp = await SupabaseService.client
            .from('announcements')
            .select('title, content, created_at')
            .eq('site_id', widget.siteId as String)
            .order('created_at', ascending: false)
            .limit(5);
        _recentAnnouncements = announcementsResp as List;
      }

      setState(() {});
    } catch (e) {
      print('Error fetching resident stats: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final themeService = Provider.of<ThemeService>(context);
    final isModern = themeService.isModern;
    final authService = Provider.of<AuthService>(context, listen: false);
    final userName = authService.currentUser?.fullName ?? l10n.residentRole;
    final displaySiteName = widget.siteName ?? "";

    return GradientBackground(
      child: Column(
        children: [
          // Premium gradient header
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
                          if (displaySiteName.isNotEmpty) ...[
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
                    // Stats Row
                    if (_isLoading)
                      const Center(child: LinearProgressIndicator())
                    else
                      IntrinsicHeight(
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildInfoCard(
                                l10n.activeRequests, 
                                _activeRequestCount.toString(), 
                                Icons.forum_rounded, 
                                [const Color(0xFF818CF8), const Color(0xFFA78BFA)],
                                isModern,
                                onTap: () => widget.onTabSelected?.call(3),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildInfoCard(
                                l10n.unpaidDues, 
                                _unpaidDuesCount.toString(), 
                                Icons.money_off_rounded, 
                                [const Color(0xFFFB7185), const Color(0xFFFDA4AF)],
                                isModern,
                                onTap: () => widget.onTabSelected?.call(2),
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    const SizedBox(height: 24),
                    
                    // Quick Actions Header
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
                          'Hızlı Erişim', 
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: isModern ? Colors.white : AppColors.mgmtTextHeading,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          )
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Tools Grid (2x2)
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
                                () => widget.onTabSelected?.call(4),
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
                                () => widget.onTabSelected?.call(5),
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
                                l10n.announcements,
                                Icons.campaign_rounded,
                                Colors.lightBlueAccent,
                                () => widget.onTabSelected?.call(1),
                                isModern,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildToolCard(
                                context,
                                l10n.requests,
                                Icons.forum_rounded,
                                Colors.purpleAccent,
                                () => widget.onTabSelected?.call(3),
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
                                l10n.quickAnnouncements, 
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: isModern ? Colors.white : AppColors.mgmtTextHeading,
                                  fontWeight: FontWeight.bold,
                                )
                              ),
                            ],
                          ),
                          TextButton(
                            onPressed: () => widget.onTabSelected?.call(1),
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
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: subTextColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolCard(BuildContext context, String label, IconData icon, Color color, VoidCallback? onTap, bool isModern) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: isModern ? Colors.white.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isModern ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04),
          ),
          boxShadow: isModern ? null : [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(isModern ? 0.15 : 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isModern ? Colors.white : AppColors.mgmtTextHeading,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.chevron_right_rounded, 
              size: 18, 
              color: isModern ? Colors.white24 : Colors.black12,
            ),
          ],
        ),
      ),
    );
  }
}
