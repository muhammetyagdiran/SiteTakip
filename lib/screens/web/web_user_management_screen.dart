import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';
import '../../services/auth_service.dart';
import '../../services/theme_service.dart';
import '../../models/user_model.dart';
import '../../theme/app_theme.dart';
import 'package:site_takip/l10n/app_localizations.dart';

/// Web-optimized User Management screen for the Owner Dashboard.
/// Replaces the mobile UserManagementScreen in the web layout.
class WebUserManagementScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const WebUserManagementScreen({super.key, this.onBack});

  @override
  State<WebUserManagementScreen> createState() => _WebUserManagementScreenState();
}

class _WebUserManagementScreenState extends State<WebUserManagementScreen> {
  final List<dynamic> _users = [];
  List<dynamic> _sites = [];
  bool _isLoading = true;
  String _roleFilter = 'all'; // all, system_owner, site_manager, resident
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchSites();
    _fetchUsers();
  }

  // ──── Data Fetching (re-used from mobile) ────

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
        setState(() => _sites = response as List);
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

      final sitesResponse = await SupabaseService.client
          .from('sites')
          .select('id')
          .eq('owner_id', ownerId)
          .filter('deleted_at', 'is', null);

      final siteIds = (sitesResponse as List).map((s) => s['id'] as String).toList();

      var query = SupabaseService.client
          .from('profiles')
          .select()
          .filter('deleted_at', 'is', null);

      if (siteIds.isNotEmpty) {
        final siteIdsStr = siteIds.map((id) => '"$id"').join(',');
        query = query.or('id.eq.$ownerId,created_by.eq.$ownerId,site_id.in.($siteIdsStr)');
      } else {
        query = query.or('id.eq.$ownerId,created_by.eq.$ownerId');
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

  // ──── Filtered Users ────

  List<dynamic> get _filteredUsers {
    var list = _users.toList();
    if (_roleFilter != 'all') {
      list = list.where((u) => u['role'] == _roleFilter).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((u) {
        final name = (u['full_name'] ?? '').toString().toLowerCase();
        final email = (u['email'] ?? '').toString().toLowerCase();
        return name.contains(q) || email.contains(q);
      }).toList();
    }
    return list;
  }

  // ──── Stats ────

  int get _totalCount => _users.length;
  int get _ownerCount => _users.where((u) => u['role'] == 'system_owner').length;
  int get _managerCount => _users.where((u) => u['role'] == 'site_manager').length;
  int get _residentCount => _users.where((u) => u['role'] == 'resident').length;

  // ──── Delete User ────

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    final l10n = AppLocalizations.of(context)!;
    final isModern = Provider.of<ThemeService>(context, listen: false).isModern;
    final textColor = isModern ? Colors.white : AppColors.mgmtTextHeading;
    final subtextColor = isModern ? Colors.white70 : AppColors.mgmtTextBody;

    final authService = Provider.of<AuthService>(context, listen: false);
    if (user['id'] == authService.currentUser?.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.errorLabel}: ${l10n.cannotDeleteSelf}')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isModern ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 24),
          const SizedBox(width: 8),
          Expanded(child: Text(l10n.deleteUser, style: TextStyle(color: textColor, fontSize: 18))),
        ]),
        content: Text(l10n.deleteUserPrompt, style: TextStyle(color: subtextColor, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel, style: TextStyle(color: subtextColor, fontWeight: FontWeight.bold)),
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
            .from('profiles')
            .update({'deleted_at': DateTime.now().toIso8601String()})
            .eq('id', user['id']);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.userUpdatedSuccessfully)),
        );
        _fetchUsers();
      } catch (e) {
        print('Error deleting user: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${l10n.errorLabel}: $e')),
          );
        }
      }
    }
  }

  // ──── Add / Edit User Dialog (web-native) ────

  Future<void> _showUserDialog({Map<String, dynamic>? user}) async {
    final l10n = AppLocalizations.of(context)!;
    final isModern = Provider.of<ThemeService>(context, listen: false).isModern;
    final textColor = isModern ? Colors.white : AppColors.mgmtTextHeading;
    final subtextColor = isModern ? Colors.white70 : AppColors.mgmtTextBody;
    final primaryColor = isModern ? const Color(0xFF3B82F6) : AppColors.mgmtPrimary;

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

    // Pre-fetch data for editing a resident
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
                child: Icon(isEditing ? Icons.edit_rounded : Icons.person_add_rounded, color: primaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isEditing ? l10n.editUser : l10n.addUser, style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 18)),
                    Text(
                      isEditing ? 'Kullanıcı bilgilerini güncelle' : 'Yeni kullanıcı tanımla',
                      style: TextStyle(fontSize: 12, color: subtextColor, fontWeight: FontWeight.normal),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: subtextColor, size: 20),
                onPressed: () => Navigator.pop(ctx),
              ),
            ]),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Full Name
                    _buildDialogField(
                      controller: nameController,
                      label: l10n.fullNameLabel,
                      icon: Icons.person_outline,
                      enabled: !isSubmitting,
                      isModern: isModern,
                      textColor: textColor,
                      subtextColor: subtextColor,
                      primaryColor: primaryColor,
                    ),
                    const SizedBox(height: 14),
                    // Email
                    _buildDialogField(
                      controller: emailController,
                      label: l10n.emailLabel,
                      icon: Icons.email_outlined,
                      enabled: !isSubmitting,
                      readOnly: isEditing,
                      isModern: isModern,
                      textColor: textColor,
                      subtextColor: subtextColor,
                      primaryColor: primaryColor,
                    ),
                    if (!isEditing) ...[
                      const SizedBox(height: 14),
                      // Password
                      _buildDialogField(
                        controller: passwordController,
                        label: l10n.passwordLabel,
                        icon: Icons.lock_outline,
                        enabled: !isSubmitting,
                        isPassword: true,
                        isModern: isModern,
                        textColor: textColor,
                        subtextColor: subtextColor,
                        primaryColor: primaryColor,
                      ),
                    ],
                    const SizedBox(height: 14),
                    // Role
                    _buildDialogDropdown<String>(
                      value: selectedRole,
                      label: l10n.selectRole,
                      icon: Icons.shield_outlined,
                      isModern: isModern,
                      textColor: textColor,
                      subtextColor: subtextColor,
                      primaryColor: primaryColor,
                      items: [
                        DropdownMenuItem(value: 'system_owner', child: Text(l10n.systemOwner, style: TextStyle(fontSize: 14, color: textColor))),
                        DropdownMenuItem(value: 'site_manager', child: Text(l10n.siteManagerRole, style: TextStyle(fontSize: 14, color: textColor))),
                        DropdownMenuItem(value: 'resident', child: Text(l10n.residentRole, style: TextStyle(fontSize: 14, color: textColor))),
                      ],
                      onChanged: isSubmitting ? null : (val) {
                        if (val != null) setDState(() => selectedRole = val);
                      },
                    ),
                    if (selectedRole != 'system_owner') ...[
                      const SizedBox(height: 14),
                      // Site
                      _buildDialogDropdown<String?>(
                        value: selectedSiteId,
                        label: l10n.sites,
                        icon: Icons.business_outlined,
                        isModern: isModern,
                        textColor: textColor,
                        subtextColor: subtextColor,
                        primaryColor: primaryColor,
                        items: [
                          DropdownMenuItem(value: null, child: Text(l10n.noAssignedSite, style: TextStyle(fontSize: 14, color: textColor), overflow: TextOverflow.ellipsis)),
                          ..._sites.map((site) => DropdownMenuItem(
                            value: site['id'] as String,
                            child: Text(site['name'] ?? '', style: TextStyle(fontSize: 14, color: textColor), overflow: TextOverflow.ellipsis),
                          )),
                        ],
                        onChanged: isSubmitting ? null : (val) async {
                          setDState(() {
                            selectedSiteId = val;
                            selectedBlockId = null;
                            selectedApartmentId = null;
                            localBlocks = [];
                            localApartments = [];
                          });
                          if (val != null) {
                            setDState(() => isLoadingDependent = true);
                            try {
                              final blocksRes = await SupabaseService.client.from('blocks').select('id, name').eq('site_id', val).filter('deleted_at', 'is', null);
                              setDState(() => localBlocks = blocksRes as List);
                            } finally {
                              setDState(() => isLoadingDependent = false);
                            }
                          }
                        },
                      ),
                    ],
                    if (selectedRole == 'resident' && selectedSiteId != null) ...[
                      const SizedBox(height: 14),
                      if (isLoadingDependent)
                        const LinearProgressIndicator(minHeight: 2)
                      else
                        // Block
                        _buildDialogDropdown<String?>(
                          value: selectedBlockId,
                          label: 'Blok Seçin',
                          icon: Icons.domain_outlined,
                          isModern: isModern,
                          textColor: textColor,
                          subtextColor: subtextColor,
                          primaryColor: primaryColor,
                          items: [
                            DropdownMenuItem(value: null, child: Text('Blok Seçilmedi', style: TextStyle(color: textColor))),
                            ...localBlocks.map((b) => DropdownMenuItem(value: b['id'] as String, child: Text(b['name'] ?? '', style: TextStyle(color: textColor)))),
                          ],
                          onChanged: isSubmitting ? null : (val) async {
                            setDState(() {
                              selectedBlockId = val;
                              selectedApartmentId = null;
                              localApartments = [];
                            });
                            if (val != null) {
                              setDState(() => isLoadingDependent = true);
                              try {
                                final aptsRes = await SupabaseService.client.from('apartments').select('id, number').eq('block_id', val).filter('deleted_at', 'is', null).order('number');
                                setDState(() => localApartments = aptsRes as List);
                              } finally {
                                setDState(() => isLoadingDependent = false);
                              }
                            }
                          },
                        ),
                      const SizedBox(height: 14),
                      // Apartment
                      _buildDialogDropdown<String?>(
                        value: selectedApartmentId,
                        label: 'Daire Seçin',
                        icon: Icons.door_front_door_outlined,
                        isModern: isModern,
                        textColor: textColor,
                        subtextColor: subtextColor,
                        primaryColor: primaryColor,
                        items: [
                          DropdownMenuItem(value: null, child: Text('Daire Seçilmedi', style: TextStyle(color: textColor))),
                          ...localApartments.map((a) => DropdownMenuItem(value: a['id'] as String, child: Text('Daire ${a['number']}', style: TextStyle(color: textColor)))),
                        ],
                        onChanged: isSubmitting ? null : (val) {
                          setDState(() => selectedApartmentId = val);
                        },
                      ),
                    ],
                    // Error message
                    if (errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 13))),
                        ]),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.cancel, style: TextStyle(color: subtextColor, fontWeight: FontWeight.bold)),
              ),
              ElevatedButton.icon(
                icon: isSubmitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(isEditing ? Icons.save_rounded : Icons.person_add_rounded, color: Colors.white, size: 18),
                label: Text(
                  isSubmitting ? 'Kaydediliyor...' : (isEditing ? l10n.update : l10n.save),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  minimumSize: const Size(0, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: isSubmitting ? null : () async {
                  setDState(() => errorMessage = null);

                  // Validation
                  if (nameController.text.trim().isEmpty) {
                    setDState(() => errorMessage = 'Lütfen Ad Soyad alanını doldurun.');
                    return;
                  }
                  if (!isEditing) {
                    if (emailController.text.trim().isEmpty) {
                      setDState(() => errorMessage = 'Lütfen E-posta alanını doldurun.');
                      return;
                    }
                    if (passwordController.text.isEmpty) {
                      setDState(() => errorMessage = 'Lütfen bir Şifre belirleyin.');
                      return;
                    }
                    if (passwordController.text.length < 6) {
                      setDState(() => errorMessage = 'Şifre en az 6 karakter olmalıdır.');
                      return;
                    }
                  }

                  if (selectedRole != 'system_owner' && selectedSiteId == null) {
                    setDState(() => errorMessage = 'Lütfen bir Site seçin.');
                    return;
                  }

                  if (selectedRole == 'resident' && selectedApartmentId == null) {
                    setDState(() => errorMessage = 'Lütfen bir Daire seçin.');
                    return;
                  }

                  setDState(() => isSubmitting = true);
                  try {
                    if (isEditing) {
                      await SupabaseService.client.from('profiles').update({
                        'full_name': nameController.text,
                        'role': selectedRole,
                        'site_id': selectedSiteId,
                      }).eq('id', user!['id']);

                      if (selectedRole == 'site_manager' && selectedSiteId != null) {
                        await SupabaseService.client.from('sites').update({
                          'manager_id': user['id']
                        }).eq('id', selectedSiteId as Object);
                      }

                      if (selectedRole == 'resident' && selectedApartmentId != null) {
                        await SupabaseService.client.from('apartments').update({'resident_id': null}).eq('resident_id', user['id']);
                        await SupabaseService.client.from('apartments').update({'resident_id': user['id']}).eq('id', selectedApartmentId as Object);
                      }

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.userUpdatedSuccessfully)));
                      }
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
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.userCreatedSuccessfully)));
                      }
                    }
                    if (mounted) Navigator.pop(ctx);
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
                    setDState(() => errorMessage = 'Hata: $errorMsg');
                  } finally {
                    if (mounted) setDState(() => isSubmitting = false);
                  }
                },
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
    bool readOnly = false,
    bool isPassword = false,
    required bool isModern,
    required Color textColor,
    required Color subtextColor,
    required Color primaryColor,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      readOnly: readOnly,
      obscureText: isPassword,
      style: TextStyle(
        color: readOnly ? textColor.withOpacity(0.7) : textColor,
        fontSize: 15,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: subtextColor, fontSize: 14),
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
      dropdownColor: isModern ? const Color(0xFF1E293B) : Colors.white,
      isExpanded: true,
      items: items,
      onChanged: onChanged,
      icon: Icon(Icons.keyboard_arrow_down_rounded, color: subtextColor),
      style: TextStyle(color: textColor, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: subtextColor, fontSize: 14),
        prefixIcon: Icon(icon, color: primaryColor, size: 20),
        filled: true,
        fillColor: isModern ? Colors.black.withOpacity(0.2) : Colors.grey.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  // ──── Role helpers ────

  String _roleName(String role, AppLocalizations l10n) {
    switch (role) {
      case 'system_owner': return l10n.systemOwner;
      case 'site_manager': return l10n.siteManagerRole;
      case 'resident': return l10n.residentRole;
      default: return role;
    }
  }

  IconData _roleIcon(String role) {
    switch (role) {
      case 'system_owner': return Icons.admin_panel_settings;
      case 'site_manager': return Icons.manage_accounts;
      default: return Icons.person;
    }
  }

  Color _roleColor(String role, bool isModern) {
    switch (role) {
      case 'system_owner': return isModern ? Colors.purpleAccent : AppColors.mgmtPrimary;
      case 'site_manager': return isModern ? AppColors.secondary : AppColors.mgmtAccent;
      default: return isModern ? AppColors.primary : AppColors.mgmtSecondary;
    }
  }

  String _siteName(String? siteId) {
    if (siteId == null) return '-';
    try {
      final site = _sites.firstWhere((s) => s['id'] == siteId);
      return site['name'] ?? '-';
    } catch (_) {
      return '-';
    }
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
                      Text(l10n.userManagement, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: textColor)),
                      const SizedBox(height: 4),
                      Text('Kullanıcıları görüntüle, ekle ve yönet.', style: TextStyle(color: subtextColor, fontSize: 16)),
                    ],
                  ),
                ),
                // Search box
                SizedBox(
                  width: 260,
                  height: 40,
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: TextStyle(color: textColor, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Kullanıcı ara...',
                      hintStyle: TextStyle(color: subtextColor, fontSize: 13),
                      prefixIcon: Icon(Icons.search_rounded, color: subtextColor, size: 20),
                      filled: true,
                      fillColor: cardBg,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: isModern ? Colors.white10 : AppColors.mgmtBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: isModern ? Colors.white10 : AppColors.mgmtBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: primaryColor, width: 1.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: _fetchUsers,
                  icon: const Icon(Icons.refresh),
                  color: subtextColor,
                  tooltip: 'Yenile',
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _showUserDialog(),
                  icon: const Icon(Icons.person_add_rounded, color: Colors.white, size: 18),
                  label: Text(l10n.addUser, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
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

          // ──── Summary Cards (clickable for filtering) ────
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 20, 32, 0),
            child: Row(
              children: [
                _buildStatCard('Toplam Kullanıcı', '$_totalCount', Icons.people_rounded, primaryColor, isModern, cardBg, textColor, subtextColor, filterKey: 'all'),
                const SizedBox(width: 12),
                _buildStatCard(l10n.systemOwner, '$_ownerCount', Icons.admin_panel_settings, Colors.purpleAccent, isModern, cardBg, textColor, subtextColor, filterKey: 'system_owner'),
                const SizedBox(width: 12),
                _buildStatCard(l10n.siteManagerRole, '$_managerCount', Icons.manage_accounts, Colors.orange, isModern, cardBg, textColor, subtextColor, filterKey: 'site_manager'),
                const SizedBox(width: 12),
                _buildStatCard(l10n.residentRole, '$_residentCount', Icons.person, Colors.blue, isModern, cardBg, textColor, subtextColor, filterKey: 'resident'),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ──── Data Table ────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredUsers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, size: 64, color: subtextColor),
                            const SizedBox(height: 16),
                            Text(
                              _roleFilter == 'all' && _searchQuery.isEmpty
                                  ? l10n.noUsersFound
                                  : 'Bu filtreye uygun kullanıcı bulunamadı.',
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
                                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                                ),
                                child: Row(
                                  children: [
                                    const SizedBox(width: 48), // Avatar space
                                    Expanded(flex: 3, child: Text('Ad Soyad', style: _headerStyle(subtextColor))),
                                    Expanded(flex: 3, child: Text('E-posta', style: _headerStyle(subtextColor))),
                                    Expanded(flex: 2, child: Text('Rol', style: _headerStyle(subtextColor))),
                                    Expanded(flex: 2, child: Text('Site', style: _headerStyle(subtextColor))),
                                    const SizedBox(width: 90), // Actions space
                                  ],
                                ),
                              ),
                              Divider(height: 1, color: isModern ? Colors.white10 : Colors.black.withOpacity(0.06)),
                              // Table body
                              Expanded(
                                child: ListView.separated(
                                  padding: EdgeInsets.zero,
                                  itemCount: _filteredUsers.length,
                                  separatorBuilder: (_, __) => Divider(height: 1, color: isModern ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04)),
                                  itemBuilder: (context, index) {
                                    final user = _filteredUsers[index];
                                    return _buildUserRow(user, isModern, textColor, subtextColor, primaryColor, l10n);
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

  // ──── Table Row ────

  Widget _buildUserRow(dynamic user, bool isModern, Color textColor, Color subtextColor, Color primaryColor, AppLocalizations l10n) {
    final role = (user['role'] ?? 'resident') as String;
    final roleColor = _roleColor(role, isModern);

    return InkWell(
      onTap: () => _showUserDialog(user: user),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: roleColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: roleColor.withOpacity(0.2)),
              ),
              child: Icon(_roleIcon(role), color: roleColor, size: 18),
            ),
            const SizedBox(width: 12),
            // Name
            Expanded(
              flex: 3,
              child: Text(
                user['full_name'] ?? 'İsimsiz',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: textColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Email
            Expanded(
              flex: 3,
              child: Text(
                user['email'] ?? '-',
                style: TextStyle(fontSize: 13, color: subtextColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Role badge
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: roleColor.withOpacity(isModern ? 0.15 : 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: roleColor.withOpacity(isModern ? 0.4 : 0.6), width: 1),
                  ),
                  child: Text(
                    _roleName(role, l10n).toUpperCase(),
                    style: TextStyle(color: roleColor, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                  ),
                ),
              ),
            ),
            // Site
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Icon(Icons.business_rounded, size: 14, color: subtextColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _siteName(user['site_id']),
                      style: TextStyle(fontSize: 13, color: subtextColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            // Actions
            SizedBox(
              width: 90,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: Icon(Icons.edit_outlined, color: primaryColor.withOpacity(0.7), size: 18),
                    onPressed: () => _showUserDialog(user: user),
                    tooltip: l10n.editUser,
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline_rounded, color: Colors.redAccent.withOpacity(0.7), size: 18),
                    onPressed: () => _deleteUser(user),
                    tooltip: l10n.deleteUser,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──── Reusable widgets ────

  TextStyle _headerStyle(Color color) => TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: color, letterSpacing: 0.5);

  Widget _buildStatCard(String label, String value, IconData icon, Color color, bool isModern, Color cardBg, Color textColor, Color subtextColor, {String? filterKey}) {
    final isSelected = filterKey != null && _roleFilter == filterKey;

    return Expanded(
      child: MouseRegion(
        cursor: filterKey != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: filterKey != null ? () {
            setState(() {
              _roleFilter = (_roleFilter == filterKey) ? 'all' : filterKey;
            });
          } : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? color.withOpacity(0.6)
                    : (isModern ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06)),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected ? [
                BoxShadow(color: color.withOpacity(0.15), blurRadius: 12, spreadRadius: 0),
              ] : null,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(isSelected ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
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
        ),
      ),
    );
  }
}
