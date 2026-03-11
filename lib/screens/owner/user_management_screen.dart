import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';
import '../../services/auth_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/glass_widgets.dart';
import '../../theme/app_theme.dart';
import 'package:site_takip/l10n/app_localizations.dart';

class UserManagementScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const UserManagementScreen({super.key, this.onBack});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final List<dynamic> _users = [];
  List<dynamic> _sites = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSites();
    _fetchUsers();
  }

  Future<void> _fetchSites() async {
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
        setState(() {
          _sites = response as List;
        });
      }
    } catch (e) {
      print('Error fetching sites for user management: $e');
    }
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final ownerId = authService.currentUser?.id;
      if (ownerId == null) return;

      // 1. Get IDs of all sites owned by this user
      final sitesResponse = await SupabaseService.client
          .from('sites')
          .select('id')
          .eq('owner_id', ownerId)
          .filter('deleted_at', 'is', null);
      
      final siteIds = (sitesResponse as List).map((s) => s['id'] as String).toList();

      // 2. Build query
      var query = SupabaseService.client
          .from('profiles')
          .select()
          .filter('deleted_at', 'is', null);

      if (siteIds.isNotEmpty) {
        // Show users created by owner OR associated with owner's sites
        final siteIdsStr = siteIds.map((id) => '"$id"').join(',');
        query = query.or('created_by.eq.$ownerId,site_id.in.($siteIdsStr)');
      } else {
        query = query.eq('created_by', ownerId);
      }

      final response = await query.order('full_name');

      if (mounted) {
        setState(() {
          _users.clear();
          _users.addAll(response as List);
        });
      }
    } catch (e) {
      print('Error fetching users: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    final l10n = AppLocalizations.of(context)!;
    final themeService = Provider.of<ThemeService>(context, listen: false);
    final isModern = themeService.isModern;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isModern ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text(l10n.deleteUser, style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading)),
        content: Text(l10n.deleteUserPrompt, style: TextStyle(color: isModern ? Colors.white70 : AppColors.mgmtTextBody)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel, style: TextStyle(color: isModern ? Colors.white70 : AppColors.mgmtTextBody)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    final authService = Provider.of<AuthService>(context, listen: false);
    if (user['id'] == authService.currentUser?.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.errorLabel}: ${l10n.cannotDeleteSelf}')),
      );
      return;
    }

    if (confirmed == true) {
      try {
        await SupabaseService.client
            .from('profiles')
            .update({'deleted_at': DateTime.now().toIso8601String()})
            .eq('id', user['id']);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.userUpdatedSuccessfully)),
        );
        _fetchUsers();
      } catch (e) {
        final l10n = AppLocalizations.of(context)!;
        print('Error deleting user: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${l10n.errorLabel}: $e')),
          );
        }
      }
    }
  }

  Future<void> _addUser() async {
    // This would typically involve Supabase Auth and then profile creation.
    // Simplifying for now: show a dialog or navigated to a specialized form.
    _showUserForm();
  }

  Future<void> _showUserForm({Map<String, dynamic>? user}) async {
    final l10n = AppLocalizations.of(context)!;
    final themeService = Provider.of<ThemeService>(context, listen: false);
    final isModern = themeService.isModern;

    final nameController = TextEditingController(text: user?['full_name']);
    final emailController = TextEditingController(text: user?['email']);
    final passwordController = TextEditingController();
    String selectedRole = user?['role'] ?? 'resident';
    String? selectedSiteId = user?['site_id'];
    String? selectedBlockId;
    String? selectedApartmentId;
    List<dynamic> localBlocks = [];
    List<dynamic> localApartments = [];
    bool isLoadingDependent = false;
    bool isEditing = user != null;
    bool isSubmitting = false;
    String? errorMessage;

    if (isEditing && selectedRole == 'resident') {
      try {
        final aptResponse = await SupabaseService.client
            .from('apartments')
            .select('id, number, block_id')
            .eq('resident_id', user['id'])
            .filter('deleted_at', 'is', null)
            .maybeSingle();

        if (aptResponse != null) {
          selectedApartmentId = aptResponse['id'];
          selectedBlockId = aptResponse['block_id'];

          if (selectedSiteId != null) {
            final blocksRes = await SupabaseService.client
                .from('blocks')
                .select('id, name')
                .eq('site_id', selectedSiteId as Object)
                .filter('deleted_at', 'is', null);
            localBlocks = blocksRes as List;
          }

          if (selectedBlockId != null) {
            final aptsRes = await SupabaseService.client
                .from('apartments')
                .select('id, number')
                .eq('block_id', selectedBlockId as Object)
                .filter('deleted_at', 'is', null)
                .order('number');
            localApartments = aptsRes as List;
          }
        }
      } catch (e) {
        print('Error pre-fetching user details: $e');
      }
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: false, // Prevents closing on scroll
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
                              isEditing ? l10n.editUser : l10n.addUser,
                              style: TextStyle(
                                color: isModern ? Colors.white : AppColors.mgmtTextHeading,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              isEditing ? 'Bilgileri güncelle' : 'Yeni kullanıcı tanımla',
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
                          child: Icon(Icons.close_rounded, 
                            color: isModern ? Colors.white70 : AppColors.mgmtTextBody, 
                            size: 20
                          ),
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
                          const SizedBox(height: 16),
                          _buildGlassInput(
                            controller: emailController,
                            label: l10n.emailLabel,
                            icon: Icons.email_outlined,
                            enabled: !isSubmitting,
                            readOnly: isEditing, // Use readOnly instead of disabling to keep UI consistent
                            isModern: isModern,
                          ),
                          if (!isEditing) ...[
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
                        const SizedBox(height: 20),
                        _buildGlassDropdown<String>(
                          value: selectedRole,
                          label: l10n.selectRole,
                          icon: Icons.shield_outlined,
                          isModern: isModern,
                          items: [
                            DropdownMenuItem(value: 'system_owner', child: Text(l10n.systemOwner, style: const TextStyle(fontSize: 14))),
                            DropdownMenuItem(value: 'site_manager', child: Text(l10n.siteManagerRole, style: const TextStyle(fontSize: 14))),
                            DropdownMenuItem(value: 'resident', child: Text(l10n.residentRole, style: const TextStyle(fontSize: 14))),
                          ],
                          onChanged: isSubmitting ? null : (val) {
                            if (val != null) setModalState(() => selectedRole = val);
                          },
                        ),
                        if (selectedRole != 'system_owner') ...[
                          const SizedBox(height: 16),
                          _buildGlassDropdown<String?>(
                            value: selectedSiteId,
                            label: l10n.sites,
                            icon: Icons.business_outlined,
                            isModern: isModern,
                            items: [
                              DropdownMenuItem(value: null, child: Text(l10n.noAssignedSite, style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis)),
                              ..._sites.map((site) => DropdownMenuItem(
                                    value: site['id'] as String,
                                    child: Text(site['name'] ?? '', style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis),
                                  )),
                            ],
                            onChanged: isSubmitting ? null : (val) async {
                              setModalState(() {
                                selectedSiteId = val;
                                selectedBlockId = null;
                                selectedApartmentId = null;
                                localBlocks = [];
                                localApartments = [];
                              });
                              if (val != null) {
                                setModalState(() => isLoadingDependent = true);
                                try {
                                  final blocksRes = await SupabaseService.client.from('blocks').select('id, name').eq('site_id', val).filter('deleted_at', 'is', null);
                                  setModalState(() => localBlocks = blocksRes as List);
                                } finally {
                                  setModalState(() => isLoadingDependent = false);
                                }
                              }
                            },
                          ),
                        ],
                        if (selectedRole == 'resident' && selectedSiteId != null) ...[
                          const SizedBox(height: 16),
                          if (isLoadingDependent)
                            const LinearProgressIndicator(minHeight: 2)
                          else
                            _buildGlassDropdown<String?>(
                              value: selectedBlockId,
                              label: 'Blok Seçin',
                              icon: Icons.domain_outlined,
                              isModern: isModern,
                              items: [
                                const DropdownMenuItem(value: null, child: Text('Blok Seçilmedi')),
                                ...localBlocks.map((b) => DropdownMenuItem(value: b['id'] as String, child: Text(b['name'] ?? ''))),
                              ],
                              onChanged: isSubmitting ? null : (val) async {
                                setModalState(() {
                                  selectedBlockId = val;
                                  selectedApartmentId = null;
                                  localApartments = [];
                                });
                                if (val != null) {
                                  setModalState(() => isLoadingDependent = true);
                                  try {
                                    final aptsRes = await SupabaseService.client.from('apartments').select('id, number').eq('block_id', val).filter('deleted_at', 'is', null).order('number');
                                    setModalState(() => localApartments = aptsRes as List);
                                  } finally {
                                    setModalState(() => isLoadingDependent = false);
                                  }
                                }
                              },
                            ),
                          const SizedBox(height: 16),
                          _buildGlassDropdown<String?>(
                            value: selectedApartmentId,
                            label: 'Daire Seçin',
                            icon: Icons.door_front_door_outlined,
                            isModern: isModern,
                            items: [
                              const DropdownMenuItem(value: null, child: Text('Daire Seçilmedi')),
                              ...localApartments.map((a) => DropdownMenuItem(value: a['id'] as String, child: Text('Daire ${a['number']}'))),
                            ],
                            onChanged: isSubmitting ? null : (val) {
                              setModalState(() => selectedApartmentId = val);
                            },
                          ),
                        ],
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
                              
                              if (selectedRole != 'system_owner' && selectedSiteId == null) {
                                setModalState(() => errorMessage = 'Lütfen bir Site seçin.');
                                return;
                              }

                              if (selectedRole == 'resident' && selectedApartmentId == null) {
                                setModalState(() => errorMessage = 'Lütfen bir Daire seçin.');
                                return;
                              }

                              setModalState(() => isSubmitting = true);
                              try {
                                if (isEditing) {
                                  await SupabaseService.client.from('profiles').update({
                                    'full_name': nameController.text,
                                    'role': selectedRole,
                                    'site_id': selectedSiteId,
                                  }).eq('id', user['id']);

                                  if (selectedRole == 'site_manager' && selectedSiteId != null) {
                                    await SupabaseService.client.from('sites').update({
                                      'manager_id': user['id']
                                    }).eq('id', selectedSiteId as Object);
                                  }

                                  if (selectedRole == 'resident' && selectedApartmentId != null) {
                                    await SupabaseService.client.from('apartments').update({'resident_id': null}).eq('resident_id', user['id']);
                                    await SupabaseService.client.from('apartments').update({'resident_id': user['id']}).eq('id', selectedApartmentId as Object);
                                  }

                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.userUpdatedSuccessfully)));
                                } else {
                                  final authService = Provider.of<AuthService>(context, listen: false);
                                  final ownerId = authService.currentUser?.id;
                                  if (ownerId == null) throw Exception(l10n.sessionNotFound);

                                  final separateClient = SupabaseClient(
                                    SupabaseService.url,
                                    SupabaseService.anonKey,
                                    authOptions: const AuthClientOptions(
                                      authFlowType: AuthFlowType.implicit,
                                      autoRefreshToken: false,
                                    ),
                                  );

                                  final authResponse = await separateClient.auth.signUp(
                                    email: emailController.text,
                                    password: passwordController.text,
                                    data: {'full_name': nameController.text},
                                  );

                                  if (authResponse.user != null) {
                                    final newUserId = authResponse.user!.id;
                                    await SupabaseService.client.from('profiles').upsert({
                                      'id': newUserId,
                                      'full_name': nameController.text,
                                      'email': emailController.text,
                                      'role': selectedRole,
                                      'site_id': selectedSiteId,
                                      'created_by': ownerId,
                                    });

                                    if (selectedRole == 'site_manager' && selectedSiteId != null) {
                                      await SupabaseService.client.from('sites').update({
                                        'manager_id': newUserId
                                      }).eq('id', selectedSiteId as Object);
                                    }

                                    if (selectedRole == 'resident' && selectedApartmentId != null) {
                                      await SupabaseService.client.from('apartments').update({
                                        'resident_id': newUserId
                                      }).eq('id', selectedApartmentId as Object);
                                    }
                                  }

                                  separateClient.dispose();
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.userCreatedSuccessfully)));
                                }
                                if (mounted) Navigator.pop(context);
                                _fetchUsers();
                              } catch (e) {
                                print('User creation error: $e');
                                String errorMsg = e.toString();
                                if (errorMsg.contains('User already registered') || errorMsg.contains('already exists')) {
                                  errorMsg = "Bu e-posta adresi ile zaten bir kullanıcı kayıtlı.";
                                } else if (errorMsg.contains('over_email_send_rate_limit')) {
                                  errorMsg = "E-posta gönderim limiti aşıldı. Lütfen bir süre bekleyin.";
                                } else if (errorMsg.contains('weak_password')) {
                                  errorMsg = "Şifre çok zayıf. Lütfen daha güçlü bir şifre deneyin.";
                                } else if (errorMsg.startsWith('Exception: ')) {
                                  errorMsg = errorMsg.replaceFirst('Exception: ', '');
                                }
                                setModalState(() => errorMessage = 'Hata: $errorMsg');
                              } finally {
                                if (mounted) setModalState(() => isSubmitting = false);
                              }
                            },
                            child: Text(
                              isEditing ? l10n.update : l10n.save,
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
                            ),
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
                        const SizedBox(height: 20),
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
    bool readOnly = false,
    bool isPassword = false,
    required bool isModern,
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
        style: TextStyle(
          color: isModern 
            ? (readOnly ? Colors.white.withOpacity(0.7) : Colors.white) 
            : (readOnly ? AppColors.mgmtTextHeading.withOpacity(0.7) : AppColors.mgmtTextHeading), 
          fontSize: 15
        ),
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
        dropdownColor: isModern ? const Color(0xFF1E293B) : Colors.white,
        isExpanded: true, // Crucial for layout
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final themeService = Provider.of<ThemeService>(context);
    final isModern = themeService.isModern;

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
                      l10n.userManagement,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _fetchUsers, 
                    icon: const Icon(Icons.refresh, color: Colors.white70, size: 22),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _users.isEmpty
                      ? Center(child: Text(l10n.noUsersFound, style: TextStyle(
                          color: isModern ? Colors.white70 : AppColors.mgmtTextBody,
                        )))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _users.length,
                          itemBuilder: (context, index) {
                            final user = _users[index];
                            final role = user['role'];
                            IconData roleIcon;
                            Color roleColor;

                            switch (role) {
                              case 'system_owner':
                                roleIcon = Icons.admin_panel_settings;
                                roleColor = isModern ? Colors.purpleAccent : AppColors.mgmtPrimary;
                                break;
                              case 'site_manager':
                                roleIcon = Icons.manage_accounts;
                                roleColor = isModern ? AppColors.secondary : AppColors.mgmtAccent;
                                break;
                              default:
                                roleIcon = Icons.person;
                                roleColor = isModern ? AppColors.primary : AppColors.mgmtSecondary;
                            }

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: GlassCard(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: ListTile(
                                    leading: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: roleColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: roleColor.withOpacity(0.2), width: 1),
                                      ),
                                      child: Icon(roleIcon, color: roleColor, size: 24),
                                    ),
                                    title: Text(user['full_name'] ?? 'No Name', style: TextStyle(
                                      color: isModern ? Colors.white : AppColors.mgmtTextHeading,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    )),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: roleColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          role.toString().toUpperCase().replaceAll('_', ' '),
                                          style: TextStyle(
                                            color: roleColor.withOpacity(0.8),
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: Icon(Icons.edit_outlined, color: isModern ? Colors.white60 : AppColors.mgmtAccent, size: 20),
                                          onPressed: () => _showUserForm(user: user),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                          onPressed: () => _deleteUser(user),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ],
                                    ),
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
        padding: const EdgeInsets.only(bottom: 95),
        child: FloatingActionButton.extended(
          onPressed: _addUser,
          label: Text(l10n.addUser, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          icon: const Icon(Icons.person_add_rounded, color: Colors.white, size: 24),
          backgroundColor: isModern ? AppColors.primary : AppColors.mgmtPrimary,
          elevation: 12,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
