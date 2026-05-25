// import 'package:flutter/material.dart';
// import 'package:flutter_stripe/flutter_stripe.dart';
// import 'package:provider/provider.dart';
// import 'package:url_launcher/url_launcher.dart';

// import '../api/escrow_api.dart';
// import '../auth/auth_controller.dart';
// import '../config/constants.dart';
// import '../models/wallet_models.dart';
// import '../theme/app_colors.dart';
// import '../utils/snackbar.dart';
// import '../widgets/glass_card.dart';

// class BillingsScreen extends StatelessWidget {
//   const BillingsScreen({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return const _WalletBody();
//   }
// }

// class _WalletBody extends StatefulWidget {
//   const _WalletBody();

//   @override
//   State<_WalletBody> createState() => _WalletBodyState();
// }

// class _WalletBodyState extends State<_WalletBody> {
//   bool _loading = true;
//   int _activeTabIndex = 0;
//   String _balance = '0';
//   List<Map<String, dynamic>> _methods = const [];
//   List<WalletTransferSummary> _transfers = const [];
//   WalletTransferStats _stats =
//       WalletTransferStats(transferCount: 0, totalDeposited: '0', totalWithdrawn: '0');

//   String _publicError(Object error) {
//     final message = error.toString();
//     final lowered = message.toLowerCase();
//     if (lowered.contains('secret') ||
//         lowered.contains('token') ||
//         lowered.contains('apikey') ||
//         lowered.contains('database_url')) {
//       return 'Payment request failed. Please try again.';
//     }
//     return message;
//   }

//   @override
//   void initState() {
//     super.initState();
//     _refresh();
//   }

//   Future<void> _refresh() async {
//     final auth = context.read<AuthController>();
//     final token = auth.token;
//     if (token == null || token.isEmpty) return;
//     setState(() => _loading = true);
//     try {
//       final wallet = await getWallet(token);
//       final methods = await listPaymentMethods(token);
//       final stats = await getWalletTransferStats(token);
//       final transfers = await getWalletTransfers(token, limit: 200);
//       setState(() {
//         _balance = wallet.balance;
//         _methods = methods
//             .map(
//               (m) => {
//                 'id': m.id,
//                 'label': m.label,
//                 'provider': m.provider,
//                 'type': m.type,
//                 'last4': m.last4,
//                 'brand': m.brand,
//                 'msisdn': m.msisdn,
//               },
//             )
//             .toList();
//         _transfers = transfers;
//         _stats = stats;
//       });
//     } catch (e) {
//       if (mounted) showSnack(context, _publicError(e));
//     } finally {
//       if (mounted) setState(() => _loading = false);
//     }
//   }

//   Future<void> _addCard() async {
//     final auth = context.read<AuthController>();
//     final token = auth.token;
//     if (token == null || token.isEmpty) return;

//     try {
//       final cfg = await getEscrowConfig(token);
//       if (!mounted) return;
//       final pk = (cfg['stripePublishableKey'] ?? '').toString().trim();
//       if (pk.isEmpty) {
//         showSnack(context, 'Card payments are unavailable');
//         return;
//       }
//       Stripe.publishableKey = pk;
//       final setup = await createStripeSetupIntent(token);
//       if (!mounted) return;
//       final setupIntentClientSecret = (setup['clientSecret'] ?? '').toString();
//       final setupIntentId = (setup['setupIntentId'] ?? '').toString();
//       if (setupIntentClientSecret.isEmpty || setupIntentId.isEmpty) {
//         showSnack(context, 'Unable to initialize card setup');
//         return;
//       }

//       await Stripe.instance.initPaymentSheet(
//         paymentSheetParameters: SetupPaymentSheetParameters(
//           setupIntentClientSecret: setupIntentClientSecret,
//           merchantDisplayName: kAppName,
//         ),
//       );
//       await Stripe.instance.presentPaymentSheet();
//       if (!mounted) return;

//       await completeStripeSetupIntent(token, setupIntentId: setupIntentId);
//       if (!mounted) return;
//       showSnack(context, 'Card added successfully');
//       await _refresh();
//     } catch (e) {
//       if (mounted) showSnack(context, _publicError(e));
//     }
//   }

//   Future<void> _depositWithStripe(double amount, String paymentMethodId) async {
//     final auth = context.read<AuthController>();
//     final token = auth.token;
//     if (token == null || token.isEmpty) return;
//     try {
//       final res = await createStripeDepositIntent(
//         token,
//         amount: amount,
//         paymentMethodId: paymentMethodId,
//       );
//       if (!mounted) return;
//       final clientSecret = (res['clientSecret'] ?? '').toString();
//       if (clientSecret.isEmpty) {
//         showSnack(context, 'Deposit intent did not return a client secret');
//         return;
//       }

//       await Stripe.instance.initPaymentSheet(
//         paymentSheetParameters: SetupPaymentSheetParameters(
//           paymentIntentClientSecret: clientSecret,
//           merchantDisplayName: kAppName,
//           allowsDelayedPaymentMethods: true,
//         ),
//       );
//       await Stripe.instance.presentPaymentSheet();
//       if (!mounted) return;

//       showSnack(context, 'Payment submitted. Wallet will update after confirmation.');
//       await _refresh();
//     } catch (e) {
//       if (mounted) showSnack(context, _publicError(e));
//     }
//   }

//   Future<void> _depositWithMobileWallet(
//     double amount,
//   ) async {
//     final auth = context.read<AuthController>();
//     final token = auth.token;
//     if (token == null || token.isEmpty) return;
//     try {
//       final res = await createModernPayDepositIntent(
//         token,
//         amount: amount,
//         clientRequestId: DateTime.now().millisecondsSinceEpoch.toString(),
//       );
//       if (!mounted) return;
//       final checkoutUrl = (res['checkoutUrl'] ?? '').toString();
//       final transferId = (res['transferId'] ?? '').toString();
//       if (checkoutUrl.isEmpty || transferId.isEmpty) {
//         showSnack(context, 'Unable to start mobile wallet checkout');
//         return;
//       }

