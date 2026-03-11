import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://vsgvdzeasejwzcdzxnmp.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZzZ3ZkemVhc2Vqd3pjZHp4bm1wIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE1ODQ5MDQsImV4cCI6MjA4NzE2MDkwNH0.BkjLOYjk1cixsDwgKuGRR5PK7CVq00BLjvrSUUaWWVg'
  );

  final response = await supabase
      .from('profiles')
      .select('email, role, full_name, id');

  for (var r in response as List) {
    print('User: ${r['email']} | Role: ${r['role']} | Name: ${r['full_name']} | ID: ${r['id']}');
  }
}
