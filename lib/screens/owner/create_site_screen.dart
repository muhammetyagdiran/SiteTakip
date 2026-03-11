import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:site_takip/l10n/app_localizations.dart';
import '../../services/supabase_service.dart';
import '../../services/auth_service.dart';
import '../../services/theme_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_widgets.dart';
import '../../models/site_model.dart';
import '../../models/user_model.dart';

class CreateSiteScreen extends StatefulWidget {
  final Map<String, dynamic>? site;
  final VoidCallback? onSaved;
  const CreateSiteScreen({super.key, this.onSaved, this.site});

  @override
  State<CreateSiteScreen> createState() => _CreateSiteScreenState();
}

class _CreateSiteScreenState extends State<CreateSiteScreen> {
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  bool _isSaving = false;
  String? _selectedManagerId;
  List<dynamic> _managers = [];
  bool _isLoadingManagers = false;
  SiteType _selectedType = SiteType.site;

  @override
  void initState() {
    super.initState();
    if (widget.site != null) {
      _nameController.text = widget.site!['name'] ?? '';
      _addressController.text = widget.site!['address'] ?? '';
      _selectedManagerId = widget.site!['manager_id'];
      _selectedType = widget.site!['type'] == 'apartment' ? SiteType.apartment : SiteType.site;
    }
    _fetchManagers();
  }