//       await launchUrl(Uri.parse(checkoutUrl), mode: LaunchMode.externalApplication);
//       if (!mounted) return;

//       final shouldConfirm = await showDialog<bool>(
//         context: context,
//         builder: (context) => AlertDialog(
//           title: const Text('Confirm Mobile Payment'),
//           content: const Text(
//             'After completing the payment in Modem Pay, tap confirm to credit your wallet.',
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(context, false),
//               child: const Text('Later'),
//             ),
//             FilledButton(
//               onPressed: () => Navigator.pop(context, true),
//               child: const Text('Confirm now'),
//             ),
//           ],
//         ),
//       );
//       if (shouldConfirm != true || !mounted) return;

//       final confirmed = await confirmModernPayDeposit(token, transferId: transferId);
//       if (!mounted) return;
//       final status = (confirmed['status'] ?? '').toString();
//       if (status == 'SUCCEEDED') {
//         showSnack(context, 'Wallet credited successfully.');
//         await _refresh();
//         return;
//       }
//       if (status == 'FAILED' || status == 'CANCELED') {
//         showSnack(context, 'Mobile wallet payment was not successful.');
//         return;
//       }
//       showSnack(context, 'Payment is still processing. Please confirm again shortly.');
//     } catch (e) {
//       if (mounted) showSnack(context, _publicError(e));
//     }
//   }

//   Future<void> _addFunds() async {
//     final source = await showDialog<String>(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Add funds'),
//         content: const Text('Select how you want to deposit money into your wallet.'),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('Cancel'),
//           ),
//           OutlinedButton(
//             onPressed: () => Navigator.pop(context, 'mobile'),
//             child: const Text('Mobile wallet'),
//           ),
//           FilledButton(
//             onPressed: () => Navigator.pop(context, 'card'),
//             child: const Text('Card'),
//           ),
//         ],
//       ),
//     );
//     if (!mounted || source == null) return;

//     final options = _methods.where((m) => m['provider'] == 'STRIPE').toList();
//     if (source == 'card' && options.isEmpty) {
//       showSnack(
//         context,
//         'Add a card first.',
//       );
//       return;
//     }

//     String? selectedMethod;
//     if (source != 'mobile') {
//       selectedMethod = await showDialog<String>(
//         context: context,
//         builder: (context) => _MethodSelectionDialog(
//           title: 'Select card',
//           methods: options,
//         ),
//       );
//       if (!mounted || selectedMethod == null) return;
//     }

//     final amountController = TextEditingController();
//     final amountRaw = await showDialog<String>(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Deposit amount'),
//         content: TextField(
//           controller: amountController,
//           keyboardType: const TextInputType.numberWithOptions(decimal: true),
//           decoration: const InputDecoration(
//             labelText: 'Amount (GMD)',
//             hintText: 'e.g. 250',
//           ),
//         ),
//         actions: [
//           TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
//           FilledButton(
//             onPressed: () => Navigator.pop(context, amountController.text.trim()),
//             child: const Text('Continue'),
//           ),
//         ],
//       ),
//     );
//     if (!mounted || amountRaw == null || amountRaw.isEmpty) return;
//     final amount = double.tryParse(amountRaw);
//     if (amount == null || amount <= 0) {
//       showSnack(context, 'Invalid amount');
//       return;
//     }

//     if (source == 'mobile') {
//       await _depositWithMobileWallet(amount);
//     } else {
//       await _depositWithStripe(amount, selectedMethod!);
//     }
//   }

//   Future<void> _requestPayout() async {
//     final auth = context.read<AuthController>();
//     final token = auth.token;
//     if (token == null || token.isEmpty) return;

//     final controller = TextEditingController();
//     final amountRaw = await showDialog<String>(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Withdraw funds'),
//         content: TextField(
//           controller: controller,
//           keyboardType: const TextInputType.numberWithOptions(decimal: true),
//           decoration: const InputDecoration(
//             labelText: 'Amount (GMD)',
//             hintText: 'e.g. 100',
//           ),
//         ),
//         actions: [
//           TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
//           FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Request')),
//         ],
//       ),
//     );
//     if (!mounted) return;
//     if (amountRaw == null || amountRaw.isEmpty) return;
//     final amount = double.tryParse(amountRaw);
//     if (amount == null || amount <= 0) {
//       showSnack(context, 'Invalid amount');
//       return;
//     }

//     try {
//       await requestPayout(
//         token,
//         amount: amount,
//         provider: 'MODERNPAY',
//         providerPayload: {'note': 'MVP: payout execution not wired yet'},
//       );
//       if (!mounted) return;
//       showSnack(context, 'Payout requested (processing).');
//       await _refresh();
//     } catch (e) {
//       if (mounted) showSnack(context, _publicError(e));
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);
//     final cardMethods = _methods.where((m) => m['provider'] == 'STRIPE').toList();
//     final mobileMethods =
//         _methods.where((m) => m['provider'] == 'MODERNPAY').toList();
//     final totalDeposited = double.tryParse(_stats.totalDeposited) ?? 0;
//     final totalWithdrawn = double.tryParse(_stats.totalWithdrawn) ?? 0;

