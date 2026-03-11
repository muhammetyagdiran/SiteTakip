import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../services/supabase_service.dart';
import '../../services/auth_service.dart';
import '../../services/theme_service.dart';
import '../../models/survey_model.dart';
import '../../models/user_model.dart';
import '../../theme/app_theme.dart';
import 'package:site_takip/l10n/app_localizations.dart';

/// Web-optimized Survey Management screen for the Owner/Manager Dashboard.
class WebSurveyManagementScreen extends StatefulWidget {
  final String? siteId;
  final VoidCallback? onBack;
  const WebSurveyManagementScreen({super.key, this.siteId, this.onBack});

  @override
  State<WebSurveyManagementScreen> createState() => _WebSurveyManagementScreenState();
}

class _WebSurveyManagementScreenState extends State<WebSurveyManagementScreen> {
  List<Survey> _surveys = [];
  List<Map<String, dynamic>> _mySites = [];
  bool _isLoading = true;
  String? _selectedSiteId;
  Timer? _countdownTimer;

  // Filter: 'all', 'active', 'past'
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _selectedSiteId = widget.siteId;
    _initScreen();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _initScreen() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.currentUser?.role == UserRole.systemOwner) {
      await _fetchMySites();
    }
    await _fetchSurveys();
  }

  Future<void> _fetchMySites() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final response = await SupabaseService.client
          .from('sites')
          .select('id, name')
          .eq('owner_id', authService.currentUser!.id)
          .filter('deleted_at', 'is', null);
      
      if (mounted) {
        setState(() {
          _mySites = List<Map<String, dynamic>>.from(response as List);
        });
      }
    } catch (e) {
      debugPrint('Error fetching sites: $e');
    }
  }

  Future<void> _fetchSurveys() async {
    setState(() => _isLoading = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;
      
      var query = SupabaseService.client
          .from('surveys')
          .select('*, survey_options(*), sites(name)');

      if (_selectedSiteId != null) {
        query = query.eq('site_id', _selectedSiteId as String);
      } else if (user?.role == UserRole.systemOwner) {
        final siteIds = _mySites.map((s) => s['id'] as String).toList();
        if (siteIds.isNotEmpty) {
          query = query.inFilter('site_id', siteIds);
        } else {
          setState(() {
            _surveys = [];
            _isLoading = false;
          });
          return;
        }
      }

      final response = await query
          .order('is_closed', ascending: true)
          .order('created_at', ascending: false);
      
      final List<Survey> loaded = (response as List).map((s) {
        final options = (s['survey_options'] as List)
            .map((o) => SurveyOption.fromMap(o))
            .toList();
        return Survey.fromMap(s, options);
      }).toList();

      if (mounted) {
        setState(() {
          _surveys = loaded;
        });
      }
    } catch (e) {
      debugPrint('Error fetching surveys: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _closeSurvey(String surveyId) async {
    try {
      await SupabaseService.client
          .from('surveys')
          .update({'is_closed': true})
          .eq('id', surveyId);
      _fetchSurveys();
    } catch (e) {
      debugPrint('Error closing survey: $e');
    }
  }

  // ──── Calculated Stats ────

  int get _totalSurveys => _surveys.length;
  int get _activeCount => _surveys.where((s) => s.isActive).length;
  int get _pastCount => _surveys.where((s) => !s.isActive).length;

  List<Survey> get _filteredSurveys {
    if (_statusFilter == 'active') return _surveys.where((s) => s.isActive).toList();
    if (_statusFilter == 'past') return _surveys.where((s) => !s.isActive).toList();
    return _surveys;
  }

  // ──── Creation Dialog ────

  Future<void> _showCreateDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final isModern = Provider.of<ThemeService>(context, listen: false).isModern;
    final textColor = isModern ? Colors.white : AppColors.mgmtTextHeading;
    final subtextColor = isModern ? Colors.white70 : AppColors.mgmtTextBody;
    final primaryColor = isModern ? const Color(0xFF3B82F6) : AppColors.mgmtPrimary;

    final titleController = TextEditingController();
    final descController = TextEditingController();
    final List<TextEditingController> optionControllers = [
      TextEditingController(),
      TextEditingController(),
    ];
    String? selectedSiteIdForNew = _selectedSiteId;
    DateTime? expiresAt;
    TimeOfDay? expiresTime;
    String? errorMessage;
    bool isSubmitting = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) {
          return AlertDialog(
            backgroundColor: isModern ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.poll_rounded, color: primaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Yeni Anket Oluştur', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    Text('Katılımcılar için yeni bir anket yayınlayın', style: TextStyle(fontSize: 12, color: subtextColor, fontWeight: FontWeight.normal)),
                  ],
                ),
              ),
              IconButton(onPressed: () => Navigator.pop(ctx), icon: Icon(Icons.close, color: subtextColor, size: 20)),
            ]),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_mySites.isNotEmpty)
                      _buildDialogDropdown<String?>(
                        value: selectedSiteIdForNew,
                        label: 'Site',
                        icon: Icons.business_outlined,
                        isModern: isModern,
                        textColor: textColor,
                        subtextColor: subtextColor,
                        primaryColor: primaryColor,
                        items: _mySites.map((s) => DropdownMenuItem(value: s['id'] as String, child: Text(s['name'] ?? '', style: TextStyle(fontSize: 14, color: textColor)))).toList(),
                        onChanged: isSubmitting ? null : (val) => setDState(() => selectedSiteIdForNew = val),
                      ),
                    const SizedBox(height: 14),
                    _buildDialogField(
                      controller: titleController,
                      label: l10n.surveyTitle,
                      icon: Icons.title_rounded,
                      isModern: isModern,
                      textColor: textColor,
                      subtextColor: subtextColor,
                      primaryColor: primaryColor,
                      enabled: !isSubmitting,
                    ),
                    const SizedBox(height: 14),
                    _buildDialogField(
                      controller: descController,
                      label: l10n.descriptionLabel,
                      icon: Icons.description_outlined,
                      isModern: isModern,
                      textColor: textColor,
                      subtextColor: subtextColor,
                      primaryColor: primaryColor,
                      enabled: !isSubmitting,
                    ),
                    const SizedBox(height: 14),
                    // Date & Time Picker
                    InkWell(
                      onTap: isSubmitting ? null : () async {
                        final date = await showDatePicker(
                          context: ctx,
                          initialDate: DateTime.now().add(const Duration(days: 7)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          final time = await showTimePicker(
                            context: ctx,
                            initialTime: const TimeOfDay(hour: 23, minute: 59),
                          );
                          setDState(() {
                            expiresAt = date;
                            expiresTime = time ?? const TimeOfDay(hour: 23, minute: 59);
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isModern ? Colors.black.withOpacity(0.2) : Colors.grey.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.event_available_rounded, size: 18, color: primaryColor),
                            const SizedBox(width: 12),
                            Text(
                              expiresAt != null
                                  ? '${DateFormat('dd/MM/yyyy').format(expiresAt!)} ${expiresTime!.format(ctx)}'
                                  : 'Bitiş Tarihi Seçin *',
                              style: TextStyle(color: expiresAt != null ? textColor : subtextColor, fontSize: 14),
                            ),
                            const Spacer(),
                            Icon(Icons.calendar_month_rounded, size: 18, color: subtextColor),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Text(l10n.optionsLabel, style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: isSubmitting ? null : () => setDState(() => optionControllers.add(TextEditingController())),
                          icon: const Icon(Icons.add_circle_outline, size: 16),
                          label: Text(l10n.addOption, style: const TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...optionControllers.asMap().entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildDialogField(
                                controller: entry.value,
                                label: '${entry.key + 1}. Seçenek',
                                icon: Icons.radio_button_checked_rounded,
                                isModern: isModern,
                                textColor: textColor,
                                subtextColor: subtextColor,
                                primaryColor: primaryColor,
                                enabled: !isSubmitting,
                              ),
                            ),
                            if (optionControllers.length > 2)
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                onPressed: isSubmitting ? null : () => setDState(() => optionControllers.removeAt(entry.key)),
                              ),
                          ],
                        ),
                      );
                    }),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel, style: TextStyle(color: subtextColor))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: isSubmitting ? null : () async {
                  if (titleController.text.trim().isEmpty || optionControllers.any((c) => c.text.trim().isEmpty) || selectedSiteIdForNew == null || expiresAt == null) {
                    setDState(() => errorMessage = 'Lütfen tüm alanları doldurun.');
                    return;
                  }
                  setDState(() => isSubmitting = true);
                  try {
                    final expTime = expiresTime ?? const TimeOfDay(hour: 23, minute: 59);
                    final expiresDateTime = DateTime(expiresAt!.year, expiresAt!.month, expiresAt!.day, expTime.hour, expTime.minute);
                    
                    final surveyRes = await SupabaseService.client.from('surveys').insert({
                      'site_id': selectedSiteIdForNew,
                      'title': titleController.text.trim(),
                      'description': descController.text.trim(),
                      'expires_at': expiresDateTime.toUtc().toIso8601String(),
                    }).select().single();
                    
                    final surveyId = surveyRes['id'];
                    final options = optionControllers.map((c) => { 'survey_id': surveyId, 'text': c.text.trim() }).toList();
                    await SupabaseService.client.from('survey_options').insert(options);
                    
                    if (mounted) Navigator.pop(ctx);
                    _fetchSurveys();
                  } catch (e) {
                    setDState(() => errorMessage = 'Hata: $e');
                  } finally {
                    setDState(() => isSubmitting = false);
                  }
                },
                child: Text(isSubmitting ? '...' : l10n.save, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  // ──── Reusable Dialog Widgets ────

  Widget _buildDialogField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool enabled = true,
    required bool isModern,
    required Color textColor,
    required Color subtextColor,
    required Color primaryColor,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      style: TextStyle(color: textColor, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: subtextColor, fontSize: 13),
        prefixIcon: Icon(icon, color: primaryColor, size: 20),
        filled: true,
        fillColor: isModern ? Colors.black.withOpacity(0.2) : Colors.grey.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildDialogDropdown<T>({
    required T value,
    required String label,
    required IconData icon,
    required List<DropdownMenuItem<T>> items,
    required Function(T?)? onChanged,
    required bool isModern,
    required Color textColor,
    required Color subtextColor,
    required Color primaryColor,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      dropdownColor: isModern ? const Color(0xFF1E293B) : Colors.white,
      style: TextStyle(color: textColor, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: subtextColor, fontSize: 13),
        prefixIcon: Icon(icon, color: primaryColor, size: 20),
        filled: true,
        fillColor: isModern ? Colors.black.withOpacity(0.2) : Colors.grey.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  // ──── Build ────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isModern = Provider.of<ThemeService>(context).isModern;
    final textColor = isModern ? Colors.white : Colors.black87;
    final subtextColor = isModern ? Colors.white54 : Colors.black54;
    final primaryColor = isModern ? const Color(0xFF3B82F6) : AppColors.mgmtPrimary;
    final cardBg = isModern ? const Color(0xFF1E293B) : Colors.white;

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
                      Text(l10n.surveys, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: textColor)),
                      const SizedBox(height: 4),
                      Text('Anketlerinizi yönetin ve sonuçları takip edin.', style: TextStyle(color: subtextColor, fontSize: 16)),
                    ],
                  ),
                ),
                if (_mySites.isNotEmpty) ...[
                  SizedBox(
                    width: 180,
                    child: _buildHeaderDropdown<String?>(
                      value: _selectedSiteId,
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Tüm Siteler')),
                        ..._mySites.map((s) => DropdownMenuItem(value: s['id'] as String, child: Text(s['name'] ?? ''))),
                      ],
                      onChanged: (val) {
                        setState(() => _selectedSiteId = val);
                        _fetchSurveys();
                      },
                      isModern: isModern,
                      cardBg: cardBg,
                      textColor: textColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                IconButton(
                  onPressed: _fetchSurveys,
                  icon: const Icon(Icons.refresh),
                  color: subtextColor,
                  tooltip: 'Yenile',
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _showCreateDialog,
                  icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                  label: const Text('Anket Oluştur', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    minimumSize: const Size(0, 44),
                  ),
                ),
              ],
            ),
          ),

          // ──── Summary Cards (Filters) ────
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
            child: Row(
              children: [
                _buildStatCard('Toplam Anket', '$_totalSurveys', Icons.poll_outlined, primaryColor, isModern, cardBg, textColor, subtextColor, filterKey: 'all'),
                const SizedBox(width: 16),
                _buildStatCard('Aktif Anketler', '$_activeCount', Icons.bolt_rounded, Colors.greenAccent, isModern, cardBg, textColor, subtextColor, filterKey: 'active'),
                const SizedBox(width: 16),
                _buildStatCard('Geçmiş Anketler', '$_pastCount', Icons.history_rounded, Colors.orangeAccent, isModern, cardBg, textColor, subtextColor, filterKey: 'past'),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ──── Survey List ────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredSurveys.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 64, color: subtextColor),
                            const SizedBox(height: 16),
                            Text('Anket bulunamadı.', style: TextStyle(fontSize: 16, color: subtextColor)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
                        itemCount: _filteredSurveys.length,
                        itemBuilder: (context, index) {
                          final s = _filteredSurveys[index];
                          return _buildSurveyItem(s, isModern, textColor, subtextColor, cardBg, primaryColor);
                        },
                      ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSurveyItem(Survey s, bool isModern, Color textColor, Color subtextColor, Color cardBg, Color primaryColor) {
    final totalVotes = s.options.fold<int>(0, (sum, opt) => sum + opt.voteCount);
    final remaining = s.expiresAt != null ? s.expiresAt!.difference(DateTime.now()) : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isModern ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06)),
      ),
      child: ExpansionTile(
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        tilePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textColor)),
                  if (s.siteName != null)
                    Text(s.siteName!, style: TextStyle(fontSize: 12, color: subtextColor.withOpacity(0.7))),
                ],
              ),
            ),
            _buildStatusBadge(s),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Row(
            children: [
              _buildInfoBadge(Icons.people_outline_rounded, '$totalVotes Oy', subtextColor),
              const SizedBox(width: 16),
              if (remaining != null && s.isActive)
                _buildInfoBadge(
                  Icons.timer_outlined,
                  _formatCountdown(remaining),
                  remaining.inHours < 1 ? Colors.redAccent : Colors.orangeAccent,
                ),
            ],
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (s.description != null && s.description!.isNotEmpty) ...[
                  Text(s.description!, style: TextStyle(color: subtextColor, fontSize: 14)),
                  const SizedBox(height: 20),
                ],
                const Text('Sonuçlar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 12),
                ...s.options.map((o) {
                  final percentage = totalVotes > 0 ? (o.voteCount / totalVotes) : 0.0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(o.text, style: TextStyle(fontSize: 14, color: textColor)),
                            Text('${o.voteCount} (${(percentage * 100).toStringAsFixed(0)}%)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: subtextColor)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: percentage,
                            minHeight: 8,
                            backgroundColor: isModern ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1),
                            valueColor: AlwaysStoppedAnimation<Color>(primaryColor.withOpacity(0.6)),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                if (s.isActive) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _closeSurvey(s.id),
                      icon: const Icon(Icons.lock_clock_rounded, size: 16),
                      label: const Text('Anketü Kapat', style: TextStyle(fontSize: 13)),
                      style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(Survey s) {
    String text; Color color;
    if (s.isClosed) { text = 'KAPALI'; color = Colors.redAccent;
    } else if (s.isExpired) { text = 'SÜRESİ DOLDU'; color = Colors.orangeAccent;
    } else { text = 'AKTİF'; color = Colors.greenAccent; }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.3))),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
    );
  }

  Widget _buildInfoBadge(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, bool isModern, Color cardBg, Color textColor, Color subtextColor, {required String filterKey}) {
    final isSelected = _statusFilter == filterKey;

    return Expanded(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => setState(() => _statusFilter = filterKey),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? color.withOpacity(0.6) : (isModern ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06)),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.1), blurRadius: 15, spreadRadius: 0)] : null,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: textColor)),
                    Text(label, style: TextStyle(fontSize: 13, color: subtextColor)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderDropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required Function(T?)? onChanged,
    required bool isModern,
    required Color cardBg,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isModern ? Colors.white10 : AppColors.mgmtBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          dropdownColor: isModern ? const Color(0xFF1E293B) : Colors.white,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
          style: TextStyle(color: textColor, fontSize: 13),
        ),
      ),
    );
  }

  String _formatCountdown(Duration d) {
    if (d.isNegative) return 'Süresi doldu';
    final days = d.inDays;
    final hours = d.inHours % 24;
    final minutes = d.inMinutes % 60;
    if (days > 0) return '${days}g ${hours}s';
    if (hours > 0) return '${hours}s ${minutes}dk';
    return '${minutes}dk';
  }
}
