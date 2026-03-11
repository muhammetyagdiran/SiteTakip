import 'package:supabase/supabase.dart';

void main() async {
  const url = 'https://vsgvdzeasejwzcdzxnmp.supabase.co';
  const serviceRoleKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZzZ3ZkemVhc2Vqd3pjZHp4bm1wIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MTU4NDkwNCwiZXhwIjoyMDg3MTYwOTA0fQ.UN7nzm9ATqh4U7AyfVnHy2k_qeruOvUBgyVmzlljND0';

  final supabase = SupabaseClient(url, serviceRoleKey);

  try {
    print('Testing profiles table accessibility...');
    final response = await supabase.from('profiles').select().limit(1);
    print('Success! Found ${response.length} profiles.');
  } catch (e) {
    print('Failed to access profiles table: $e');
  }

  try {
    print('Testing site owner email exists in auth...');
    final listResponse = await supabase.auth.admin.listUsers();
    final owner = listResponse.firstWhere((u) => u.email == 'owner@example.com');
    print('Found owner: ${owner.id}');
  } catch (e) {
    print('Failed to find owner or list users: $e');
  }
}