//     return Scaffold(
//       appBar: AppBar(title: const Text('Wallet')),
//       body: Stack(
//         fit: StackFit.expand,
//         children: [
//           const DecoratedBox(
//             decoration: BoxDecoration(gradient: AppColors.pageBackground),
//             child: SizedBox.expand(),
//           ),
//           SafeArea(
//             child: RefreshIndicator(
//               onRefresh: _refresh,
//               child: ListView(
//                 physics: const AlwaysScrollableScrollPhysics(),
//                 padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
//                 children: [
//           // Web-parity hero wallet card
//           Container(
//             margin: const EdgeInsets.only(bottom: 16),
//             decoration: BoxDecoration(
//               color: AppColors.gambianBlue,
//               borderRadius: BorderRadius.circular(18),
//               boxShadow: [
//                 BoxShadow(
//                   color: AppColors.gambianBlue.withValues(alpha: 0.35),
//                   blurRadius: 22,
//                   offset: const Offset(0, 10),
//                 ),
//               ],
//             ),
//             child: Stack(
//               children: [
//                 Positioned(
//                   right: 10,
//                   top: 10,
//                   child: IconButton(
//                     onPressed: _loading ? null : _refresh,
//                     icon: Icon(
//                       Icons.refresh,
//                       color: Colors.white.withValues(alpha: 0.9),
//                     ),
//                   ),
//                 ),
//                 Padding(
//                   padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         'Available Balance',
//                         style: TextStyle(
//                           color: Colors.white.withValues(alpha: 0.75),
//                           fontWeight: FontWeight.w600,
//                           fontSize: 13,
//                           height: 1.2,
//                         ),
//                       ),
//                       const SizedBox(height: 8),
//                       Text(
//                         '$kCurrencyPrefix$_balance',
//                         style: const TextStyle(
//                           color: Colors.white,
//                           fontSize: 26,
//                           fontWeight: FontWeight.w800,
//                           letterSpacing: -0.5,
//                           height: 1.05,
//                           decoration: TextDecoration.none,
//                         ),
//                       ),
//                       const SizedBox(height: 8),
//                       Wrap(
//                         spacing: 10,
//                         runSpacing: 6,
//                         children: [
//                           _MiniCount(text: '${cardMethods.length} cards'),
//                           _MiniCount(text: '${mobileMethods.length} mobile'),
//                           _MiniCount(text: '${_stats.transferCount} transactions'),
//                         ],
//                       ),
//                       const SizedBox(height: 14),
//                       Row(
//                         children: [
//                           Expanded(
//                             child: FilledButton(
//                               onPressed: _loading ? null : _addFunds,
//                               style: FilledButton.styleFrom(
//                                 backgroundColor: AppColors.gambianGold,
//                                 foregroundColor: const Color(0xFF3A2A00),
//                                 padding:
//                                     const EdgeInsets.symmetric(vertical: 12),
//                               ),
//                               child: const Text('Deposit'),
//                             ),
//                           ),
//                           const SizedBox(width: 10),
//                           Expanded(
//                             child: OutlinedButton(
//                               onPressed: _loading ? null : _requestPayout,
//                               style: OutlinedButton.styleFrom(
//                                 foregroundColor: Colors.white,
//                                 side: BorderSide(
//                                   color: Colors.white.withValues(alpha: 0.35),
//                                 ),
//                                 padding:
//                                     const EdgeInsets.symmetric(vertical: 12),
//                               ),
//                               child: const Text('Withdraw'),
//                             ),
//                           ),
//                         ],
//                       ),
//                       const SizedBox(height: 14),
//                       Row(
//                         children: [
//                           Expanded(
//                             child: _StatPill(
//                               label: 'Total Deposited',
//                               value:
//                                   '$kCurrencyPrefix${totalDeposited.toStringAsFixed(2)}',
//                             ),
//                           ),
//                           const SizedBox(width: 10),
//                           Expanded(
//                             child: _StatPill(
//                               label: 'Total Withdrawn',
//                               value:
//                                   '$kCurrencyPrefix${totalWithdrawn.toStringAsFixed(2)}',
//                             ),
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ),