  Future<void> _fetchManagers() async {
    setState(() => _isLoadingManagers = true);
    try {
      final response = await SupabaseService.client
          .from('profiles')
          .select('id, full_name')
          .filter('deleted_at', 'is', null)
          .filter('role', 'in', ['site_manager', 'system_owner']);

      final managers = response as List;
      setState(() {
        _managers = managers;
        if (_selectedManagerId != null) {
          final managerExists = managers.any((m) => m['id'] == _selectedManagerId);
          if (!managerExists) {
            _selectedManagerId = null;
          }
        }
      });
    } catch (e) {
      print('Error fetching managers: $e');
    } finally {
      if (mounted) setState(() => _isLoadingManagers = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _saveSite() async {
    final l10n = AppLocalizations.of(context)!;
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pleaseEnterSiteName)),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;
      final userId = user?.id;
      
      if (userId == null) throw Exception(l10n.sessionNotFound);

      // Manager Restriction: Max 1 site
      if (user?.role == UserRole.siteManager && widget.site == null) {
        final existingSite = await SupabaseService.client
            .from('sites')
            .select('id')
            .or('owner_id.eq.$userId,manager_id.eq.$userId')
            .filter('deleted_at', 'is', null)
            .maybeSingle();
        
        if (existingSite != null) {
          throw Exception(l10n.maxSiteLimitReached);
        }
      }

      final siteData = {
        'name': _nameController.text.trim(),
        'address': _addressController.text.trim(),
        'type': _selectedType == SiteType.apartment ? 'apartment' : 'site',
        'manager_id': _selectedManagerId,
      };

      if (widget.site != null) {
        await SupabaseService.client.from('sites').update(siteData).eq('id', widget.site!['id']);
      } else {
        siteData['owner_id'] = userId;
        // If manager is creating, they are also the manager
        if (user?.role == UserRole.siteManager) {
          siteData['manager_id'] = userId;
        }
        await SupabaseService.client.from('sites').insert(siteData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.siteSavedSuccessfully)),
        );
        if (widget.onSaved != null) {
          widget.onSaved!();
        } else {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      print('Error saving site: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.errorLabel}: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final themeService = Provider.of<ThemeService>(context);
    final isModern = themeService.isModern;
    final authService = Provider.of<AuthService>(context, listen: false);
    final isOwner = authService.currentUser?.role == UserRole.systemOwner;

    final headerGradient = isModern 
        ? const LinearGradient(
            colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : LinearGradient(
            colors: [AppColors.mgmtPrimary, const Color(0xFF0D2B4E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    return Scaffold(
      body: GradientBackground(
        child: Column(
          children: [
            // Modern header
            Container(
              padding: EdgeInsets.fromLTRB(8, MediaQuery.of(context).padding.top + 8, 16, 16),
              decoration: BoxDecoration(
                gradient: headerGradient,
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.site != null ? l10n.editSite : l10n.addSite,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.siteInfo,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isModern ? Colors.white.withOpacity(0.05) : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isModern ? Colors.white.withOpacity(0.08) : Colors.grey.withOpacity(0.12),
                    ),
                    boxShadow: isModern ? null : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTextFieldLabel(l10n.siteNameLabel, isModern),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _nameController,
                        style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading),
                        decoration: _buildInputDecoration(
                          l10n.siteNameHint, 
                          Icons.business_rounded, 
                          isModern
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      _buildTextFieldLabel(l10n.siteTypeLabel, isModern),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTypeChoiceCard(
                              l10n.siteOption, 
                              Icons.location_city_rounded,
                              _selectedType == SiteType.site, 
                              () => setState(() => _selectedType = SiteType.site),
                              isModern,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTypeChoiceCard(
                              l10n.apartmentOption, 
                              Icons.domain_rounded,
                              _selectedType == SiteType.apartment, 
                              () => setState(() => _selectedType = SiteType.apartment),
                              isModern,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      _buildTextFieldLabel(l10n.addressLabel, isModern),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _addressController,
                        style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading),
                        maxLines: 3,
                        decoration: _buildInputDecoration(
                          l10n.addressHint, 
                          Icons.location_on_rounded, 
                          isModern
                        ).copyWith(alignLabelWithHint: true),
                      ),
                      
                      if (isOwner) ...[
                        const SizedBox(height: 20),
                        _buildTextFieldLabel(l10n.selectManager, isModern),
                        const SizedBox(height: 8),
                        _isLoadingManagers
                          ? const Center(child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(),
                            ))
                          : DropdownButtonFormField<String>(
                              value: _selectedManagerId,
                              dropdownColor: isModern ? const Color(0xFF1E293B) : Colors.white,
                              style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading),
                              decoration: _buildInputDecoration(
                                null, 
                                Icons.person_pin_rounded, 
                                isModern
                              ).copyWith(contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
                              icon: Icon(Icons.keyboard_arrow_down_rounded, color: isModern ? Colors.white54 : AppColors.mgmtTextBody),
                              items: [
                                DropdownMenuItem(value: null, child: Text(l10n.noManager)),
                                ..._managers.map((m) => DropdownMenuItem(
                                  value: m['id'] as String,
                                  child: Text(m['full_name'] ?? l10n.unknown),
                                )),
                              ],
                              onChanged: (val) => setState(() => _selectedManagerId = val),
                            ),
                      ],
                      const SizedBox(height: 32),
                      
                      if (_isSaving)
                        const Center(child: CircularProgressIndicator())
                      else
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _saveSite,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isModern ? AppColors.primary : AppColors.mgmtPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 2,
                            ),
                            child: Text(
                              widget.site != null ? l10n.saveSite : l10n.addSite,
                              style: const TextStyle(
                                fontSize: 16, 
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
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

  Widget _buildTextFieldLabel(String text, bool isModern) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: isModern ? Colors.white70 : AppColors.mgmtTextHeading.withOpacity(0.8),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String? hint, IconData icon, bool isModern) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: isModern ? Colors.white30 : AppColors.mgmtTextBody.withOpacity(0.5)),
      prefixIcon: Icon(icon, color: isModern ? Colors.white54 : AppColors.mgmtPrimary.withOpacity(0.7)),
      filled: true,
      fillColor: isModern ? Colors.black.withOpacity(0.2) : Colors.grey.withOpacity(0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: isModern ? AppColors.primary : AppColors.mgmtPrimary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _buildTypeChoiceCard(String label, IconData icon, bool isSelected, VoidCallback onTap, bool isModern) {
    final activeColor = isModern ? AppColors.primary : AppColors.mgmtPrimary;
    final inactiveColor = isModern ? Colors.white12 : Colors.grey.withOpacity(0.1);
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withOpacity(0.15) : inactiveColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? activeColor : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon, 
              color: isSelected ? activeColor : (isModern ? Colors.white54 : AppColors.mgmtTextBody),
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected 
                    ? (isModern ? Colors.white : AppColors.mgmtTextHeading)
                    : (isModern ? Colors.white54 : AppColors.mgmtTextBody),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
