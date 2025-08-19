import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'shared/widgets/root_app_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://wvmvsodrvbkxfydabqed.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind2bXZzb2RydmJreGZ5ZGFicWVkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTUyOTMxMDcsImV4cCI6MjA3MDg2OTEwN30.pG2IYdEIIFS8_zPxzr6pZplzWQqvD13dvslrpFMAPCk',
  );
  
  runApp(
    const ProviderScope(
      child: RootAppWidget(),
    ),
  );
}

