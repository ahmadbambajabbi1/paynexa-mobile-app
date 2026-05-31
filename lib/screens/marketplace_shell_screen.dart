import 'package:flutter/material.dart';

import '../config/constants.dart';
import '../theme/app_colors.dart';
import 'billings_screen.dart';
// import 'marketplace_explore_screen.dart';
// import 'marketplace_store_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'transactions_screen.dart';

class MarketplaceShellScreen extends StatefulWidget {
  const MarketplaceShellScreen({super.key});

  @override
  State<MarketplaceShellScreen> createState() => _MarketplaceShellScreenState();
}

class _MarketplaceShellScreenState extends State<MarketplaceShellScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final body = switch (_index) {
      // 0 => const MarketplaceExploreScreen(),
      0 => const TransactionsScreen(),
      1 => const BillingsScreen(),
      // 2 => MarketplaceStoreScreen(
      //   onGoToExplore: () => setState(() => _index = 0),
      // ),
      2 => const ProfileScreen(),
      _ => const TransactionsScreen(),
    };

    return Scaffold(
      // appBar:
          // _index == 0
          // ? null
          // :
          // AppBar(
          //   title: Text.rich(
          //     TextSpan(
          //       children: [
          //         TextSpan(
          //           text: kAppName,
          //           style: TextStyle(
          //             fontSize: 17,
          //             letterSpacing: -0.35,
          //             fontWeight: FontWeight.w700,
          //             color: Colors.grey.shade900,
          //             decoration: TextDecoration.none,
          //           ),
          //         ),
          //         TextSpan(
          //           text: ' $kAppNameRegion',
          //           style: const TextStyle(
          //             fontSize: 17,
          //             fontWeight: FontWeight.w800,
          //             letterSpacing: 0.2,
          //             color: AppColors.primaryColorBlack,
          //             decoration: TextDecoration.none,
          //           ),
          //         ),
          //       ],
          //     ),
          //     maxLines: 1,
          //     overflow: TextOverflow.ellipsis,
          //     textAlign: TextAlign.center,
          //   ),
          //   actions: [
          //     IconButton(
          //       tooltip: 'Notifications',
          //       onPressed: () {
          //         Navigator.of(context).push(
          //           MaterialPageRoute<void>(
          //             builder: (_) => const NotificationsScreen(),
          //           ),
          //         );
          //       },
          //       icon: const Icon(Icons.notifications_outlined),
          //     ),
          //   ],
          // ),
      body: SafeArea(child: body),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? Colors.white
                  : Colors.white70,
            ),
          ),
        ),
        child: NavigationBar(
          backgroundColor: AppColors.primaryColorBlack,
          indicatorColor: Colors.white.withValues(alpha: 0.18),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              fontSize: 12,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w800
                  : FontWeight.w600,
              color: states.contains(WidgetState.selected)
                  ? Colors.white
                  : Colors.white70,
            ),
          ),
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            // NavigationDestination(
            //   icon: Icon(Icons.explore_outlined),
            //   selectedIcon: Icon(Icons.explore),
            //   label: 'Explore',
            // ),
            NavigationDestination(
              icon: Icon(Icons.swap_horiz_outlined),
              selectedIcon: Icon(Icons.swap_horiz),
              label: 'Transactions',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet),
              label: 'Wallet',
            ),
            // NavigationDestination(
            //   icon: Icon(Icons.storefront_outlined),
            //   selectedIcon: Icon(Icons.storefront),
            //   label: 'Store',
            // ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
