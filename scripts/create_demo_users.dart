import 'package:supabase/supabase.dart';

void main() async {
  const url = 'https://vsgvdzeasejwzcdzxnmp.supabase.co';
  const serviceRoleKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZzZ3ZkemVhc2Vqd3pjZHp4bm1wIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MTU4NDkwNCwiZXhwIjoyMDg3MTYwOTA0fQ.UN7nzm9ATqh4U7AyfVnHy2k_qeruOvUBgyVmzlljND0';

  final supabase = SupabaseClient(url, serviceRoleKey);

  final users = [
    {'email': 'owner@example.com', 'role': 'system_owner', 'name': 'Ahmet Yılmaz'},
    {'email': 'manager_kemal@example.com', 'role': 'site_manager', 'name': 'Kemal Ersoy'},
    {'email': 'manager_ayse@example.com', 'role': 'site_manager', 'name': 'Ayşe Demir'},
    {'email': 'resident_can@example.com', 'role': 'resident', 'name': 'Can Tekin'},
    {'email': 'resident_elif@example.com', 'role': 'resident', 'name': 'Elif Yıldız'},
    {'email': 'resident_murat@example.com', 'role': 'resident', 'name': 'Murat Kaya'},
  ];

  for (var userData in users) {
    String? userId;
    try {
      print('--- Processing: ${userData['email']} ---');
      
      // Try to find if user exists
      final listResponse = await supabase.auth.admin.listUsers();
      final existingUser = listResponse.firstWhere(
        (u) => u.email == userData['email'],
        orElse: () => User(
          id: '',
          appMetadata: {},
          userMetadata: {},
          aud: '',
          createdAt: '',
        ),
      );

      if (existingUser.id.isNotEmpty) {
        print('User already exists. Updating password...');
        userId = existingUser.id;
        await supabase.auth.admin.updateUserById(
          userId,
          attributes: AdminUserAttributes(password: 'password123'),
        );
      } else {
        print('Creating new user...');
        final createResponse = await supabase.auth.admin.createUser(
          AdminUserAttributes(
            email: userData['email'] as String,
            password: 'password123',
            emailConfirm: true,
          ),
        );
        userId = createResponse.user?.id;
      }

      if (userId != null) {
        print('Checking profile for ID: $userId');
        try {
          // Check if profile exists
          final profileResponse = await supabase.from('profiles').select().eq('id', userId).maybeSingle();
          
          if (profileResponse == null) {
            print('Creating profile...');
            await supabase.from('profiles').insert({
              'id': userId,
              'full_name': userData['name'],
              'role': userData['role'],
            });
            print('Profile created successfully.');
          } else {
            print('Profile already exists.');
          }
        } catch (e) {
          print('Error with profiles table: $e');
          print('TIP: Ensure you have run the schema.sql in Supabase SQL Editor.');
        }
      }
    } catch (e) {
      print('Unexpected error for ${userData['email']}: $e');
    }
  }
}
