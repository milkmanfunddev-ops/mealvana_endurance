import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Mock Supabase client for testing
/// Uses mocktail to stub Supabase SDK calls
class MockSupabaseClient extends Mock implements SupabaseClient {}

/// Mock GoTrue client for authentication testing
class MockGoTrueClient extends Mock implements GoTrueClient {}

/// Mock Functions client for edge function testing
class MockFunctionsClient extends Mock implements FunctionsClient {}
