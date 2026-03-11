import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static const String url = 'https://vsgvdzeasejwzcdzxnmp.supabase.co';
  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZzZ3ZkemVhc2Vqd3pjZHp4bm1wIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE1ODQ5MDQsImV4cCI6MjA4NzE2MDkwNH0.BkjLOYjk1cixsDwgKuGRR5PK7CVq00BLjvrSUUaWWVg';

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
