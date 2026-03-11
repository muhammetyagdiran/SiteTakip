import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../services/auth_service.dart';
import '../../services/theme_service.dart';
import 'package:provider/provider.dart';
import '../../widgets/glass_widgets.dart';
import '../../theme/app_theme.dart';
import 'package:site_takip/l10n/app_localizations.dart';

class CreateRequestScreen extends StatefulWidget {
  final VoidCallback? onSaved;
  const CreateRequestScreen({super.key, this.onSaved});

  @override
  State<CreateRequestScreen> createState() => _CreateRequestScreenState();
}

class _CreateRequestScreenState extends State<CreateRequestScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isSaving = false;

  Future<void> _saveRequest() async {
    if (_titleController.text.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUser?.id;
      if (userId == null) throw Exception(AppLocalizations.of(context)!.sessionNotFound);

      final aptData = await SupabaseService.client
          .from('apartments')
          .select('id')
          .eq('resident_id', userId)
          .maybeSingle();

      await SupabaseService.client.from('requests').insert({
        'title': _titleController.text,
        'description': _descriptionController.text,
        'resident_id': userId,
        'apartment_id': aptData?['id'],
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Talebiniz başarıyla oluşturuldu.')),
        );
        if (widget.onSaved != null) widget.onSaved!();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)!.error}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: GradientBackground(
        child: Column(
          children: [
            // Modern header
            Container(
              padding: EdgeInsets.fromLTRB(8, MediaQuery.of(context).padding.top + 8, 16, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: Provider.of<ThemeService>(context, listen: false).isModern 
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
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.newRequest,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.newRequest,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.requestDescription,
                        style: const TextStyle(color: AppColors.textBody),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _titleController,
                        style: TextStyle(color: Provider.of<ThemeService>(context, listen: false).isModern ? Colors.white : AppColors.mgmtTextHeading),
                        decoration: InputDecoration(
                          labelText: l10n.requestTitleLabel,
                          hintText: l10n.requestTitleHint,
                          labelStyle: TextStyle(color: Provider.of<ThemeService>(context, listen: false).isModern ? Colors.white70 : AppColors.mgmtTextBody),
                          hintStyle: TextStyle(color: Provider.of<ThemeService>(context, listen: false).isModern ? Colors.white30 : AppColors.mgmtTextBody.withOpacity(0.5)),
                          prefixIcon: Icon(Icons.title_rounded, color: Provider.of<ThemeService>(context, listen: false).isModern ? Colors.white54 : AppColors.mgmtPrimary.withOpacity(0.7)),
                          filled: true,
                          fillColor: Provider.of<ThemeService>(context, listen: false).isModern ? Colors.black.withOpacity(0.2) : Colors.grey.withOpacity(0.05),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _descriptionController,
                        maxLines: 4,
                        style: TextStyle(color: Provider.of<ThemeService>(context, listen: false).isModern ? Colors.white : AppColors.mgmtTextHeading),
                        decoration: InputDecoration(
                          labelText: l10n.descriptionLabel,
                          hintText: l10n.descriptionHint,
                          labelStyle: TextStyle(color: Provider.of<ThemeService>(context, listen: false).isModern ? Colors.white70 : AppColors.mgmtTextBody),
                          hintStyle: TextStyle(color: Provider.of<ThemeService>(context, listen: false).isModern ? Colors.white30 : AppColors.mgmtTextBody.withOpacity(0.5)),
                          alignLabelWithHint: true,
                          prefixIcon: Padding(
                            padding: const EdgeInsets.only(bottom: 60), // Align icon with top of multiline textfield
                            child: Icon(Icons.description_rounded, color: Provider.of<ThemeService>(context, listen: false).isModern ? Colors.white54 : AppColors.mgmtPrimary.withOpacity(0.7)),
                          ),
                          filled: true,
                          fillColor: Provider.of<ThemeService>(context, listen: false).isModern ? Colors.black.withOpacity(0.2) : Colors.grey.withOpacity(0.05),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 32),
                      if (_isSaving)
                        const Center(child: CircularProgressIndicator())
                      else
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _saveRequest,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Provider.of<ThemeService>(context, listen: false).isModern ? AppColors.primary : AppColors.mgmtPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 2,
                            ),
                            child: Text(l10n.sendRequest, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                        ),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
