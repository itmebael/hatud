import 'package:supabase_flutter/supabase_flutter.dart';

class AppSupabase {
  static const String supabaseUrl = 'https://csdpoytuklosckjuvtzu.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNzZHBveXR1a2xvc2NranV2dHp1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjAwODk3ODIsImV4cCI6MjA3NTY2NTc4Mn0.ob_BMYIEXrkJ7P6vMg49xB9-rb1L1HHQbMDZdqrYsZ4';

  static SupabaseClient get client => Supabase.instance.client;

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
    _initialized = true;
  }
}

