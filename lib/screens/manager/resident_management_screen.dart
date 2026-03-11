import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/supabase_service.dart';
import '../../services/auth_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/glass_widgets.dart';
import '../../theme/app_theme.dart';
import 'package:site_takip/l10n/app_localizations.dart';

class ResidentManagementScreen extends StatefulWidget {
  final String? siteId;
  final VoidCallback? onBack;
  const ResidentManagementScreen({super.key, this.siteId, this.onBack});

  @override
  State<ResidentManagementScreen> createState() => _ResidentManagementScreenState();
}

class _ResidentManagementScreenState extends State<ResidentManagementScreen> {
  final List<dynamic> _residents = [];
  List<dynamic> _blocks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchResidents();
    _fetchBlocks();
  }

  Future<void> _fetchBlocks() async {
    if (widget.siteId == null) return;
    try {
      final response = await SupabaseService.client
          .from('blocks')
          .select('id, name, apartments(id, number, resident_id)')
          .eq('site_id', widget.siteId as String);
      setState(() => _blocks = response as List);
    } catch (e) {
      print('Error fetching blocks: $e');
    }
  }

  Future<void> _fetchResidents() async {
    setState(() => _isLoading = true);
    try {
      if (widget.siteId == null) {
        setState(() => _isLoading = false);
        return;
      }
      
      // Fetch residents with their apartments and block names, filtered by siteId
      final dynamic query = SupabaseService.client
          .from('profiles')
          .select('*, apartments!inner(id, number, blocks!inner(id, name, site_id))')
          .eq('role', 'resident')
          .filter('deleted_at', 'is', null) // Soft delete filter
          .eq('apartments.blocks.site_id', widget.siteId as String);
      
      final response = await query;
      
      setState(() {
        _residents.clear();
        _residents.addAll(response);
      });
    } catch (e) {
      print('Error fetching residents: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showResidentForm({Map<String, dynamic>? resident}) {
    final l10n = AppLocalizations.of(context)!;
    final isModern = Provider.of<ThemeService>(context, listen: false).isModern;
    final nameController = TextEditingController(text: resident?['full_name']);
    final emailController = TextEditingController(text: resident?['email'] ?? '');
    final phoneController = TextEditingController(text: resident?['phone_number']);
    final passwordController = TextEditingController();
    
    String? selectedBlockId;
    String? selectedApartmentId;
    List<dynamic> currentApartments = [];

    // If editing, find current apartment
    if (resident != null && resident['apartments'] != null && (resident['apartments'] as List).isNotEmpty) {
      final apt = resident['apartments'][0];
      selectedApartmentId = apt['id'];
      // Find block id for this apartment
      for (var block in _blocks) {
        if ((block['apartments'] as List).any((a) => a['id'] == selectedApartmentId)) {
          selectedBlockId = block['id'];
          currentApartments = block['apartments'];
          break;
        }
      }
    }

    bool isEditing = resident != null;
    bool isSubmitting = false;
    String? errorMessage;

    showModalBottomSheet(
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
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: Column(
              children: [
                // Premium Modal Header
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 12, 16, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 24,
                        decoration: BoxDecoration(
                          color: isModern ? AppColors.primary : AppColors.mgmtAccent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEditing ? 'Sakini Düzenle' : 'Yeni Sakin Ekle',
                              style: TextStyle(
                                color: isModern ? Colors.white : AppColors.mgmtTextHeading,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              isEditing ? 'Sakin bilgilerini güncelle' : 'Yeni sakin tanımla',
                              style: TextStyle(
                                color: isModern ? Colors.white.withOpacity(0.5) : AppColors.mgmtTextBody,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isModern ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.close_rounded, color: isModern ? Colors.white70 : AppColors.mgmtTextBody, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: isModern ? Colors.white10 : Colors.grey.withOpacity(0.2)),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.only(
                      left: 24,
                      right: 24,
                      top: 24,
                      bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                    ),
                    child: Column(
                      children: [
                        _buildGlassInput(
                          controller: nameController,
                          label: l10n.fullNameLabel,
                          icon: Icons.person_outline,
                          enabled: !isSubmitting,
                          isModern: isModern,
                        ),
                        if (!isEditing) ...[
                          const SizedBox(height: 16),
                          _buildGlassInput(
                            controller: emailController,
                            label: l10n.emailLabel,
                            icon: Icons.email_outlined,
                            enabled: !isSubmitting,
                            isModern: isModern,
                          ),
                          const SizedBox(height: 16),
                          _buildGlassInput(
                            controller: passwordController,
                            label: l10n.passwordLabel,
                            icon: Icons.lock_outline,
                            enabled: !isSubmitting,
                            isPassword: true,
                            isModern: isModern,
                          ),
                        ],
                        if (isEditing && emailController.text.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _buildGlassInput(
                            controller: emailController,
                            label: l10n.emailLabel,
                            icon: Icons.email_outlined,
                            enabled: true,
                            readOnly: true,
                            isModern: isModern,
                          ),
                        ],
                        const SizedBox(height: 16),
                        _buildGlassInput(
                          controller: phoneController,
                          label: 'Telefon Numarası',
                          icon: Icons.phone_outlined,
                          enabled: !isSubmitting,
                          isModern: isModern,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 20),
                        
                        _buildGlassDropdown<String?>(
                          value: selectedBlockId,
                          label: 'Blok Seçin',
                          icon: Icons.domain_outlined,
                          isModern: isModern,
                          items: _blocks.map((b) => DropdownMenuItem(
                            value: b['id'] as String,
                            child: Text(b['name'] as String, style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis),
                          )).toList(),
                          onChanged: isSubmitting ? null : (val) {
                            setModalState(() {
                              selectedBlockId = val;
                              selectedApartmentId = null;
                              currentApartments = _blocks.firstWhere((b) => b['id'] == val)['apartments'] as List;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        _buildGlassDropdown<String?>(
                          value: selectedApartmentId,
                          label: 'Daire Seçin',
                          icon: Icons.door_front_door_outlined,
                          isModern: isModern,
                          items: currentApartments.map((a) => DropdownMenuItem(
                            value: a['id'] as String,
                            child: Text('No: ${a['number']} ${a['resident_id'] != null && a['resident_id'] != resident?['id'] ? "(Dolu)" : ""}', 
                              style: const TextStyle(fontSize: 14), 
                              overflow: TextOverflow.ellipsis
                            ),
                          )).toList(),
                          onChanged: isSubmitting ? null : (val) => setModalState(() => selectedApartmentId = val),
                        ),
                        
                        const SizedBox(height: 32),
                        if (isSubmitting)
                          const CircularProgressIndicator()
                        else
                          GlassButton(
                            onPressed: () async {
                              setModalState(() => errorMessage = null);
                              
                              // Form Validation
                              if (nameController.text.trim().isEmpty) {
                                setModalState(() => errorMessage = 'Lütfen Ad Soyad alanını doldurun.');
                                return;
                              }
                              
                              if (!isEditing) {
                                if (emailController.text.trim().isEmpty) {
                                  setModalState(() => errorMessage = 'Lütfen E-posta alanını doldurun.');
                                  return;
                                }
                                if (passwordController.text.isEmpty) {
                                  setModalState(() => errorMessage = 'Lütfen bir Şifre belirleyin.');
                                  return;
                                }
                                if (passwordController.text.length < 6) {
                                  setModalState(() => errorMessage = 'Şifre en az 6 karakter olmalıdır.');
                                  return;
                                }
                              }

                              if (selectedApartmentId == null) {
                                setModalState(() => errorMessage = 'Lütfen bir Blok ve Daire seçin.');
                                return;
                              }

                              setModalState(() => isSubmitting = true);
                              try {
                                String? targetResidentId = resident?['id'];

                                if (isEditing) {
                                  await SupabaseService.client.from('profiles').update({
                                    'full_name': nameController.text.trim(),
                                    'phone_number': phoneController.text.trim(),
                                    'site_id': widget.siteId,
                                  }).eq('id', targetResidentId!);
                                } else {
                                  final authResponse = await SupabaseService.client.auth.signUp(
                                    email: emailController.text.trim(),
                                    password: passwordController.text,
                                    data: {'full_name': nameController.text.trim()},
                                  );
                                  
                                  if (authResponse.user != null) {
                                    final authService = Provider.of<AuthService>(context, listen: false);
                                    final currentUserId = authService.currentUser?.id;
                                    targetResidentId = authResponse.user!.id;
                                    await SupabaseService.client.from('profiles').upsert({
                                      'id': targetResidentId,
                                      'full_name': nameController.text.trim(),
                                      'phone_number': phoneController.text.trim(),
                                      'role': 'resident',
                                      'site_id': widget.siteId,
                                      'created_by': currentUserId,
                                    });
                                  }
                                }

                                // Link to Apartment
                                if (targetResidentId != null) {
                                  await SupabaseService.client.from('apartments').update({
                                    'resident_id': targetResidentId,
                                  }).eq('id', selectedApartmentId!);
                                }

                                if (mounted) Navigator.pop(context);
                                _fetchResidents();
                                _fetchBlocks();
                              } catch (e) {
                                print('Resident creation error: $e');
                                String errorMsg = e.toString();
                                if (errorMsg.contains('already registered')) errorMsg = 'E-posta zaten kayıtlı.';
                                setModalState(() => errorMessage = 'Hata: $errorMsg');
                              } finally {
                                if (mounted) setModalState(() => isSubmitting = false);
                              }
                            },
                            child: Text(l10n.save, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                          ),
                        if (errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    errorMessage!,
                                    style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
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

  Widget _buildGlassInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool enabled = true,
    bool isPassword = false,
    bool readOnly = false,
    required bool isModern,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isModern ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isModern ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.2)),
      ),
      child: TextField(
        controller: controller,
        enabled: enabled,
        readOnly: readOnly,
        obscureText: isPassword,
        keyboardType: keyboardType,
        style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading, fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: isModern ? Colors.white.withOpacity(0.5) : AppColors.mgmtTextBody, fontSize: 14),
          prefixIcon: Icon(icon, color: isModern ? AppColors.primary : AppColors.mgmtAccent, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildGlassDropdown<T>({
    required T value,
    required String label,
    required IconData icon,
    required List<DropdownMenuItem<T>> items,
    required Function(T?)? onChanged,
    required bool isModern,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isModern ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isModern ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.2)),
      ),
      child: DropdownButtonFormField<T>(
        value: value,
        dropdownColor: isModern ? const Color(0xFF1E1E1E) : Colors.white,
        isExpanded: true,
        items: items,
        onChanged: onChanged,
        icon: Icon(Icons.keyboard_arrow_down_rounded, color: isModern ? Colors.white54 : AppColors.mgmtTextBody),
        style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading, fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: isModern ? Colors.white.withOpacity(0.5) : AppColors.mgmtTextBody, fontSize: 14),
          prefixIcon: Icon(icon, color: isModern ? AppColors.primary : AppColors.mgmtAccent, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        ),
      ),
    );
  }

  Future<void> _deleteResident(dynamic resident) async {
    final isModern = Provider.of<ThemeService>(context, listen: false).isModern;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isModern ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text('Sakini Sil', style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading)),
        content: Text('Bu sakini silmek istediğinize emin misiniz? Daire ataması da kaldırılacaktır.', 
          style: TextStyle(color: isModern ? Colors.white70 : AppColors.mgmtTextBody)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), 
            child: Text('İptal', style: TextStyle(color: isModern ? Colors.white54 : AppColors.mgmtTextBody))
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Sil', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Soft delete: update deleted_at
        await SupabaseService.client
            .from('profiles')
            .update({'deleted_at': DateTime.now().toIso8601String()})
            .eq('id', resident['id']);
            
        // Also remove resident from apartment
        await SupabaseService.client
            .from('apartments')
            .update({'resident_id': null})
            .eq('resident_id', resident['id']);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sakin başarıyla silindi.')),
          );
          _fetchResidents();
          _fetchBlocks();
        }
      } catch (e) {
        print('Delete resident error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Silme hatası: $e')));
        }
      }
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
              padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 12, 12, 16),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.residents,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_residents.length} sakin kayıtlı',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _fetchResidents,
                    icon: const Icon(Icons.refresh, color: Colors.white70, size: 24),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _residents.isEmpty
                      ? Center(child: Text(l10n.noResidentsFound, style: TextStyle(color: isModern ? Colors.white70 : AppColors.mgmtTextBody)))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _residents.length,
                          itemBuilder: (context, index) {
                            final res = _residents[index];
                            final apts = res['apartments'] as List?;
                            String aptInfo = 'Daire atanmamış';
                            if (apts != null && apts.isNotEmpty) {
                              final apt = apts[0];
                              final blockName = apt['blocks']?['name'] ?? 'Blok?';
                              aptInfo = '$blockName, No: ${apt['number']}';
                            }

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: GlassCard(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                onTap: () => _showResidentForm(resident: res),
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(
                                    backgroundColor: AppColors.primary.withOpacity(0.2),
                                    child: const Icon(Icons.person, color: AppColors.primary),
                                  ),
                                  title: Text(
                                    res['full_name'] ?? l10n.anonymousResident,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isModern ? Colors.white : AppColors.mgmtTextHeading,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(aptInfo, style: TextStyle(color: isModern ? Colors.white60 : AppColors.mgmtTextBody, fontSize: 12)),
                                      if (res['phone_number'] != null)
                                        Text(res['phone_number'], style: TextStyle(color: isModern ? Colors.white54 : AppColors.mgmtTextBody, fontSize: 11)),
                                    ],
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                    onPressed: () => _deleteResident(res),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 90),
        child: FloatingActionButton.extended(
          onPressed: () => _showResidentForm(),
          label: const Text('Yeni Sakin Ekle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 24),
          backgroundColor: isModern ? AppColors.primary : AppColors.mgmtPrimary,
          elevation: 12,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