//           SegmentedButton<int>(
//             style: ButtonStyle(
//               visualDensity: VisualDensity.compact,
//               padding: WidgetStateProperty.all(
//                 const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
//               ),
//               foregroundColor: WidgetStateProperty.resolveWith(
//                 (s) =>
//                     s.contains(WidgetState.selected) ? Colors.white : Colors.grey.shade800,
//               ),
//               backgroundColor: WidgetStateProperty.resolveWith(
//                 (s) => s.contains(WidgetState.selected)
//                     ? AppColors.gambianBlue
//                     : Colors.white.withValues(alpha: 0.92),
//               ),
//               side: WidgetStateProperty.all(BorderSide(color: Colors.grey.shade300)),
//             ),
//             segments: const [
//               ButtonSegment(value: 0, label: Text('Overview')),
//               ButtonSegment(value: 1, label: Text('Transactions')),
//             ],
//             selected: {_activeTabIndex},
//             onSelectionChanged: (selection) {
//               setState(() => _activeTabIndex = selection.first);
//             },
//           ),
//           const SizedBox(height: 12),
//           if (_activeTabIndex == 0) ...[
//             Row(
//               children: [
//                 Expanded(
//                   child: Text(
//                     'Payment Methods',
//                     style: theme.textTheme.titleMedium?.copyWith(
//                       fontWeight: FontWeight.w800,
//                       color: Colors.grey.shade900,
//                     ),
//                   ),
//                 ),
//                 const SizedBox(width: 8),
//                 OutlinedButton.icon(
//                   onPressed: _loading ? null : _addCard,
//                   icon: const Icon(Icons.credit_card, size: 18),
//                   label: const Text('Add Card'),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 10),
//             if (_methods.isEmpty)
//               GlassCard(
//                 padding: const EdgeInsets.all(18),
//                 child: Text(
//                   'No payment methods yet. Add a card to start transacting.',
//                   style: theme.textTheme.bodyMedium?.copyWith(
//                     fontSize: 14,
//                     height: 1.4,
//                     color: Colors.grey.shade700,
//                   ),
//                 ),
//               )
//             else
//               ..._methods.map(
//                 (m) => Padding(
//                   padding: const EdgeInsets.only(bottom: 8),
//                   child: GlassCard(
//                     child: Row(
//                       children: [
//                         Icon(
//                           (m['provider'] == 'STRIPE') ? Icons.credit_card : Icons.phone_iphone,
//                           color: AppColors.gambianBlue,
//                         ),
//                         const SizedBox(width: 10),
//                         Expanded(
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Text(
//                                 (m['label'] ?? '').toString().isEmpty ? 'Payment method' : (m['label'] ?? '').toString(),
//                                 style: const TextStyle(fontWeight: FontWeight.w600),
//                               ),
//                               const SizedBox(height: 2),
//                               Text(
//                                 m['provider'] == 'STRIPE'
//                                     ? '${m['brand'] ?? 'card'} •••• ${m['last4'] ?? ''}'
//                                     : (m['msisdn'] ?? '').toString(),
//                                 style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
//                               ),
//                             ],
//                           ),
//                         ),
//                         Text(
//                           (m['provider'] ?? '').toString(),
//                           style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ),
//           ] else ...[
//             Text(
//               'All Transactions',
//               style: theme.textTheme.titleMedium?.copyWith(
//                 fontWeight: FontWeight.w800,
//                 color: Colors.grey.shade900,
//               ),
//             ),
//             const SizedBox(height: 10),
//             if (_transfers.isEmpty)
//               GlassCard(
//                 padding: const EdgeInsets.all(18),
//                 child: Text(
//                   'No transactions yet.',
//                   style: theme.textTheme.bodyMedium?.copyWith(
//                     fontSize: 14,
//                     height: 1.4,
//                     color: Colors.grey.shade700,
//                   ),
//                 ),
//               )
//             else
//               ..._transfers.map(
//                 (t) => Padding(
//                   padding: const EdgeInsets.only(bottom: 8),
//                   child: GlassCard(
//                     child: Row(
//                       children: [
//                         Icon(
//                           t.kind == 'DEPOSIT'
//                               ? Icons.north_east
//                               : Icons.south_west,
//                           color: t.kind == 'DEPOSIT'
//                               ? AppColors.gambianGreen
//                               : AppColors.gambianRed,
//                         ),
//                         const SizedBox(width: 10),
//                         Expanded(
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Text(
//                                 '${t.kind == 'DEPOSIT' ? 'Deposit' : 'Withdrawal'} via ${t.provider}',
//                                 style:
//                                     const TextStyle(fontWeight: FontWeight.w700),
//                               ),
//                               const SizedBox(height: 2),
//                               Text(
//                                 '${t.createdAt.toLocal()}',
//                                 style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
//                               ),
//                             ],
//                           ),
//                         ),
//                         Text(
//                           '${t.kind == 'DEPOSIT' ? '+' : '-'}$kCurrencyPrefix${t.amount}',
//                           style: const TextStyle(fontWeight: FontWeight.w800),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ),
//           ],
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _MiniCount extends StatelessWidget {
//   const _MiniCount({required this.text});
//   final String text;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
//       decoration: BoxDecoration(
//         color: Colors.white.withValues(alpha: 0.08),
//         borderRadius: BorderRadius.circular(999),
//         border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
//       ),
//       child: Text(
//         text,
//         style: TextStyle(
//           color: Colors.white.withValues(alpha: 0.8),
//           fontWeight: FontWeight.w600,
//           fontSize: 12,
//         ),
//       ),
//     );
//   }
// }

// class _StatPill extends StatelessWidget {
//   const _StatPill({required this.label, required this.value});
//   final String label;
//   final String value;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: Colors.white.withValues(alpha: 0.08),
//         borderRadius: BorderRadius.circular(14),
//         border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             label,
//             style: TextStyle(
//               color: Colors.white.withValues(alpha: 0.65),
//               fontSize: 11,
//               fontWeight: FontWeight.w600,
//             ),
//           ),
//           const SizedBox(height: 6),
//           Text(
//             value,
//             style: const TextStyle(
//               color: Colors.white,
//               fontSize: 16,
//               fontWeight: FontWeight.w800,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _MethodSelectionDialog extends StatelessWidget {
//   const _MethodSelectionDialog({
//     required this.title,
//     required this.methods,
//   });

//   final String title;
//   final List<Map<String, dynamic>> methods;

//   @override
//   Widget build(BuildContext context) {
//     return AlertDialog(
//       title: Text(title),
//       content: SizedBox(
//         width: 420,
//         child: methods.isEmpty
//             ? const Text('No methods available')
//             : ListView.builder(
//                 shrinkWrap: true,
//                 itemCount: methods.length,
//                 itemBuilder: (context, index) {
//                   final m = methods[index];
//                   final isStripe = m['provider'] == 'STRIPE';
//                   final subtitle = isStripe
//                       ? '${m['brand'] ?? 'card'} •••• ${m['last4'] ?? ''}'
//                       : (m['msisdn'] ?? m['modernpayMsisdn'] ?? '').toString();
//                   final title = (m['label'] ?? '').toString().isEmpty
//                       ? (isStripe ? 'Card' : 'Mobile wallet')
//                       : (m['label'] ?? '').toString();
//                   return ListTile(
//                     leading: Icon(isStripe ? Icons.credit_card : Icons.phone_iphone),
//                     title: Text(title),
//                     subtitle: Text(subtitle),
//                     onTap: () => Navigator.pop(context, (m['id'] ?? '').toString()),
//                   );
//                 },
//               ),
//       ),
//       actions: [
//         TextButton(
//           onPressed: () => Navigator.pop(context),
//           child: const Text('Cancel'),
//         ),
//       ],
//     );
//   }
// }
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/escrow_api.dart';
import '../auth/auth_controller.dart';
import '../config/constants.dart';
import '../models/wallet_models.dart';
import '../theme/app_colors.dart';
import '../utils/snackbar.dart';
import '../widgets/glass_card.dart';

class BillingsScreen extends StatelessWidget {
  const BillingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _WalletBody();
  }
}

// ─────────────────────────────────────────────
// State
// ─────────────────────────────────────────────

class _WalletBody extends StatefulWidget {
  const _WalletBody();

  @override
  State<_WalletBody> createState() => _WalletBodyState();
}

class _WalletBodyState extends State<_WalletBody>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  int _activeTabIndex = 0;
  String _balance = '0';
  List<Map<String, dynamic>> _methods = const [];
  List<WalletTransferSummary> _transfers = const [];
  List<WalletLedgerEntry> _ledger = const [];
  WalletTransferStats _stats = WalletTransferStats(
    transferCount: 0,
    totalDeposited: '0',
    totalWithdrawn: '0',
  );

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  String _publicError(Object error) {
    final lowered = error.toString().toLowerCase();
    if (lowered.contains('secret') ||
        lowered.contains('token') ||
        lowered.contains('apikey') ||
        lowered.contains('database_url')) {
      return 'Payment request failed. Please try again.';
    }
    return error.toString();
  }

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _refresh();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final auth = context.read<AuthController>();
    final token = auth.token;
    if (token == null || token.isEmpty) return;
    setState(() => _loading = true);
    _fadeCtrl.reset();
    try {
      final wallet = await getWallet(token);
      final methods = await listPaymentMethods(token);
      final stats = await getWalletTransferStats(token);
      final transfers = await getWalletTransfers(token, limit: 200);
      final ledger = await getWalletLedger(token, limit: 200);
      setState(() {
        _balance = wallet.balance;
        _ledger = ledger;
        _methods = methods
            .map((m) => {
                  'id': m.id,
                  'label': m.label,
                  'provider': m.provider,
                  'type': m.type,
                  'last4': m.last4,
                  'brand': m.brand,
                  'msisdn': m.msisdn,
                })
            .toList();
        _transfers = transfers;
        _stats = stats;
      });
      _fadeCtrl.forward();
    } catch (e) {
      if (mounted) showSnack(context, _publicError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Payment method actions ────────────────

  Future<void> _addCard() async {
    final auth = context.read<AuthController>();
    final token = auth.token;
    if (token == null || token.isEmpty) return;
    try {
      final cfg = await getEscrowConfig(token);
      if (!mounted) return;
      final pk = (cfg['stripePublishableKey'] ?? '').toString().trim();
      if (pk.isEmpty) {
        showSnack(context, 'Card payments are unavailable');
        return;
      }
      Stripe.publishableKey = pk;
      final setup = await createStripeSetupIntent(token);
      if (!mounted) return;
      final clientSecret = (setup['clientSecret'] ?? '').toString();
      final setupIntentId = (setup['setupIntentId'] ?? '').toString();
      if (clientSecret.isEmpty || setupIntentId.isEmpty) {
        showSnack(context, 'Unable to initialise card setup');
        return;
      }
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          setupIntentClientSecret: clientSecret,
          merchantDisplayName: kAppName,
        ),
      );
      await Stripe.instance.presentPaymentSheet();
      if (!mounted) return;
      await completeStripeSetupIntent(token, setupIntentId: setupIntentId);
      if (!mounted) return;
      showSnack(context, 'Card added successfully');
      await _refresh();
    } catch (e) {
      if (mounted) showSnack(context, _publicError(e));
    }
  }

  Future<void> _depositWithStripe(
      double amount, String paymentMethodId) async {
    final token = context.read<AuthController>().token;
    if (token == null || token.isEmpty) return;
    try {
      final res = await createStripeDepositIntent(token,
          amount: amount, paymentMethodId: paymentMethodId);
      if (!mounted) return;
      final clientSecret = (res['clientSecret'] ?? '').toString();
      if (clientSecret.isEmpty) {
        showSnack(context, 'Deposit intent did not return a client secret');
        return;
      }
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: kAppName,
          allowsDelayedPaymentMethods: true,
        ),
      );
      await Stripe.instance.presentPaymentSheet();
      if (!mounted) return;
      showSnack(
          context, 'Payment submitted. Wallet will update after confirmation.');
      await _refresh();
    } catch (e) {
      if (mounted) showSnack(context, _publicError(e));
    }
  }

  Future<void> _depositWithMobileWallet(double amount) async {
    final token = context.read<AuthController>().token;
    if (token == null || token.isEmpty) return;
    try {
      final res = await createModernPayDepositIntent(token,
          amount: amount,
          clientRequestId:
              DateTime.now().millisecondsSinceEpoch.toString());
      if (!mounted) return;
      final checkoutUrl = (res['checkoutUrl'] ?? '').toString();
      final transferId = (res['transferId'] ?? '').toString();
      if (checkoutUrl.isEmpty || transferId.isEmpty) {
        showSnack(context, 'Unable to start mobile wallet checkout');
        return;
      }
      await launchUrl(Uri.parse(checkoutUrl),
          mode: LaunchMode.externalApplication);
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => _ConfirmDialog(
          title: 'Confirm Mobile Payment',
          body:
              'After completing the payment in Modem Pay, tap Confirm to credit your wallet.',
          confirmLabel: 'Confirm',
          cancelLabel: 'Later',
        ),
      );
      if (confirmed != true || !mounted) return;
      final result =
          await confirmModernPayDeposit(token, transferId: transferId);
      if (!mounted) return;
      final status = (result['status'] ?? '').toString();
      if (status == 'SUCCEEDED') {
        showSnack(context, 'Wallet credited successfully.');
        await _refresh();
        return;
      }
      if (status == 'FAILED' || status == 'CANCELED') {
        showSnack(context, 'Mobile wallet payment was not successful.');
        return;
      }
      showSnack(
          context, 'Payment is still processing. Please confirm again shortly.');
    } catch (e) {
      if (mounted) showSnack(context, _publicError(e));
    }
  }

  Future<void> _addFunds() async {
    final source = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _DepositSourceSheet(),
    );
    if (!mounted || source == null) return;

    final stripeOptions =
        _methods.where((m) => m['provider'] == 'STRIPE').toList();
    if (source == 'card' && stripeOptions.isEmpty) {
      showSnack(context, 'Add a card first before depositing.');
      return;
    }

    String? selectedMethod;
    if (source == 'card') {
      selectedMethod = await showDialog<String>(
        context: context,
        builder: (ctx) => _MethodSelectionDialog(
          title: 'Select card',
          methods: stripeOptions,
        ),
      );
      if (!mounted || selectedMethod == null) return;
    }

    final amount = await showDialog<double>(
      context: context,
      builder: (ctx) => _AmountDialog(
        title: 'Deposit amount',
        hint: 'e.g. 250',
        currency: 'GMD',
      ),
    );
    if (!mounted || amount == null) return;

    if (source == 'mobile') {
      await _depositWithMobileWallet(amount);
    } else {
      await _depositWithStripe(amount, selectedMethod!);
    }
  }

  Future<void> _requestPayout() async {
    final token = context.read<AuthController>().token;
    if (token == null || token.isEmpty) return;

    final amount = await showDialog<double>(
      context: context,
      builder: (ctx) => _AmountDialog(
        title: 'Withdraw funds',
        hint: 'e.g. 100',
        currency: 'GMD',
      ),
    );
    if (!mounted || amount == null) return;

    try {
      await requestPayout(token,
          amount: amount,
          provider: 'MODERNPAY',
          providerPayload: {'note': 'MVP: payout execution not wired yet'});
      if (!mounted) return;
      showSnack(context, 'Payout requested (processing).');
      await _refresh();
    } catch (e) {
      if (mounted) showSnack(context, _publicError(e));
    }
  }

  // ── Build ─────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardMethods =
        _methods.where((m) => m['provider'] == 'STRIPE').toList();
    final mobileMethods =
        _methods.where((m) => m['provider'] == 'MODERNPAY').toList();
    final totalDeposited = double.tryParse(_stats.totalDeposited) ?? 0;
    final totalWithdrawn = double.tryParse(_stats.totalWithdrawn) ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Wallet',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: Color(0xFF0D1B3E),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _RefreshIconButton(
              loading: _loading,
              onPressed: _refresh,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.gambianBlue,
        onRefresh: _refresh,
        child: FadeTransition(
          opacity: _loading ? const AlwaysStoppedAnimation(1) : _fadeAnim,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              // ── Hero balance card ──────────────
              _HeroCard(
                balance: _balance,
                cardCount: cardMethods.length,
                mobileCount: mobileMethods.length,
                txCount: _stats.transferCount,
                totalDeposited: totalDeposited,
                totalWithdrawn: totalWithdrawn,
                loading: _loading,
                onDeposit: _addFunds,
                onWithdraw: _requestPayout,
              ),

              const SizedBox(height: 20),

              // ── Tab toggle ────────────────────
              _TabToggle(
                activeIndex: _activeTabIndex,
                onChanged: (i) => setState(() => _activeTabIndex = i),
              ),

              const SizedBox(height: 16),

              // ── Tab bodies ────────────────────
              if (_activeTabIndex == 0)
                _OverviewTab(
                  methods: _methods,
                  loading: _loading,
                  onAddCard: _addCard,
                  theme: theme,
                )
              else
                _TransactionsTab(
                  transfers: _transfers,
                  ledger: _ledger,
                  loading: _loading,
                  theme: theme,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Hero card
// ─────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.balance,
    required this.cardCount,
    required this.mobileCount,
    required this.txCount,
    required this.totalDeposited,
    required this.totalWithdrawn,
    required this.loading,
    required this.onDeposit,
    required this.onWithdraw,
  });

  final String balance;
  final int cardCount;
  final int mobileCount;
  final int txCount;
  final double totalDeposited;
  final double totalWithdrawn;
  final bool loading;
  final VoidCallback onDeposit;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A2463), Color(0xFF1A3A7A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A2463).withValues(alpha: 0.40),
            blurRadius: 32,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Subtle geometric accent
          Positioned(
            top: -30,
            right: -30,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            bottom: -20,
            left: -20,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Label
                Text(
                  'Available Balance',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                // Balance
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      kCurrencyPrefix,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      balance,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                        height: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Chips
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _Chip(label: '$cardCount card${cardCount == 1 ? '' : 's'}'),
                    _Chip(
                        label:
                            '$mobileCount mobile${mobileCount == 1 ? '' : 's'}'),
                    _Chip(label: '$txCount transactions'),
                  ],
                ),
                const SizedBox(height: 20),
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: _HeroButton(
                        label: 'Deposit',
                        icon: Icons.add_rounded,
                        filled: true,
                        onPressed: loading ? null : onDeposit,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _HeroButton(
                        label: 'Withdraw',
                        icon: Icons.south_rounded,
                        filled: false,
                        onPressed: loading ? null : onWithdraw,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Stat pills
                Row(
                  children: [
                    Expanded(
                      child: _StatPill(
                        label: 'Total Deposited',
                        value:
                            '$kCurrencyPrefix${totalDeposited.toStringAsFixed(2)}',
                        icon: Icons.north_east_rounded,
                        iconColor: const Color(0xFF4CAF50),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatPill(
                        label: 'Total Withdrawn',
                        value:
                            '$kCurrencyPrefix${totalWithdrawn.toStringAsFixed(2)}',
                        icon: Icons.south_west_rounded,
                        iconColor: const Color(0xFFFF6B6B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.82),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _HeroButton extends StatelessWidget {
  const _HeroButton({
    required this.label,
    required this.icon,
    required this.filled,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    if (filled) {
      return FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.gambianGold,
          foregroundColor: const Color(0xFF2A1A00),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
        textStyle:
            const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        padding: const EdgeInsets.symmetric(vertical: 13),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Tab toggle
// ─────────────────────────────────────────────

class _TabToggle extends StatelessWidget {
  const _TabToggle({required this.activeIndex, required this.onChanged});

  final int activeIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EBF2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          _TabPill(
            label: 'Overview',
            active: activeIndex == 0,
            onTap: () => onChanged(0),
          ),
          _TabPill(
            label: 'Transactions',
            active: activeIndex == 1,
            onTap: () => onChanged(1),
          ),
        ],
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: active ? AppColors.gambianBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : const Color(0xFF8892A4),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Overview tab
// ─────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.methods,
    required this.loading,
    required this.onAddCard,
    required this.theme,
  });

  final List<Map<String, dynamic>> methods;
  final bool loading;
  final VoidCallback onAddCard;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Payment Methods',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0D1B3E),
                letterSpacing: -0.2,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: loading ? null : onAddCard,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Add Card'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.gambianBlue,
                textStyle: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (methods.isEmpty)
          _EmptyState(
            icon: Icons.credit_card_off_outlined,
            message: 'No payment methods yet.\nAdd a card to start transacting.',
          )
        else
          ...methods.map(
            (m) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _MethodTile(method: m),
            ),
          ),
      ],
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({required this.method});
  final Map<String, dynamic> method;

  @override
  Widget build(BuildContext context) {
    final isStripe = method['provider'] == 'STRIPE';
    final label = (method['label'] ?? '').toString().isEmpty
        ? (isStripe ? 'Card' : 'Mobile wallet')
        : (method['label'] ?? '').toString();
    final subtitle = isStripe
        ? '${method['brand'] ?? 'Card'} •••• ${method['last4'] ?? ''}'
        : (method['msisdn'] ?? '').toString();

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.gambianBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isStripe ? Icons.credit_card_rounded : Icons.phone_iphone_rounded,
              color: AppColors.gambianBlue,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFF0D1B3E))),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        color: Color(0xFF8892A4), fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.gambianBlue.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              (method['provider'] ?? '').toString(),
              style: TextStyle(
                color: AppColors.gambianBlue,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Transactions tab
// ─────────────────────────────────────────────

class _WalletActivityItem {
  const _WalletActivityItem({
    required this.id,
    required this.label,
    required this.createdAt,
    required this.signedAmount,
    this.status,
    required this.isEscrow,
  });

  final String id;
  final String label;
  final DateTime createdAt;
  final double signedAmount;
  final String? status;
  final bool isEscrow;
}

class _TransactionsTab extends StatelessWidget {
  const _TransactionsTab({
    required this.transfers,
    required this.ledger,
    required this.loading,
    required this.theme,
  });

  final List<WalletTransferSummary> transfers;
  final List<WalletLedgerEntry> ledger;
  final bool loading;
  final ThemeData theme;

  List<_WalletActivityItem> _activity() {
    final rows = <_WalletActivityItem>[
      ...transfers.map(
        (t) => _WalletActivityItem(
          id: 'transfer-${t.id}',
          label: t.kind == 'DEPOSIT'
              ? 'Deposit via ${t.provider}'
              : 'Withdrawal via ${t.provider}',
          createdAt: t.createdAt,
          signedAmount: t.kind == 'DEPOSIT'
              ? double.tryParse(t.amount) ?? 0
              : -(double.tryParse(t.amount) ?? 0),
          status: t.status,
          isEscrow: false,
        ),
      ),
      ...ledger.map(
        (e) => _WalletActivityItem(
          id: 'ledger-${e.id}',
          label: e.action,
          createdAt: e.createdAt,
          signedAmount: double.tryParse(e.amount) ?? 0,
          isEscrow: true,
        ),
      ),
    ];
    rows.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final activity = _activity();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'All Transactions',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0D1B3E),
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 10),
        if (activity.isEmpty)
          _EmptyState(
            icon: Icons.receipt_long_outlined,
            message: 'No transactions yet.',
          )
        else
          ...activity.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ActivityTile(item: item),
            ),
          ),
      ],
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.item});
  final _WalletActivityItem item;

  @override
  Widget build(BuildContext context) {
    final positive = item.signedAmount >= 0;
    final color = positive
        ? const Color(0xFF22C55E)
        : const Color(0xFFEF4444);
    final bgColor = color;
    final date = item.createdAt.toLocal();
    final dateStr =
        '${date.day}/${date.month}/${date.year}  ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: bgColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              item.isEscrow
                  ? Icons.swap_horiz_rounded
                  : (positive
                        ? Icons.north_east_rounded
                        : Icons.south_west_rounded),
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Color(0xFF0D1B3E),
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      dateStr,
                      style: const TextStyle(
                        color: Color(0xFF8892A4),
                        fontSize: 11,
                      ),
                    ),
                    if (item.status != null) ...[
                      const SizedBox(width: 8),
                      _StatusBadge(status: item.status!),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${positive ? '+' : '-'}$kCurrencyPrefix${item.signedAmount.abs().toStringAsFixed(2)}',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransferTile extends StatelessWidget {
  const _TransferTile({required this.transfer});
  final WalletTransferSummary transfer;

  @override
  Widget build(BuildContext context) {
    final isDeposit = transfer.kind == 'DEPOSIT';
    final color = isDeposit
        ? const Color(0xFF22C55E)
        : const Color(0xFFEF4444);
    final bgColor = isDeposit
        ? const Color(0xFF22C55E)
        : const Color(0xFFEF4444);

    final date = transfer.createdAt.toLocal();
    final dateStr =
        '${date.day}/${date.month}/${date.year}  ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: bgColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isDeposit
                  ? Icons.north_east_rounded
                  : Icons.south_west_rounded,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${isDeposit ? 'Deposit' : 'Withdrawal'} via ${transfer.provider}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Color(0xFF0D1B3E)),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(dateStr,
                        style: const TextStyle(
                            color: Color(0xFF8892A4), fontSize: 11)),
                    const SizedBox(width: 8),
                    _StatusBadge(status: transfer.status),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${isDeposit ? '+' : '-'}$kCurrencyPrefix${transfer.amount}',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  Color get _color {
    switch (status.toUpperCase()) {
      case 'SUCCEEDED':
        return const Color(0xFF22C55E);
      case 'FAILED':
      case 'CANCELED':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFFF59E0B);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: _color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 36, color: const Color(0xFFCDD2DE)),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF8892A4),
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RefreshIconButton extends StatelessWidget {
  const _RefreshIconButton(
      {required this.loading, required this.onPressed});
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: loading ? null : onPressed,
      icon: loading
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.gambianBlue,
              ),
            )
          : const Icon(Icons.refresh_rounded, color: Color(0xFF0D1B3E)),
      tooltip: 'Refresh',
    );
  }
}

