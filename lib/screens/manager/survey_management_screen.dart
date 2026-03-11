import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/supabase_service.dart';
import '../../services/auth_service.dart';
import '../../services/theme_service.dart';
import 'package:provider/provider.dart';
import '../../widgets/glass_widgets.dart';
import '../../theme/app_theme.dart';
import 'package:site_takip/l10n/app_localizations.dart';
import '../../models/user_model.dart';
import '../../models/survey_model.dart';

class SurveyManagementScreen extends StatefulWidget {
  final String? siteId;
  final VoidCallback? onBack;
  const SurveyManagementScreen({super.key, this.siteId, this.onBack});

  @override
  State<SurveyManagementScreen> createState() => _SurveyManagementScreenState();
}

class _SurveyManagementScreenState extends State<SurveyManagementScreen> {
  List<Survey> _surveys = [];
  bool _isLoading = true;
  String? _selectedSiteId;
  List<dynamic> _mySites = [];
  Timer? _countdownTimer;

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
    if (authService.currentUser?.role == UserRole.systemOwner && widget.siteId == null) {
      await _fetchMySites();
    }
    _fetchSurveys();
  }

  Future<void> _fetchMySites() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final ownerId = authService.currentUser?.id;
      if (ownerId == null) return;

      final response = await SupabaseService.client
          .from('sites')
          .select('id, name')
          .eq('owner_id', ownerId)
          .filter('deleted_at', 'is', null);
      
      if (mounted) {
        setState(() => _mySites = response as List);
      }
    } catch (e) {
      print('Error fetching my sites: $e');
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
        } else if (widget.siteId == null) {
          setState(() {
            _surveys = [];
            _isLoading = false;
          });
          return;
        }
      } else if (widget.siteId != null) {
        query = query.eq('site_id', widget.siteId as String);
      } else {
        setState(() => _isLoading = false);
        return;
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

      setState(() => _surveys = loaded);
    } catch (e) {
      print('Error fetching surveys: $e');
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
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n.errorLabel}: $e')));
    }
  }

  String _formatCountdown(Duration d) {
    if (d.isNegative) return 'Süresi doldu';
    final days = d.inDays;
    final hours = d.inHours % 24;
    final minutes = d.inMinutes % 60;
    final seconds = d.inSeconds % 60;
    if (days > 0) return '${days}g ${hours}s ${minutes}dk ${seconds}sn';
    if (hours > 0) return '${hours}s ${minutes}dk ${seconds}sn';
    return '${minutes}dk ${seconds}sn';
  }

  Future<void> _addSurvey() async {
    final l10n = AppLocalizations.of(context)!;
    final themeService = Provider.of<ThemeService>(context, listen: false);
    final isModern = themeService.isModern;
    final authService = Provider.of<AuthService>(context, listen: false);

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

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: BoxDecoration(
              color: isModern ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(32),
                topRight: Radius.circular(32),
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 12, 16, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 4, height: 24,
                        decoration: BoxDecoration(
                          color: isModern ? AppColors.primary : AppColors.mgmtAccent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.createNewSurvey,
                          style: TextStyle(
                            color: isModern ? Colors.white : AppColors.mgmtTextHeading,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: isModern ? Colors.white10 : Colors.grey.withOpacity(0.2)),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                      left: 24, right: 24, top: 24,
                      bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                    ),
                    child: Column(
                      children: [
                        _buildGlassInput(
                          controller: titleController,
                          label: l10n.surveyTitle,
                          icon: Icons.title_rounded,
                          isModern: isModern,
                        ),
                        const SizedBox(height: 16),
                        _buildGlassInput(
                          controller: descController,
                          label: '${l10n.descriptionLabel} ${l10n.optionalHint}',
                          icon: Icons.description_outlined,
                          isModern: isModern,
                        ),
                        const SizedBox(height: 16),
                        if (authService.currentUser?.role == UserRole.systemOwner && _selectedSiteId == null && widget.siteId == null) ...[
                          Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: isModern ? Colors.white.withOpacity(0.08) : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: isModern ? Colors.white10 : AppColors.mgmtBorder),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String?>(
                                value: selectedSiteIdForNew,
                                dropdownColor: isModern ? const Color(0xFF1E293B) : Colors.white,
                                isExpanded: true,
                                icon: Icon(Icons.keyboard_arrow_down_rounded, color: isModern ? Colors.white54 : AppColors.mgmtPrimary),
                                hint: Row(
                                  children: [
                                    Icon(Icons.business_rounded, size: 18, color: isModern ? Colors.white54 : AppColors.mgmtPrimary.withOpacity(0.7)),
                                    const SizedBox(width: 8),
                                    Text('Site Seçin', style: TextStyle(color: isModern ? Colors.white70 : AppColors.mgmtTextBody, fontSize: 14)),
                                  ],
                                ),
                                style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading, fontSize: 14, fontWeight: FontWeight.w500),
                                items: _mySites.map((s) => DropdownMenuItem<String?>(
                                  value: s['id'] as String?, 
                                  child: Text(s['name'] ?? '', style: TextStyle(fontSize: 14, color: isModern ? Colors.white : AppColors.mgmtTextHeading))
                                )).toList(),
                                onChanged: (val) => setModalState(() => selectedSiteIdForNew = val),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        GestureDetector(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now().add(const Duration(days: 7)),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                              builder: (context, child) => _buildDateTimePickerTheme(context, child, isModern),
                            );
                            if (date != null) {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: const TimeOfDay(hour: 23, minute: 59),
                                builder: (context, child) => _buildDateTimePickerTheme(context, child, isModern),
                              );
                              setModalState(() {
                                expiresAt = date;
                                expiresTime = time ?? const TimeOfDay(hour: 23, minute: 59);
                              });
                            }
                          },
                          child: GlassCard(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                Icon(Icons.event_available_rounded, size: 20, color: isModern ? AppColors.primary : AppColors.mgmtAccent),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    expiresAt != null
                                        ? '${DateFormat('dd MMMM yyyy', 'tr').format(expiresAt!)} - ${expiresTime!.format(context)}'
                                        : 'Bitiş Tarihi Seçin *',
                                    style: TextStyle(
                                      color: isModern ? Colors.white : AppColors.mgmtTextHeading,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Text(l10n.optionsLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: () => setModalState(() => optionControllers.add(TextEditingController())),
                              icon: const Icon(Icons.add_circle_outline, size: 18),
                              label: Text(l10n.addOption),
                            ),
                          ],
                        ),
                        ...optionControllers.asMap().entries.map((entry) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 12.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildGlassInput(
                                    controller: entry.value,
                                    label: '${entry.key + 1}. Seçenek',
                                    icon: Icons.radio_button_checked_rounded,
                                    isModern: isModern,
                                  ),
                                ),
                                if (optionControllers.length > 2)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                                    onPressed: () => setModalState(() => optionControllers.removeAt(entry.key)),
                                  ),
                              ],
                            ),
                          );
                        }),
                        if (errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Text(errorMessage!, style: const TextStyle(color: Colors.redAccent)),
                        ],
                        const SizedBox(height: 32),
                        if (isSubmitting)
                          const CircularProgressIndicator()
                        else
                          GlassButton(
                            onPressed: () async {
                              final finalSiteId = selectedSiteIdForNew ?? _selectedSiteId ?? widget.siteId;
                              if (titleController.text.trim().isEmpty || optionControllers.any((c) => c.text.trim().isEmpty) || finalSiteId == null || expiresAt == null) {
                                setModalState(() => errorMessage = 'Lütfen tüm alanları doldurun.');
                                return;
                              }
                              setModalState(() { isSubmitting = true; errorMessage = null; });
                              try {
                                final expTime = expiresTime ?? const TimeOfDay(hour: 23, minute: 59);
                                final expiresDateTime = DateTime(expiresAt!.year, expiresAt!.month, expiresAt!.day, expTime.hour, expTime.minute);
                                final surveyRes = await SupabaseService.client.from('surveys').insert({
                                  'site_id': finalSiteId,
                                  'title': titleController.text.trim(),
                                  'description': descController.text.trim(),
                                  'expires_at': expiresDateTime.toUtc().toIso8601String(),
                                }).select().single();
                                final surveyId = surveyRes['id'];
                                final options = optionControllers.map((c) => { 'survey_id': surveyId, 'text': c.text.trim() }).toList();
                                await SupabaseService.client.from('survey_options').insert(options);
                                Navigator.pop(context);
                                _fetchSurveys();
                              } catch (e) {
                                setModalState(() => errorMessage = 'Hata: $e');
                              } finally {
                                setModalState(() => isSubmitting = false);
                              }
                            },
                            child: Text(l10n.publishSurvey, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                      ],
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isModern = Provider.of<ThemeService>(context).isModern;
    final isOwner = Provider.of<AuthService>(context, listen: false).currentUser?.role == UserRole.systemOwner;
    return Scaffold(
      body: GradientBackground(
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.fromLTRB(8, MediaQuery.of(context).padding.top + 8, 16, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isModern 
                      ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                      : [AppColors.mgmtPrimary, const Color(0xFF0D2B4E)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                    onPressed: () {
                      if (widget.onBack != null) {
                        widget.onBack!();
                      } else if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(l10n.surveys, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(onPressed: _fetchSurveys, icon: const Icon(Icons.refresh, color: Colors.white)),
                ],
              ),
            ),
            if (isOwner && widget.siteId == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: isModern ? Colors.white.withOpacity(0.08) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isModern ? Colors.white10 : AppColors.mgmtBorder),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: _selectedSiteId,
                      dropdownColor: isModern ? const Color(0xFF1E293B) : Colors.white,
                      isExpanded: true,
                      icon: Icon(Icons.keyboard_arrow_down_rounded, color: isModern ? Colors.white54 : AppColors.mgmtPrimary),
                      hint: Row(
                        children: [
                          Icon(Icons.business_rounded, size: 18, color: isModern ? Colors.white54 : AppColors.mgmtPrimary.withOpacity(0.7)),
                          const SizedBox(width: 8),
                          Text('Tüm Siteler', style: TextStyle(color: isModern ? Colors.white70 : AppColors.mgmtTextBody, fontSize: 14)),
                        ],
                      ),
                      style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading, fontSize: 14, fontWeight: FontWeight.w500),
                      items: [
                        DropdownMenuItem(value: null, child: Text('Tüm Siteler', style: TextStyle(fontSize: 14, color: isModern ? Colors.white : AppColors.mgmtTextHeading))),
                        ..._mySites.map((s) => DropdownMenuItem(value: s['id'] as String, child: Text(s['name'] ?? '', style: TextStyle(fontSize: 14, color: isModern ? Colors.white : AppColors.mgmtTextHeading)))),
                      ],
                      onChanged: (val) {
                        setState(() => _selectedSiteId = val);
                        _fetchSurveys();
                      },
                    ),
                  ),
                ),
              ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _surveys.isEmpty
                      ? Center(child: Text(l10n.noSurveysFound, style: TextStyle(color: isModern ? Colors.white70 : AppColors.mgmtTextBody)))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                          itemCount: _surveys.length,
                          itemBuilder: (context, index) => _buildSurveyCard(_surveys[index], l10n, isOwner),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 100),
        child: FloatingActionButton.extended(
          onPressed: _addSurvey,
          label: const Text('Yeni Anket Oluştur', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          icon: const Icon(Icons.add, color: Colors.white),
          backgroundColor: isModern ? AppColors.primary : AppColors.mgmtPrimary,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildSurveyCard(Survey s, AppLocalizations l10n, bool isOwner) {
    final isModern = Provider.of<ThemeService>(context, listen: false).isModern;
    final totalVotes = s.options.fold<int>(0, (sum, opt) => sum + opt.voteCount);
    final remaining = s.expiresAt != null ? s.expiresAt!.difference(DateTime.now()) : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(0),
        child: ExpansionTile(
          title: Text(s.title, style: TextStyle(fontWeight: FontWeight.bold, color: isModern ? Colors.white : AppColors.mgmtTextHeading)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (s.siteName != null) 
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(s.siteName!, style: TextStyle(fontSize: 13, color: isModern ? Colors.white70 : AppColors.mgmtTextBody, fontWeight: FontWeight.w500)),
                ),
              const SizedBox(height: 4),
              _buildInfoItem(Icons.people_outline_rounded, '$totalVotes Oy', isModern),
              if (remaining != null && s.isActive)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Kalan: ${_formatCountdown(remaining)}', style: const TextStyle(fontSize: 12, color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          trailing: _buildStatusBadge(s),
          children: [
             ...s.options.map((o) {
              final percentage = totalVotes > 0 ? (o.voteCount / totalVotes) : 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(o.text, style: TextStyle(fontSize: 14, color: isModern ? Colors.white : AppColors.mgmtTextHeading))),
                        Text('${o.voteCount} (${(percentage * 100).toStringAsFixed(0)}%)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isModern ? Colors.white70 : AppColors.mgmtTextBody)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: percentage, 
                      backgroundColor: isModern ? Colors.white10 : Colors.grey[200],
                      color: isModern ? AppColors.primary : AppColors.mgmtAccent,
                    ),
                  ],
                ),
              );
            }).toList(),
            if (s.isActive)
              TextButton.icon(
                onPressed: () => _closeSurvey(s.id),
                icon: const Icon(Icons.lock_clock_rounded, size: 18),
                label: Text(l10n.closeSurvey),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(Survey s) {
    String text; Color color;
    if (s.isClosed) { text = 'KAPALI'; color = Colors.redAccent;
    } else if (s.isExpired) { text = 'SÜRESİ DOLDU'; color = Colors.orangeAccent;
    } else { text = 'AKTİF'; color = Colors.greenAccent; }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withOpacity(0.3))),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildInfoItem(IconData icon, String text, bool isModern) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: isModern ? AppColors.primary : AppColors.mgmtAccent),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(fontSize: 12, color: isModern ? Colors.white60 : AppColors.mgmtTextBody.withOpacity(0.7), fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildGlassInput({required TextEditingController controller, required String label, required IconData icon, required bool isModern}) {
    return Container(
      decoration: BoxDecoration(color: isModern ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: isModern ? Colors.white10 : Colors.grey.withOpacity(0.1))),
      child: TextField(
        controller: controller,
        style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading),
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 20), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
      ),
    );
  }

  Widget _buildGlassDropdown<T>({required T? value, required String label, required IconData icon, required bool isModern, required List<DropdownMenuItem<T>> items, required ValueChanged<T?> onChanged}) {
    return Container(
      decoration: BoxDecoration(
        color: isModern ? Colors.white.withOpacity(0.08) : Colors.grey.withOpacity(0.05), 
        borderRadius: BorderRadius.circular(16), 
        border: Border.all(color: isModern ? Colors.white24 : Colors.grey.withOpacity(0.2))
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<T>(
          value: value, items: items, onChanged: onChanged,
          dropdownColor: isModern ? const Color(0xFF1E293B) : Colors.white,
          decoration: InputDecoration(
            labelText: label, 
            labelStyle: TextStyle(color: isModern ? Colors.white70 : Colors.grey[700], fontSize: 13),
            prefixIcon: Icon(icon, size: 20, color: isModern ? AppColors.primary : AppColors.mgmtAccent), 
            border: InputBorder.none,
            filled: false,
          ),
          style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildDateTimePickerTheme(BuildContext context, Widget? child, bool isModern) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: isModern ? ColorScheme.dark(primary: AppColors.primary, surface: const Color(0xFF1E293B)) : ColorScheme.light(primary: AppColors.mgmtAccent, surface: Colors.white),
      ),
      child: child!,
    );
  }
}
