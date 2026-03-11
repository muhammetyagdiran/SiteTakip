enum SiteType { site, apartment }

class Site {
  final String id;
  final String name;
  final String? address;
  final SiteType type;
  final String? managerId;
  final String ownerId;

  Site({
    required this.id,
    required this.name,
    this.address,
    required this.type,
    this.managerId,
    required this.ownerId,
  });

  factory Site.fromMap(Map<String, dynamic> map) {
    return Site(
      id: map['id'],
      name: map['name'],
      address: map['address'],
      type: map['type'] == 'apartment' ? SiteType.apartment : SiteType.site,
      managerId: map['manager_id'],
      ownerId: map['owner_id'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'type': type == SiteType.apartment ? 'apartment' : 'site',
      'manager_id': managerId,
      'owner_id': ownerId,
    };
  }
}