// ─────────────────────────────────────────────
// Dialogs
// ─────────────────────────────────────────────

/// Generic confirm dialog
class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.cancelLabel,
  });

  final String title;
  final String body;
  final String confirmLabel;
  final String cancelLabel;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      content: Text(body,
          style: const TextStyle(color: Color(0xFF5A6478), height: 1.5)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.gambianBlue,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}

/// Amount entry dialog
class _AmountDialog extends StatefulWidget {
  const _AmountDialog({
    required this.title,
    required this.hint,
    required this.currency,
  });

  final String title;
  final String hint;
  final String currency;

  @override
  State<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<_AmountDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = double.tryParse(_ctrl.text.trim());
    if (amount == null || amount <= 0) return;
    Navigator.pop(context, amount);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(widget.title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          prefixText: '${widget.currency} ',
          hintText: widget.hint,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFDDE1EA)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: AppColors.gambianBlue, width: 2),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.gambianBlue,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Continue'),
        ),
      ],
    );
  }
}

/// Deposit source bottom sheet
class _DepositSourceSheet extends StatelessWidget {
  const _DepositSourceSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 22),
            decoration: BoxDecoration(
              color: const Color(0xFFDDE1EA),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const Text(
            'Add Funds',
            style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: Color(0xFF0D1B3E)),
          ),
          const SizedBox(height: 6),
          const Text(
            'Choose how you want to deposit money.',
            style: TextStyle(color: Color(0xFF8892A4), fontSize: 13),
          ),
          const SizedBox(height: 22),
          _SheetOption(
            icon: Icons.phone_iphone_rounded,
            label: 'Mobile Wallet',
            subtitle: 'Pay via Modem Pay',
            onTap: () => Navigator.pop(context, 'mobile'),
          ),
          const SizedBox(height: 10),
          _SheetOption(
            icon: Icons.credit_card_rounded,
            label: 'Credit / Debit Card',
            subtitle: 'Pay via Stripe',
            onTap: () => Navigator.pop(context, 'card'),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF8892A4))),
          ),
        ],
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  const _SheetOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE8EBF2)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.gambianBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.gambianBlue, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Color(0xFF0D1B3E))),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          color: Color(0xFF8892A4), fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: Color(0xFFCDD2DE)),
          ],
        ),
      ),
    );
  }
}

