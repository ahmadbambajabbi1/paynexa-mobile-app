import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_controller.dart';
import '../config/constants.dart';
import '../theme/app_colors.dart';
import 'billings_screen.dart';
import 'dashboard_screen.dart';
import 'notifications_screen.dart';
import 'products_screen.dart';
import 'profile_screen.dart';
import 'transactions_screen.dart';

/// Shell matching [escrow_web/src/components/layout/AppSidebar.tsx] — Dashboard, Products,
/// Transactions, Profile, Billings.
class WorkspaceShellScreen extends StatefulWidget {
  const WorkspaceShellScreen({super.key});

  @override
  State<WorkspaceShellScreen> createState() => _WorkspaceShellScreenState();
}

class _WorkspaceShellScreenState extends State<WorkspaceShellScreen> {
  /// Start on Products: `IndexedStack` used to mount *all* tabs at once, so Dashboard and
  /// Transactions both called `/transactions/by-party` before you even opened them.
  int _index = 1;

  static const _destinations = <_NavDest>[
    _NavDest(0, 'Dashboard', Icons.dashboard_outlined, Icons.dashboard),
    _NavDest(1, 'Products', Icons.inventory_2_outlined, Icons.inventory_2),
    _NavDest(2, 'Transactions', Icons.swap_horiz_outlined, Icons.swap_horiz),
    _NavDest(3, 'Notifications', Icons.notifications_outlined, Icons.notifications),
    _NavDest(4, 'Profile', Icons.person_outline, Icons.person),
    _NavDest(5, 'Wallet', Icons.account_balance_wallet_outlined, Icons.account_balance_wallet),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 720;

    final body = Stack(
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(gradient: AppColors.pageBackground),
          child: SizedBox.expand(),
        ),
        SafeArea(
          top: wide,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (wide) _sideRail(context),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 8, right: 12, top: 8, bottom: 8),
                  child: _workspaceBody(),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (wide) {
      return Scaffold(body: body);
    }

    return Scaffold(
      appBar: AppBar(
        title: RichText(
          text: TextSpan(
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade900),
            children: [
              TextSpan(text: kAppName),
              TextSpan(
                text: kAppNameRegion,
                style: const TextStyle(color: AppColors.gambianRed),
              ),
            ],
          ),
        ),
      ),
      drawer: Drawer(
        child: _drawerContent(context, rail: false),
      ),
      body: body,
    );
  }

  /// Only the selected tab is built — avoids transaction-service calls during login/workspace entry.
  Widget _workspaceBody() {
    switch (_index) {
      case 0:
        return const DashboardScreen();
      case 1:
        return const ProductsScreen();
      case 2:
        return const TransactionsScreen();
      case 3:
        return const NotificationsScreen();
      case 4:
        return const ProfileScreen();
      case 5:
        return const BillingsScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _sideRail(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.92),
      child: Container(
        width: 256,
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: Colors.grey.shade200)),
          boxShadow: [
            BoxShadow(
              color: AppColors.gambianBlue.withOpacity(0.08),
              offset: const Offset(4, 0),
              blurRadius: 24,
            ),
          ],
        ),
        child: _drawerContent(context, rail: true),
      ),
    );
  }

  Widget _drawerContent(BuildContext context, {required bool rail}) {
    final auth = context.watch<AuthController>();
    final user = auth.user;
    final initials = (user?.displayName ?? user?.phone ?? 'U').trim();
    final short = initials.isEmpty
        ? 'U'
        : (initials.length >= 2 ? initials.substring(0, 2) : initials).toUpperCase();

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(14)),
              gradient: AppColors.heroIconGradient,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.shield_outlined, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.grey.shade900),
                    children: [
                      TextSpan(text: kAppName),
                      TextSpan(
                        text: kAppNameRegion,
                        style: const TextStyle(color: AppColors.gambianRed),
                      ),
                    ],
                  ),
                ),
                Text(
                  'Workspace',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final menuLabel = Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Text(
        'MENU',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          color: Colors.grey.shade400,
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!rail) const SizedBox(height: 8),
        header,
        menuLabel,
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: _destinations.length,
            itemBuilder: (context, i) {
              final d = _destinations[i];
              final selected = _index == d.index;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Material(
                  color: selected ? AppColors.gambianBlue.withOpacity(0.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      setState(() => _index = d.index);
                      if (!rail) Navigator.of(context).pop();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: selected ? AppColors.gambianBlue : Colors.grey.shade100,
                            ),
                            child: Icon(
                              selected ? d.selectedIcon : d.icon,
                              size: 18,
                              color: selected ? Colors.white : Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              d.label,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: selected ? AppColors.gambianBlue : Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.grey.shade50, Colors.white],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.gambianGreen,
                      child: Text(short, style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.displayName ?? user?.phone ?? 'Account',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          Text(
                            auth.profileReady ? 'Verified' : 'Complete your profile',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => context.read<AuthController>().logout(),
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Sign out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey.shade700,
                  side: BorderSide(color: Colors.grey.shade300),
                  minimumSize: const Size.fromHeight(44),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NavDest {
  const _NavDest(this.index, this.label, this.icon, this.selectedIcon);

  final int index;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
