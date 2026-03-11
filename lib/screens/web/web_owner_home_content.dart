import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/supabase_service.dart';
import '../../services/theme_service.dart';
import 'package:site_takip/l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class WebOwnerHomeContent extends StatefulWidget {
  final Function(int)? onTabSelected;
  const WebOwnerHomeContent({super.key, this.onTabSelected});

  @override
  State<WebOwnerHomeContent> createState() => _WebOwnerHomeContentState();
}

class _WebOwnerHomeContentState extends State<WebOwnerHomeContent> {
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

      // 1. Fetch site count
      final sitesResp = await SupabaseService.client
          .from('sites')
          .select('id')
          .eq('owner_id', ownerId)
          .filter('deleted_at', 'is', null);
      
      final siteIds = (sitesResp as List).map((s) => s['id'] as String).toList();

      // 2. Fetch resident count
      List<dynamic> residentsResp = [];
      if (siteIds.isNotEmpty) {
        residentsResp = await SupabaseService.client
            .from('profiles')
            .select('id')
            .eq('role', 'resident')
            .inFilter('site_id', siteIds)
            .filter('deleted_at', 'is', null);
      }

      // 3. Fetch total balance
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

      // 4. Fetch recent announcements
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
      print('Error fetching web owner stats: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final themeService = Provider.of<ThemeService>(context);
    final isModern = themeService.isModern;
    final incomeFormatter = NumberFormat.currency(locale: 'tr_TR', symbol: 'TL', decimalDigits: 0);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Genel Bakış',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: isModern ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sistemdeki sitelerinizin genel durumu',
                    style: TextStyle(
                      color: isModern ? Colors.white54 : Colors.black54,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: _fetchStats,
                icon: const Icon(Icons.refresh),
                color: isModern ? Colors.white70 : Colors.black54,
                tooltip: 'Yenile',
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Stat Cards Row
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'Toplam Kasa',
                  value: incomeFormatter.format(_totalBalance),
                  icon: Icons.account_balance_wallet,
                  gradient: const [Color(0xFF10B981), Color(0xFF34D399)],
                  isModern: isModern,
                  context: context,
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _buildStatCard(
                  title: l10n.sites,
                  value: _siteCount.toString(),
                  icon: Icons.apartment,
                  gradient: const [Color(0xFF3B82F6), Color(0xFF60A5FA)],
                  isModern: isModern,
                  context: context,
                  onTap: () => widget.onTabSelected?.call(1),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _buildStatCard(
                  title: l10n.residents,
                  value: _residentCount.toString(),
                  icon: Icons.people,
                  gradient: const [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
                  isModern: isModern,
                  context: context,
                  onTap: () => widget.onTabSelected?.call(2), // Could link to user management
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Bottom Split View
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: Announcements (2/3 width)
              Expanded(
                flex: 2,
                child: _buildAnnouncementsCard(isModern),
              ),
              const SizedBox(width: 24),
              // Right: Quick Actions (1/3 width)
              Expanded(
                flex: 1,
                child: _buildQuickActionsCard(l10n, isModern),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required List<Color> gradient,
    required bool isModern,
    required BuildContext context,
    VoidCallback? onTap,
  }) {
    final bgColor = isModern ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isModern ? Colors.white : Colors.black87;

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(16),
      elevation: isModern ? 0 : 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: isModern ? Border.all(color: Colors.white.withOpacity(0.05)) : null,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: gradient[0].withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(color: isModern ? Colors.white54 : Colors.black54, fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: TextStyle(color: textColor, fontSize: 28, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnnouncementsCard(bool isModern) {
    final bgColor = isModern ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isModern ? Colors.white : Colors.black87;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: isModern ? Border.all(color: Colors.white.withOpacity(0.05)) : null,
        boxShadow: isModern ? [] : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Son Duyurular',
                  style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () => widget.onTabSelected?.call(3), // Announcements tab
                  child: const Text('Hepsini Gör'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (_recentAnnouncements.isEmpty)
            Padding(
              padding: const EdgeInsets.all(48),
              child: Center(
                child: Text('Henüz duyuru bulunmuyor.', style: TextStyle(color: isModern ? Colors.white54 : Colors.black54)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recentAnnouncements.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final ann = _recentAnnouncements[index];
                final date = DateTime.tryParse(ann['created_at'] ?? '');
                final dateStr = date != null ? DateFormat('dd MMM yyyy', 'tr_TR').format(date) : '';
                final siteName = ann['sites']?['name'] ?? 'Genel';

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  leading: CircleAvatar(
                    backgroundColor: (isModern ? const Color(0xFF3B82F6) : AppColors.mgmtPrimary).withOpacity(0.1),
                    child: Icon(Icons.campaign, color: isModern ? const Color(0xFF3B82F6) : AppColors.mgmtPrimary),
                  ),
                  title: Text(ann['title'] ?? '', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    '$siteName • $dateStr',
                    style: TextStyle(color: isModern ? Colors.white54 : Colors.black54, fontSize: 13),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard(AppLocalizations l10n, bool isModern) {
     final bgColor = isModern ? const Color(0xFF1E293B) : Colors.white;
     final textColor = isModern ? Colors.white : Colors.black87;

     return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: isModern ? Border.all(color: Colors.white.withOpacity(0.05)) : null,
        boxShadow: isModern ? [] : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.managementTools,
            style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.1,
            children: [
              _buildActionTile(l10n.sites, Icons.business, const Color(0xFF3B82F6), () => widget.onTabSelected?.call(1), isModern),
              _buildActionTile(l10n.requests, Icons.forum, const Color(0xFFF59E0B), () => widget.onTabSelected?.call(2), isModern),
              _buildActionTile(l10n.dues, Icons.receipt_long, const Color(0xFF10B981), () => widget.onTabSelected?.call(4), isModern),
              _buildActionTile(l10n.userManagement, Icons.people, const Color(0xFF8B5CF6), () => widget.onTabSelected?.call(5), isModern),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(String title, IconData icon, Color color, VoidCallback onTap, bool isModern) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: color.withOpacity(0.2)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isModern ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
