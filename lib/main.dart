import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/utils/permission_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Request permissions on app startup
  await PermissionService.requestAllPermissions();

  runApp(
    const ProviderScope(
      child: App(),
    ),
  );
}
