import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../services/supabase_service.dart';
import '../../services/auth_service.dart';
import 'package:provider/provider.dart';
import '../../widgets/glass_widgets.dart';
import '../../services/theme_service.dart';
import '../../theme/app_theme.dart';
import 'package:site_takip/l10n/app_localizations.dart';

class ResidentDuesScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const ResidentDuesScreen({super.key, this.onBack});

  @override
  State<ResidentDuesScreen> createState() => _ResidentDuesScreenState();
}

class _ResidentDuesScreenState extends State<ResidentDuesScreen> {
  final List<dynamic> _dues = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMyDues();
  }

  String _formatMonth(String monthStr) {
    try {
      final parts = monthStr.split('-');
      if (parts.length >= 2) {
        final year = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        if (year != null && month != null && month >= 1 && month <= 12) {
          final months = [
            'OCAK', 'ŞUBAT', 'MART', 'NİSAN', 'MAYIS', 'HAZİRAN',
            'TEMMUZ', 'AĞUSTOS', 'EYLÜL', 'EKİM', 'KASIM', 'ARALIK'
          ];
          return '${months[month - 1]} - $year';
        }
      }
    } catch (e) {}
    return monthStr.toUpperCase();
  }

  Future<void> _fetchMyDues() async {
    setState(() => _isLoading = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUser?.id;
      if (userId == null) return;

      final aptData = await SupabaseService.client
          .from('apartments')
          .select('id')
          .eq('resident_id', userId)
          .maybeSingle();

      if (aptData != null) {
        final response = await SupabaseService.client
            .from('dues')
            .select()
            .filter('deleted_at', 'is', null) // Soft delete filter
            .eq('apartment_id', aptData['id'])
            .order('month', ascending: false);
        setState(() {
          _dues.clear();
          _dues.addAll(response);
        });
      }
    } catch (e) {
      print('Error fetching my dues: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isModern = Provider.of<ThemeService>(context).isModern;
    return Scaffold(
      body: GradientBackground(
        child: Column(
          children: [
            // Modern header
            Container(
              padding: EdgeInsets.fromLTRB(8, MediaQuery.of(context).padding.top + 8, 16, 16),
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
              child: Row(
                children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                      onPressed: () {
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        } else if (widget.onBack != null) {
                          widget.onBack!();
                        }
                      },
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.myDues,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _fetchMyDues, 
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 22),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _dues.isEmpty
                  ? Center(child: Text(l10n.noDuesFound, style: TextStyle(color: isModern ? Colors.white38 : AppColors.mgmtSecondary)))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      itemCount: _dues.length,
                      itemBuilder: (context, index) {
                        final due = _dues[index];
                        final status = due['status'] ?? (due['is_paid'] == true ? 'paid' : 'unpaid');
                        
                        final dueDateStr = due['due_date'];
                        final DateTime? dueDate = dueDateStr != null ? DateTime.parse(dueDateStr) : null;
                        final bool isOverdue = status == 'unpaid' && dueDate != null && dueDate.isBefore(DateTime.now());

                        final isPaid = status == 'paid';
                        final isPending = status == 'pending';
                        final statusColor = isPaid ? Colors.greenAccent : (isOverdue ? Colors.redAccent : (isPending ? Colors.orangeAccent : Colors.redAccent));

                        return TweenAnimationBuilder<double>(
                          duration: Duration(milliseconds: 400 + (index * 100)),
                          tween: Tween(begin: 0.0, end: 1.0),
                          builder: (context, value, child) {
                            return Transform.translate(
                              offset: Offset(0, 20 * (1 - value)),
                              child: Opacity(opacity: value, child: child),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: GlassCard(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      isPaid 
                                          ? Icons.check_circle_rounded 
                                          : (isOverdue ? Icons.error_rounded : (isPending ? Icons.access_time_filled_rounded : Icons.pending_rounded)),
                                      color: statusColor,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${due['amount']} TL',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold, 
                                            fontSize: 18,
                                            color: isModern ? Colors.white : AppColors.mgmtTextHeading,
                                          ),
                                        ),
                                        Text(
                                          _formatMonth(due['month']),
                                          style: TextStyle(
                                            color: isModern ? Colors.white54 : AppColors.mgmtTextBody, 
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        if (dueDate != null)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4),
                                            child: Text(
                                              'Son Ödeme: ${DateFormat('dd.MM.yyyy').format(dueDate)}',
                                              style: TextStyle(
                                                color: isOverdue ? Colors.redAccent : (isModern ? Colors.white38 : AppColors.mgmtSecondary), 
                                                fontSize: 11,
                                                fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
                                        ),
                                        child: Text(
                                          isPaid 
                                              ? 'ÖDENDİ' 
                                              : (isOverdue ? 'GECİKMEDE' : (isPending ? 'BEKLEMEDE' : 'BORÇ')),
                                          style: TextStyle(
                                            color: statusColor,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                      if (status == 'unpaid')
                                        Padding(
                                          padding: const EdgeInsets.only(top: 8),
                                          child: GlassButton(
                                            width: 70,
                                            height: 32,
                                            padding: EdgeInsets.zero,
                                            onPressed: () => _showPaymentDialog(due),
                                            child: const Text('ÖDE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPaymentDialog(dynamic due) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Ödeme Bilgileri', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Aşağıdaki IBAN adresine transfer yaptıktan sonra "Ödedim" butonuna basın.', 
              style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 20),
            _buildCopyField('IBAN Sahibi', due['iban_holder_name'] ?? 'Sistem Sahibi'),
            const SizedBox(height: 12),
            _buildCopyField('IBAN', due['iban'] ?? 'TR...'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              Navigator.pop(context);
              await _markAsPending(due['id']);
            },
            child: const Text('Ödemeyi Yaptım', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildCopyField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
        Row(
          children: [
            Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 14))),
            IconButton(
              icon: const Icon(Icons.copy, color: Colors.white54, size: 20),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$label kopyalandı')),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _markAsPending(String id) async {
    setState(() => _isLoading = true);
    try {
      await SupabaseService.client
          .from('dues')
          .update({'status': 'pending'})
          .eq('id', id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ödeme bildirimi gönderildi. Yönetici onayı bekleniyor.')),
        );
      }
      _fetchMyDues();
    } catch (e) {
      print('Status update error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _payDue(String id) async {
    // Legacy method, replaced by _markAsPending but kept for compatibility if needed
    await _markAsPending(id);
  }
}
