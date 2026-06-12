import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class MarketplaceChatsScreen extends StatelessWidget {
  const MarketplaceChatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(gradient: AppColors.pageBackground),
          child: SizedBox.expand(),
        ),
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Chats',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Client ↔ provider chat linked to bookings/transactions.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Next step: wire messaging-service rooms to service bookings (by transactionId) '
                  'and show real-time messages here.',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ),
            ),
            // Marketplace booking push notifications (PayNexa) — enable when FCM marketplace flow ships.
            // Card(
            //   child: Padding(
            //     padding: const EdgeInsets.all(16),
            //     child: Text(
            //       'Booking push alerts will appear in Notifications once marketplace.notification.push is enabled.',
            //       style: TextStyle(color: Colors.grey.shade700),
            //     ),
            //   ),
            // ),
          ],
        ),
      ],
    );
  }
}

