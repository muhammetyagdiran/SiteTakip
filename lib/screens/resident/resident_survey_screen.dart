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
import '../../models/survey_model.dart';

class ResidentSurveyScreen extends StatefulWidget {
  final String? siteId;
  final VoidCallback? onBack;
  const ResidentSurveyScreen({super.key, this.siteId, this.onBack});

  @override
  State<ResidentSurveyScreen> createState() => _ResidentSurveyScreenState();
}

class _ResidentSurveyScreenState extends State<ResidentSurveyScreen> {
  List<Survey> _surveys = [];
  bool _isLoading = true;
  final Map<String, String?> _userVotes = {}; // surveyId -> optionId
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _fetchSurveysAndVotes();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchSurveysAndVotes() async {
    if (widget.siteId == null) return;
    setState(() => _isLoading = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUser?.id;

      final surveyResponse = await SupabaseService.client
          .from('surveys')
          .select('*, survey_options(*), sites(name)')
          .eq('site_id', widget.siteId as String)
          .order('created_at', ascending: false);
      
      final surveys = (surveyResponse as List).map((s) {
        final options = (s['survey_options'] as List)
            .map((o) => SurveyOption.fromMap(o))
            .toList();
        return Survey.fromMap(s, options);
      }).toList();

      if (userId != null) {
        final votesResponse = await SupabaseService.client
            .from('survey_responses')
            .select('survey_id, option_id')
            .eq('resident_id', userId);
        
        _userVotes.clear();
        for (var v in (votesResponse as List)) {
          _userVotes[v['survey_id']] = v['option_id'];
        }
      }

      setState(() => _surveys = surveys);
    } catch (e) {
      print('Error fetching surveys: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _castOrChangeVote(String surveyId, String optionId) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUser?.id;
    if (userId == null) return;

    try {
      final existing = await SupabaseService.client
          .from('survey_responses')
          .select('id, option_id')
          .eq('survey_id', surveyId)
          .eq('resident_id', userId)
          .maybeSingle();
      
      if (existing != null) {
        await SupabaseService.client
            .from('survey_responses')
            .delete()
            .eq('id', existing['id']);
      }
      
      await SupabaseService.client.from('survey_responses').insert({
        'survey_id': surveyId,
        'option_id': optionId,
        'resident_id': userId,
      });
      
      setState(() => _userVotes[surveyId] = optionId);
      await _fetchSurveysAndVotes();
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n.errorLabel}: $e')));
      }
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
                      if (widget.onBack != null) {
                        widget.onBack!();
                      } else if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.surveys,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _fetchSurveysAndVotes,
                    icon: const Icon(Icons.refresh, color: Colors.white70, size: 22),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _surveys.isEmpty
                      ? Center(child: Text(l10n.noSurveysFound, style: TextStyle(color: isModern ? Colors.white70 : AppColors.mgmtTextBody)))
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                          children: [
                            if (_surveys.any((s) => s.isActive)) ...[
                              Text(l10n.activeSurveys, style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading, fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 12),
                              ..._surveys.where((s) => s.isActive).map((s) => _buildSurveyCard(s, isModern)),
                            ],
                            if (_surveys.any((s) => !s.isActive)) ...[
                              const SizedBox(height: 24),
                              Text(l10n.pastSurveys, style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading, fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 12),
                              ..._surveys.where((s) => !s.isActive).map((s) => _buildSurveyCard(s, isModern)),
                            ],
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSurveyCard(Survey s, bool isModern) {
    final votedOptionId = _userVotes[s.id];
    final hasVoted = votedOptionId != null;
    final remaining = s.expiresAt != null ? s.expiresAt!.difference(DateTime.now()) : null;
    final totalVotes = s.options.fold<int>(0, (sum, opt) => sum + opt.voteCount);

    final headingColor = isModern ? Colors.white : AppColors.mgmtTextHeading;
    final bodyColor = isModern ? Colors.white70 : AppColors.mgmtTextBody;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(s.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: headingColor))),
                const SizedBox(width: 8),
                _buildStatusBadge(s),
              ],
            ),
            if (s.description != null && s.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(s.description!, style: TextStyle(color: bodyColor, fontSize: 14)),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _buildInfoItem(Icons.calendar_today_rounded, 'Açılış: ${DateFormat('dd/MM/yyyy HH:mm').format(s.createdAt)}', isModern),
                if (totalVotes > 0)
                  _buildInfoItem(Icons.people_outline_rounded, '$totalVotes Oy', isModern),
              ],
            ),
            if (remaining != null && s.isActive) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: (remaining.inHours < 1 ? Colors.redAccent : Colors.orangeAccent).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: (remaining.inHours < 1 ? Colors.redAccent : Colors.orangeAccent).withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.timer_outlined, size: 14, color: remaining.inHours < 1 ? Colors.redAccent : Colors.orangeAccent),
                    const SizedBox(width: 6),
                    Text(
                      'Kalan: ${_formatCountdown(remaining)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: remaining.inHours < 1 ? Colors.redAccent : Colors.orangeAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            ...s.options.map((o) {
              final isSelected = votedOptionId == o.id;
              final percentage = totalVotes > 0 ? (o.voteCount / totalVotes) : 0.0;
              final canVote = s.isActive;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: InkWell(
                  onTap: canVote ? () => _castOrChangeVote(s.id, o.id) : null,
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? AppColors.primary.withOpacity(0.15) 
                          : (isModern ? Colors.white.withOpacity(0.03) : Colors.grey.withOpacity(0.05)),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected 
                            ? AppColors.primary 
                            : (isModern ? Colors.white10 : Colors.grey.withOpacity(0.2)),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (isSelected)
                              const Padding(
                                padding: EdgeInsets.only(right: 10),
                                child: Icon(Icons.check_circle_rounded, size: 18, color: AppColors.primary),
                              ),
                            Expanded(child: Text(o.text, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, color: headingColor, fontSize: 14))),
                            Text('${o.voteCount} (${(percentage * 100).toStringAsFixed(0)}%)', style: TextStyle(fontSize: 12, color: isSelected ? headingColor : bodyColor, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: percentage,
                            minHeight: 6,
                            backgroundColor: isModern ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1),
                            valueColor: AlwaysStoppedAnimation<Color>(isSelected ? AppColors.primary : (isModern ? Colors.white24 : Colors.grey.withOpacity(0.3))),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(Survey s) {
    String text;
    Color color;
    if (s.isClosed) {
      text = 'KAPALI';
      color = Colors.redAccent;
    } else if (s.isExpired) {
      text = 'SÜRESİ DOLDU';
      color = Colors.orangeAccent;
    } else {
      text = 'AKTİF';
      color = Colors.greenAccent;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text, bool isModern) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: isModern ? AppColors.primary : AppColors.mgmtAccent),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(fontSize: 12, color: isModern ? Colors.white : AppColors.mgmtTextHeading, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
