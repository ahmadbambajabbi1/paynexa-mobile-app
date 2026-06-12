import 'package:flutter/material.dart';

import 'app.dart';
import 'push/push_notifications_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PushNotificationsService.instance.initialize();
  runApp(const EscrowApp());
}
