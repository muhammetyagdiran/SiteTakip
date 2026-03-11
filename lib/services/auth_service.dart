import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import 'supabase_service.dart';
import 'notification_service.dart';

class AuthService extends ChangeNotifier {
  AppUser? _currentUser;
  bool _isLoading = false;
  bool _isLoggingIn = false;

  AppUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isLoggingIn => _isLoggingIn;

  AuthService() {
    _init();
  }

  Future<void> _init() async {
    final session = SupabaseService.client.auth.currentSession;
    if (session != null) {
      await _fetchProfile(session.user.id, session.user.email!);
    }
  }

  Future<void> _fetchProfile(String userId, String email) async {
    try {
      final data = await SupabaseService.client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (data == null) {
        // Self-healing: Profil kaydı hiç yoksa otomatik oluştur
        print('Profile not found, creating default for $email');
        final defaultName = email.split('@')[0];
        final newData = {
          'id': userId,
          'full_name': defaultName,
          'email': email,
          'role': 'resident',
        };
        await SupabaseService.client.from('profiles').upsert(newData);
        _currentUser = AppUser.fromMap(newData, email);
      } else if (data['deleted_at'] != null) {
        // KULLANICI SİLİNMİŞ - GİRİŞİ ENGELLE
        print('User is soft-deleted, logging out.');
        await logout();
        throw Exception('Bu hesap kullanım dışıdır.');
      } else {
        // Sync email if missing in profile - Wrap in try-catch to prevent login failure if column doesn't exist yet
        try {
          if (data['email'] == null) {
            await SupabaseService.client
                .from('profiles')
                .update({'email': email})
                .eq('id', userId);
          }
        } catch (e) {
          print('Email sync skipped (column might be missing): $e');
        }
        _currentUser = AppUser.fromMap(data, email);
        print('====== DEBUG LOGIN ======');
        print('Email: $email');
        print('DB Role: ${data['role']}');
        print('Parsed Role: ${_currentUser?.role}');
        print('====== END DEBUG ======');
      }
      // Initialize notifications for the logged in user
      NotificationService.initialize();
      notifyListeners();
    } catch (e) {
      print('Error fetching profile: $e');
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _isLoggingIn = true;
    notifyListeners();
    try {
      final response = await SupabaseService.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.user != null) {
        await _fetchProfile(response.user!.id, response.user!.email!);
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      print('Login error: $e');
      _isLoading = false;
      _isLoggingIn = false;
      notifyListeners();
      rethrow;
    }
    _isLoading = false;
    _isLoggingIn = false;
    notifyListeners();
    return false;
  }

  Future<void> logout() async {
    await SupabaseService.client.auth.signOut();
    _currentUser = null;
    notifyListeners();
  }
}
