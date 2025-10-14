import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Lightweight mocktail-based Supabase client for overriding in tests.
class FakeSupabaseClient extends Mock implements SupabaseClient {}
