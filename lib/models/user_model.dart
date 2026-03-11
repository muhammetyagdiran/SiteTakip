enum UserRole { systemOwner, siteManager, resident }

class AppUser {
  final String id;
  final String email;
  final String? fullName;
  final String? phoneNumber;
  final UserRole role;
  final String? siteId;
  final String? createdBy;

  AppUser({
    required this.id,
    required this.email,
    this.fullName,
    this.phoneNumber,
    required this.role,
    this.siteId,
    this.createdBy,
  });

  factory AppUser.fromMap(Map<String, dynamic> map, String email) {
    return AppUser(
      id: map['id'],
      email: email,
      fullName: map['full_name'],
      phoneNumber: map['phone_number'],
      role: _parseRole(map['role']),
      siteId: map['site_id'],
      createdBy: map['created_by'],
    );
  }

  static UserRole _parseRole(String? role) {
    switch (role) {
      case 'system_owner':
        return UserRole.systemOwner;
      case 'site_manager':
        return UserRole.siteManager;
      case 'resident':
      default:
        return UserRole.resident;
    }
  }
}