/// Method selection dialog (reused for card deposit)
class _MethodSelectionDialog extends StatelessWidget {
  const _MethodSelectionDialog({
    required this.title,
    required this.methods,
  });

  final String title;
  final List<Map<String, dynamic>> methods;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      content: SizedBox(
        width: 400,
        child: methods.isEmpty
            ? const Text('No methods available')
            : ListView.separated(
                shrinkWrap: true,
                itemCount: methods.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1),
                itemBuilder: (context, i) {
                  final m = methods[i];
                  final isStripe = m['provider'] == 'STRIPE';
                  final label = (m['label'] ?? '').toString().isEmpty
                      ? (isStripe ? 'Card' : 'Mobile wallet')
                      : (m['label'] ?? '').toString();
                  final sub = isStripe
                      ? '${m['brand'] ?? 'card'} •••• ${m['last4'] ?? ''}'
                      : (m['msisdn'] ?? '').toString();
                  return ListTile(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    leading: Icon(
                      isStripe
                          ? Icons.credit_card_rounded
                          : Icons.phone_iphone_rounded,
                      color: AppColors.gambianBlue,
                    ),
                    title: Text(label,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700)),
                    subtitle: Text(sub),
                    onTap: () => Navigator.pop(
                        context, (m['id'] ?? '').toString()),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}