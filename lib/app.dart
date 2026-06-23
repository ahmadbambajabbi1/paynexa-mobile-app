import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_links/app_links.dart';

import 'auth/auth_controller.dart';
import 'config/constants.dart';
import 'push/push_notifications_service.dart';
import 'screens/marketplace_booking_detail_screen.dart';
import 'screens/marketplace_shell_screen.dart';
import 'screens/complete_profile_screen.dart';
import 'screens/login_screen.dart';
import 'screens/public_checkout_screen.dart';
import 'screens/transaction_detail_screen.dart';
import 'theme/app_theme.dart';
import 'utils/pending_payment_resume.dart';

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
      final auth = context.read<AuthController>();
      unawaited(auth.refreshUser());
      final token = auth.token;
      if (token != null) {
        unawaited(PushNotificationsService.instance.syncToken(token));
      }
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
        final sessionToken = auth.token;
        if (sessionToken != null) {
          unawaited(PushNotificationsService.instance.syncToken(sessionToken));
        }
        return const MarketplaceShellScreen();
      },
    );
  }
}

bool _isAppDeepLinkScheme(String scheme) =>
    scheme == kDeepLinkScheme || scheme == 'safetrade';

void _handleDeepLink(Uri uri, BuildContext context) {
  // HTTPS bridge from Modem Pay (app checkout uses source=app on /wallet/deposit/*).
  if (uri.scheme == 'https' &&
      uri.pathSegments.length >= 3 &&
      uri.pathSegments[0] == 'wallet' &&
      uri.pathSegments[1] == 'deposit' &&
      uri.queryParameters['source'] == 'app') {
    final outcome = uri.pathSegments[2];
    final bridge = Uri(
      scheme: kDeepLinkScheme,
      host: 'deposit',
      pathSegments: [outcome],
      queryParameters: Map<String, String>.from(uri.queryParameters)..remove('source'),
    );
    _handleDepositReturn(bridge, context);
    return;
  }

  if (_isAppDeepLinkScheme(uri.scheme) && uri.host == 'deposit') {
    _handleDepositReturn(uri, context);
    return;
  }

  final pathSegments = uri.pathSegments;
  String? id;
  bool isPublicCheckout = false;

  if (_isAppDeepLinkScheme(uri.scheme)) {
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

void _handleDepositReturn(Uri uri, BuildContext context) {
  final outcome = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
  if (outcome != 'success' && outcome != 'cancel') return;

  final depositContext = uri.queryParameters['context'] ?? 'billings';
  final id = uri.queryParameters['id'];
  final messenger = ScaffoldMessenger.maybeOf(navigatorKey.currentContext ?? context);

  if (outcome == 'cancel') {
    messenger?.showSnackBar(
      const SnackBar(content: Text('Payment was cancelled.')),
    );
  } else {
    messenger?.showSnackBar(
      const SnackBar(content: Text('Payment received. Your wallet will update shortly.')),
    );
    PendingPaymentResume.clear();
  }

  _navigateAfterDeposit(
    depositContext: depositContext,
    id: id,
    resumePayment: outcome == 'success',
  );
}

void _navigateAfterDeposit({
  required String depositContext,
  String? id,
  required bool resumePayment,
}) {
  switch (depositContext) {
    case 'transaction':
      if (id != null && id.isNotEmpty) {
        navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute<void>(
            builder: (_) => TransactionDetailScreen(
              transactionId: id,
              resumePaymentAfterDeposit: resumePayment,
            ),
          ),
          (route) => false,
        );
      }
      break;
    case 'pay':
      if (id != null && id.isNotEmpty) {
        navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute<void>(
            builder: (_) => PublicCheckoutScreen(
              ref: id,
              resumePaymentAfterDeposit: resumePayment,
            ),
          ),
          (route) => false,
        );
      }
      break;
    case 'booking':
      if (id != null && id.isNotEmpty) {
        navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute<void>(
            builder: (_) => MarketplaceBookingDetailScreen(
              bookingId: id,
              initialMode: 'me',
              resumePaymentAfterDeposit: resumePayment,
            ),
          ),
          (route) => false,
        );
      }
      break;
    case 'billings':
    default:
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => const MarketplaceShellScreen(initialIndex: 1),
        ),
        (route) => false,
      );
      break;
  }
}
