import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:site_takip/l10n/app_localizations.dart';
import '../../services/supabase_service.dart';
import '../../services/auth_service.dart';
import '../../services/theme_service.dart';
import '../../models/user_model.dart';
import '../../theme/app_theme.dart';

/// Web-optimized Requests screen for the Owner Dashboard.
/// Replaces the mobile ManagerRequestListScreen in the web layout.
class WebRequestListScreen extends StatefulWidget {
  final String? siteId;
  final VoidCallback? onBack;
  const WebRequestListScreen({super.key, this.siteId, this.onBack});

  @override
  State<WebRequestListScreen> createState() => _WebRequestListScreenState();
}

class _WebRequestListScreenState extends State<WebRequestListScreen> {
  final List<dynamic> _requests = [];
  bool _isLoading = true;
  String? _selectedSiteId;
  List<Map<String, dynamic>> _mySites = [];
  String _filterStatus = 'all'; // all, open, in_progress, completed

  @override
  void initState() {
    super.initState();
    _selectedSiteId = widget.siteId;
    _initScreen();
  }

  Future<void> _initScreen() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.currentUser?.role == UserRole.systemOwner) {
      await _fetchMySites();
    }
    await _fetchRequests();
  }

  Future<void> _fetchMySites() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final response = await SupabaseService.client
          .from('sites')
          .select('id, name')
          .eq('owner_id', authService.currentUser!.id)
          .filter('deleted_at', 'is', null);
      setState(() {
        _mySites = List<Map<String, dynamic>>.from(response as List);
      });
    } catch (e) {
      print('Error fetching sites: $e');
    }
  }

  Future<void> _fetchRequests() async {
    setState(() => _isLoading = true);
    try {
      dynamic query = SupabaseService.client
          .from('requests')
          .select('*, profiles(full_name), apartments!inner(number, blocks!inner(name, sites!inner(name, owner_id)))')
          .filter('deleted_at', 'is', null);

      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;

      if (_selectedSiteId != null) {
        query = query.eq('apartments.blocks.site_id', _selectedSiteId as String);
      } else if (user?.role == UserRole.systemOwner) {
        final siteIds = _mySites.map((s) => s['id'] as String).toList();
        if (siteIds.isNotEmpty) {
          query = query.inFilter('apartments.blocks.site_id', siteIds);
        } else {
          setState(() {
            _requests.clear();
            _isLoading = false;
          });
          return;
        }
      }

      query = query.order('created_at', ascending: false);

      final response = await query;
      setState(() {
        _requests.clear();
        _requests.addAll(response as List);
      });
    } catch (e) {
      print('Error fetching requests: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(String id, String newStatus) async {
    try {
      await SupabaseService.client.from('requests').update({'status': newStatus}).eq('id', id);
      _fetchRequests();
    } catch (e) {
      print('Status update error: $e');
    }
  }

  Future<void> _deleteRequest(String id) async {
    final l10n = AppLocalizations.of(context)!;
    final isModern = Provider.of<ThemeService>(context, listen: false).isModern;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isModern ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 24),
            const SizedBox(width: 8),
            Expanded(child: Text('Talebi Sil', style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading, fontSize: 18))),
          ],
        ),
        content: Text(
          'Bu talebi silmek istediğinize emin misiniz?',
          style: TextStyle(color: isModern ? Colors.white70 : AppColors.mgmtTextBody, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel, style: TextStyle(color: isModern ? Colors.white54 : AppColors.mgmtTextBody, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              minimumSize: const Size(0, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await SupabaseService.client
            .from('requests')
            .update({'deleted_at': DateTime.now().toIso8601String()})
            .eq('id', id);
        _fetchRequests();
      } catch (e) {
        print('Error deleting request: $e');
      }
    }
  }

  List<dynamic> get _filteredRequests {
    if (_filterStatus == 'all') return _requests;
    return _requests.where((r) => r['status'] == _filterStatus).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isModern = Provider.of<ThemeService>(context).isModern;
    final textColor = isModern ? Colors.white : Colors.black87;
    final subtextColor = isModern ? Colors.white54 : Colors.black54;
    final primaryColor = isModern ? const Color(0xFF3B82F6) : AppColors.mgmtPrimary;
    final cardBg = isModern ? const Color(0xFF1E293B) : Colors.white;

    final openCount = _requests.where((r) => r['status'] == 'open').length;
    final progressCount = _requests.where((r) => r['status'] == 'in_progress').length;
    final completedCount = _requests.where((r) => r['status'] == 'completed').length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ──── Header ────
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.incomingRequests,
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: textColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Sakinlerden gelen talepleri takip edin ve yönetin.',
                        style: TextStyle(color: subtextColor, fontSize: 16),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _fetchRequests,
                  icon: const Icon(Icons.refresh),
                  color: subtextColor,
                  tooltip: 'Yenile',
                ),
              ],
            ),
          ),

          // ──── Filters Row ────
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 20, 32, 0),
            child: Row(
              children: [
                // Status filter chips
                _buildFilterChip('Tümü', 'all', Icons.list_alt_rounded, null, isModern, primaryColor),
                const SizedBox(width: 8),
                _buildFilterChip(l10n.open, 'open', Icons.fiber_new_rounded, Colors.blue, isModern, primaryColor, count: openCount),
                const SizedBox(width: 8),
                _buildFilterChip(l10n.inProgress, 'in_progress', Icons.hourglass_top_rounded, Colors.orange, isModern, primaryColor, count: progressCount),
                const SizedBox(width: 8),
                _buildFilterChip(l10n.completed, 'completed', Icons.check_circle_outline, Colors.green, isModern, primaryColor, count: completedCount),

                const Spacer(),

                // Site filter dropdown
                if (Provider.of<AuthService>(context, listen: false).currentUser?.role == UserRole.systemOwner && widget.siteId == null)
                  Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isModern ? Colors.white10 : AppColors.mgmtBorder),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: _selectedSiteId,
                        dropdownColor: isModern ? const Color(0xFF1E293B) : Colors.white,
                        icon: Icon(Icons.keyboard_arrow_down_rounded, color: subtextColor, size: 20),
                        hint: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.business_rounded, size: 16, color: subtextColor),
                            const SizedBox(width: 6),
                            Text('Tüm Siteler', style: TextStyle(color: subtextColor, fontSize: 13)),
                          ],
                        ),
                        style: TextStyle(color: textColor, fontSize: 13),
                        items: [
                          DropdownMenuItem(value: null, child: Text('Tüm Siteler', style: TextStyle(fontSize: 13, color: textColor))),
                          ..._mySites.map((s) => DropdownMenuItem(value: s['id'] as String, child: Text(s['name'] ?? '', style: TextStyle(fontSize: 13, color: textColor)))),
                        ],
                        onChanged: (val) {
                          setState(() => _selectedSiteId = val);
                          _fetchRequests();
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ──── Summary Cards ────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Row(
              children: [
                _buildSummaryCard('Toplam', '${_requests.length}', Icons.inbox_rounded, primaryColor, isModern, cardBg, textColor, subtextColor),
                const SizedBox(width: 12),
                _buildSummaryCard(l10n.open, '$openCount', Icons.fiber_new_rounded, Colors.blue, isModern, cardBg, textColor, subtextColor),
                const SizedBox(width: 12),
                _buildSummaryCard(l10n.inProgress, '$progressCount', Icons.hourglass_top_rounded, Colors.orange, isModern, cardBg, textColor, subtextColor),
                const SizedBox(width: 12),
                _buildSummaryCard(l10n.completed, '$completedCount', Icons.check_circle_outline, Colors.green, isModern, cardBg, textColor, subtextColor),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ──── Request Table ────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredRequests.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.forum_outlined, size: 64, color: subtextColor),
                            const SizedBox(height: 16),
                            Text(
                              _filterStatus == 'all' ? l10n.noActiveRequestsFound : 'Bu filtreye uygun talep bulunamadı.',
                              style: TextStyle(fontSize: 16, color: subtextColor),
                            ),
                          ],
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Container(
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isModern ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06)),
                          ),
                          child: Column(
                            children: [
                              // Table header
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isModern ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(16),
                                    topRight: Radius.circular(16),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(width: 200, child: Text('Başlık', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: subtextColor, letterSpacing: 0.5))),
                                    Expanded(child: Text('Konum', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: subtextColor, letterSpacing: 0.5))),
                                    SizedBox(width: 140, child: Text('Talep Eden', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: subtextColor, letterSpacing: 0.5))),
                                    SizedBox(width: 100, child: Text('Tarih', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: subtextColor, letterSpacing: 0.5))),
                                    SizedBox(width: 140, child: Text('Durum', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: subtextColor, letterSpacing: 0.5))),
                                    const SizedBox(width: 40), // delete button
                                  ],
                                ),
                              ),
                              Divider(height: 1, color: isModern ? Colors.white10 : Colors.black.withOpacity(0.06)),
                              // Table body
                              Expanded(
                                child: ListView.separated(
                                  padding: EdgeInsets.zero,
                                  itemCount: _filteredRequests.length,
                                  separatorBuilder: (_, __) => Divider(height: 1, color: isModern ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04)),
                                  itemBuilder: (context, index) {
                                    final req = _filteredRequests[index];
                                    return _buildRequestRow(req, isModern, textColor, subtextColor, primaryColor, l10n);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildRequestRow(dynamic req, bool isModern, Color textColor, Color subtextColor, Color primaryColor, AppLocalizations l10n) {
    final status = req['status'] as String;
    final siteName = req['apartments']?['blocks']?['sites']?['name'] ?? l10n.unknownSite;
    final blockName = req['apartments']?['blocks']?['name'] ?? '-';
    final aptNo = req['apartments']?['number'] ?? '-';
    final requesterName = req['profiles']?['full_name'] ?? l10n.unknown;
    final date = req['created_at'].toString().split('T')[0];

    return InkWell(
      onTap: () => _showRequestDetail(req, isModern, textColor, subtextColor, primaryColor, l10n),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            SizedBox(
              width: 200,
              child: Text(
                req['title'] ?? '',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: textColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  Icon(Icons.location_city_rounded, size: 14, color: subtextColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '$siteName / $blockName / No: $aptNo',
                      style: TextStyle(fontSize: 13, color: subtextColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 140,
              child: Row(
                children: [
                  Icon(Icons.person_outline_rounded, size: 14, color: subtextColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(requesterName, style: TextStyle(fontSize: 13, color: subtextColor), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 100,
              child: Text(date, style: TextStyle(fontSize: 13, color: subtextColor)),
            ),
            SizedBox(
              width: 140,
              child: _buildActionableStatusBadge(req['id'], status, isModern),
            ),
            SizedBox(
              width: 40,
              child: Provider.of<AuthService>(context, listen: false).currentUser?.role == UserRole.systemOwner
                  ? IconButton(
                      icon: Icon(Icons.delete_outline_rounded, color: Colors.redAccent.withOpacity(0.7), size: 18),
                      onPressed: () => _deleteRequest(req['id']),
                      tooltip: 'Sil',
                      visualDensity: VisualDensity.compact,
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  void _showRequestDetail(dynamic req, bool isModern, Color textColor, Color subtextColor, Color primaryColor, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isModern ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.forum_rounded, color: primaryColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(req['title'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 18)),
            ),
            IconButton(
              icon: Icon(Icons.close, color: subtextColor, size: 20),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (req['description'] != null && (req['description'] as String).isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isModern ? Colors.white.withOpacity(0.04) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isModern ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06)),
                  ),
                  child: Text(req['description'], style: TextStyle(color: textColor, fontSize: 14, height: 1.5)),
                ),
              const SizedBox(height: 16),
              // Location
              Row(
                children: [
                  Icon(Icons.location_city_rounded, size: 16, color: subtextColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${req['apartments']?['blocks']?['sites']?['name'] ?? l10n.unknownSite} / '
                      '${req['apartments']?['blocks']?['name'] ?? '-'} / '
                      'No: ${req['apartments']?['number'] ?? '-'}',
                      style: TextStyle(fontSize: 13, color: subtextColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Requester
              Row(
                children: [
                  Icon(Icons.person_outline_rounded, size: 16, color: subtextColor),
                  const SizedBox(width: 8),
                  Text(req['profiles']?['full_name'] ?? l10n.unknown, style: TextStyle(fontSize: 13, color: subtextColor)),
                ],
              ),
              const SizedBox(height: 8),
              // Date
              Row(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 16, color: subtextColor),
                  const SizedBox(width: 8),
                  Text(req['created_at'].toString().split('T')[0], style: TextStyle(fontSize: 13, color: subtextColor)),
                ],
              ),
              const SizedBox(height: 16),
              // Status
              Row(
                children: [
                  Text('Durum: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: textColor)),
                  _buildActionableStatusBadge(req['id'], req['status'], isModern),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, IconData icon, Color? color, bool isModern, Color primaryColor, {int? count}) {
    final isSelected = _filterStatus == value;
    final chipColor = color ?? primaryColor;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => setState(() => _filterStatus = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? chipColor.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? chipColor.withOpacity(0.4) : (isModern ? Colors.white12 : Colors.black12),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: isSelected ? chipColor : (isModern ? Colors.white54 : Colors.black45)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? chipColor : (isModern ? Colors.white70 : Colors.black54),
                ),
              ),
              if (count != null && count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: chipColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('$count', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: chipColor)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon, Color color, bool isModern, Color cardBg, Color textColor, Color subtextColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isModern ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: textColor)),
                Text(label, style: TextStyle(fontSize: 12, color: subtextColor)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionableStatusBadge(String reqId, String status, bool isModern) {
    Color color;
    String text;
    final l10n = AppLocalizations.of(context)!;
    switch (status) {
      case 'open':
        color = Colors.blue;
        text = l10n.open.toUpperCase();
        break;
      case 'in_progress':
        color = Colors.orange;
        text = l10n.inProgress.toUpperCase();
        break;
      case 'completed':
        color = Colors.green;
        text = l10n.completed.toUpperCase();
        break;
      default:
        color = Colors.grey;
        text = status.toUpperCase();
    }

    return PopupMenuButton<String>(
      onSelected: (val) => _updateStatus(reqId, val),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isModern ? const Color(0xFF1E293B) : Colors.white,
      position: PopupMenuPosition.under,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(isModern ? 0.15 : 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(isModern ? 0.4 : 0.6), width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded, color: color, size: 16),
          ],
        ),
      ),
      itemBuilder: (context) => [
        PopupMenuItem(value: 'open', child: Text(l10n.open, style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading))),
        PopupMenuItem(value: 'in_progress', child: Text(l10n.inProgress, style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading))),
        PopupMenuItem(value: 'completed', child: Text(l10n.completed, style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading))),
      ],
    );
  }
}
