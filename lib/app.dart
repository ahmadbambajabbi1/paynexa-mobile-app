import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_links/app_links.dart';

import 'auth/auth_controller.dart';
import 'config/constants.dart';
import 'screens/marketplace_shell_screen.dart';
import 'screens/complete_profile_screen.dart';
import 'screens/login_screen.dart';
import 'screens/public_checkout_screen.dart';
import 'screens/transaction_detail_screen.dart';
import 'theme/app_theme.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class EscrowApp extends StatelessWidget {
  const EscrowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthController()..bootstrap(),
      child: MaterialApp(
        title: kAppName,
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          // Prevent extreme system font scaling from breaking layouts.
          final clamped = mq.textScaler.clamp(
            minScaleFactor: 0.9,
            maxScaleFactor: 1.15,
          );
          return MediaQuery(
            data: mq.copyWith(textScaler: clamped),
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: const RootRouter(),
      ),
    );
  }
}

class RootRouter extends StatefulWidget {
  const RootRouter({super.key});

  @override
  State<RootRouter> createState() => _RootRouterState();
}

class _RootRouterState extends State<RootRouter> with WidgetsBindingObserver {
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initDeepLinks();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(context.read<AuthController>().refreshUser());
    }
  }

  void _initDeepLinks() async {
    _appLinks = AppLinks();

    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      if (mounted) {
        _handleDeepLink(uri, context);
      }
    });

    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null && mounted) {
        _handleDeepLink(initialUri, context);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthController>(
      builder: (context, auth, _) {
        if (auth.loading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (auth.token == null) {
          return const LoginScreen();
        }
        if (!auth.profileReady) {
          return const CompleteProfileScreen();
        }
        return const MarketplaceShellScreen();
      },
    );
  }
}

void _handleDeepLink(Uri uri, BuildContext context) async {
  final pathSegments = uri.pathSegments;
  String? id;
  bool isPublicCheckout = false;

  if (uri.scheme == 'safetrade') {
    if (uri.host == 'pay' && pathSegments.isNotEmpty) {
      id = pathSegments.first;
      isPublicCheckout = true;
    } else if (uri.host == 'transactions' && pathSegments.isNotEmpty) {
      id = pathSegments.first;
    }
  } else {
    if (pathSegments.length >= 2 && pathSegments[0] == 'pay') {
      id = pathSegments[1];
      isPublicCheckout = true;
    }
  }

  if (id == null || id.isEmpty) return;

  navigatorKey.currentState?.push(
    MaterialPageRoute<void>(
      builder: (_) => isPublicCheckout
          ? PublicCheckoutScreen(ref: id!)
          : TransactionDetailScreen(transactionId: id!),
    ),
  );
}
