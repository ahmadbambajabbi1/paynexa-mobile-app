import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/escrow_api.dart';
import '../auth/auth_controller.dart';
import '../config/constants.dart';
import '../models/wallet_models.dart';
import '../theme/app_colors.dart';
import '../utils/snackbar.dart';
import '../utils/currency.dart';
import '../utils/modempay_return_urls.dart';
import '../utils/pending_payment_resume.dart';
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
  bool _historyLoading = false;
  bool _balanceHidden = false;
  int _activeTabIndex = 0;
  String _balance = '0';
  String? _walletCurrency;
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
    final raw = error.toString();
    final lowered = raw.toLowerCase();
    if (error is PlatformException ||
        lowered.contains('secret') ||
        lowered.contains('token') ||
        lowered.contains('apikey') ||
        lowered.contains('database_url') ||
        lowered.contains('flutter_stripe') ||
        lowered.contains('initialization failed') ||
        lowered.contains('flutterfragmentactivity') ||
        lowered.contains('mainactivity')) {
      return 'Payment request failed. Please try again.';
    }
    return raw;
  }

  String _setupIntentIdFromClientSecret(String clientSecret) {
    final idx = clientSecret.indexOf('_secret_');
    if (idx <= 0) return '';
    return clientSecret.substring(0, idx);
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
    if (token == null || token.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    _fadeCtrl.reset();
    try {
      final results = await Future.wait<Object>([
        getWallet(token),
        listPaymentMethods(token),
        getWalletTransferStats(token),
      ]);
      final wallet = results[0] as WalletSummary;
      final methods = results[1] as List<PaymentMethodSummary>;
      final stats = results[2] as WalletTransferStats;
      if (!mounted) return;
      setState(() {
        _balance = wallet.balance;
        _walletCurrency = wallet.currency;
        _methods = methods
            .map(
              (m) => {
                'id': m.id,
                'label': m.label,
                'provider': m.provider,
                'type': m.type,
                'last4': m.last4,
                'brand': m.brand,
                'msisdn': m.msisdn,
              },
            )
            .toList();
        _stats = stats;
        _loading = false;
      });
      _fadeCtrl.forward();
      _refreshHistoryInBackground(token);
    } catch (e) {
      if (mounted) showSnack(context, _publicError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _refreshHistoryInBackground(String token) {
    _refreshHistory(token);
  }

  Future<void> _refreshHistory(String token) async {
    if (_historyLoading) return;
    setState(() => _historyLoading = true);
    try {
      final results = await Future.wait<Object>([
        getWalletTransfers(token, limit: 100),
        getWalletLedger(token, limit: 100),
      ]);
      if (!mounted) return;
      setState(() {
        _transfers = results[0] as List<WalletTransferSummary>;
        _ledger = results[1] as List<WalletLedgerEntry>;
      });
    } catch (e) {
      if (mounted) showSnack(context, _publicError(e));
    } finally {
      if (mounted) setState(() => _historyLoading = false);
    }
  }

  // ── Payment method actions ────────────────

  Future<void> _addCard() async {
    final token = context.read<AuthController>().token;
    if (token == null || token.isEmpty) return;

    setState(() => _loading = true);
    try {
      final config = await getEscrowConfig(token);
      final publishableKey = (config['stripePublishableKey'] ?? '')
          .toString()
          .trim();
      if (publishableKey.isEmpty) {
        if (!mounted) return;
        showSnack(context, 'Card payments are not configured yet.');
        return;
      }

      final setup = await createStripeSetupIntent(token);
      final clientSecret = (setup['clientSecret'] ?? '').toString();
      final setupIntentId = (setup['setupIntentId'] ?? '').toString().trim();
      final resolvedSetupIntentId = setupIntentId.isNotEmpty
          ? setupIntentId
          : _setupIntentIdFromClientSecret(clientSecret);
      if (clientSecret.isEmpty || resolvedSetupIntentId.isEmpty) {
        if (!mounted) return;
        showSnack(context, 'Unable to start card setup. Please try again.');
        return;
      }

      Stripe.publishableKey = publishableKey;
      await Stripe.instance.applySettings();
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          merchantDisplayName: kAppName,
          setupIntentClientSecret: clientSecret,
          returnURL: '$kDeepLinkScheme://stripe-redirect',
          allowsDelayedPaymentMethods: false,
        ),
      );
      await Stripe.instance.presentPaymentSheet();
      await completeStripeSetupIntent(
        token,
        setupIntentId: resolvedSetupIntentId,
      );
      if (!mounted) return;
      showSnack(context, 'Card saved successfully.');
      await _refresh();
    } on StripeException catch (e) {
      if (!mounted) return;
      final message = e.error.localizedMessage ?? 'Card setup was cancelled.';
      showSnack(context, message);
    } catch (e) {
      if (mounted) showSnack(context, _publicError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _depositWithStripe(double amount, String paymentMethodId) async {
    final token = context.read<AuthController>().token;
    if (token == null || token.isEmpty) return;
    try {
      final res = await confirmSavedCardStripeDeposit(
        token,
        amount: amount,
        paymentMethodId: paymentMethodId,
        clientRequestId: 'card-deposit-${DateTime.now().millisecondsSinceEpoch}',
      );
      if (!mounted) return;
      final credited = res['credited'] == true;
      final status = (res['status'] ?? '').toString().toUpperCase();
      if (credited || status == 'SUCCEEDED') {
        showSnack(context, 'Wallet credited successfully.');
        await _refresh();
        return;
      }
      showSnack(context, 'Card payment is $status. Please try again or use mobile wallet.');
      await _refresh();
    } catch (e) {
      if (mounted) showSnack(context, _publicError(e));
    }
  }

  Future<void> _depositWithMobileWallet(double amount) async {
    final token = context.read<AuthController>().token;
    if (token == null || token.isEmpty) return;
    try {
      PendingPaymentResume.save(
        context: 'billings',
        transactionId: '',
      );
      final urls = buildModernPayReturnUrls(context: 'billings');
      final res = await createModernPayDepositIntent(
        token,
        amount: amount,
        clientRequestId: DateTime.now().millisecondsSinceEpoch.toString(),
        returnUrl: urls.returnUrl,
        cancelUrl: urls.cancelUrl,
      );
      if (!mounted) return;
      final checkoutUrl = (res['checkoutUrl'] ?? '').toString();
      if (checkoutUrl.isEmpty) {
        showSnack(context, 'Unable to start mobile wallet checkout');
        return;
      }
      await launchUrl(
        Uri.parse(checkoutUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!mounted) return;
      showSnack(
        context,
        'Complete payment in Modem Pay. You will return to the app automatically.',
      );
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

    final stripeOptions = _methods
        .where((m) => m['provider'] == 'STRIPE')
        .toList();
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
        currency: _walletCurrency,
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
        currency: _walletCurrency,
      ),
    );
    if (!mounted || amount == null) return;

    try {
      await requestPayout(
        token,
        amount: amount,
        provider: 'MODERNPAY',
        providerPayload: {'note': 'MVP: payout execution not wired yet'},
      );
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
    final cardMethods = _methods
        .where((m) => m['provider'] == 'STRIPE')
        .toList();
    final mobileMethods = _methods
        .where((m) => m['provider'] == 'MODERNPAY')
        .toList();
    final totalDeposited = double.tryParse(_stats.totalDeposited) ?? 0;
    final totalWithdrawn = double.tryParse(_stats.totalWithdrawn) ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      // appBar: AppBar(
      //   backgroundColor: Colors.transparent,
      //   elevation: 0,
      //   centerTitle: false,
      //   // title: const Text(
      //   //   'Wallet',
      //   //   style: TextStyle(
      //   //     fontSize: 20,
      //   //     fontWeight: FontWeight.w800,
      //   //     letterSpacing: -0.4,
      //   //     color: Color(0xFF0D1B3E),
      //   //   ),
      //   // ),
      //   actions: [
      //     Padding(
      //       padding: const EdgeInsets.only(right: 8),
      //       child: _RefreshIconButton(
      //         loading: _loading,
      //         onPressed: _refresh,
      //       ),
      //     ),
      //   ],
      // ),
      body: RefreshIndicator(
        color: AppColors.primaryColorBlack,
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
                balanceHidden: _balanceHidden,
                cardCount: cardMethods.length,
                mobileCount: mobileMethods.length,
                txCount: _stats.transferCount,
                totalDeposited: totalDeposited,
                totalWithdrawn: totalWithdrawn,
                loading: _loading,
                onToggleBalance: () {
                  setState(() => _balanceHidden = !_balanceHidden);
                },
                onDeposit: _addFunds,
                onWithdraw: _requestPayout,
                currency: _walletCurrency,
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
                  loading: _historyLoading,
                  theme: theme,
                  currency: _walletCurrency,
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
    required this.balanceHidden,
    required this.cardCount,
    required this.mobileCount,
    required this.txCount,
    required this.totalDeposited,
    required this.totalWithdrawn,
    required this.loading,
    required this.onToggleBalance,
    required this.onDeposit,
    required this.onWithdraw,
    required this.currency,
  });

  final String balance;
  final bool balanceHidden;
  final int cardCount;
  final int mobileCount;
  final int txCount;
  final double totalDeposited;
  final double totalWithdrawn;
  final bool loading;
  final VoidCallback onToggleBalance;
  final VoidCallback onDeposit;
  final VoidCallback onWithdraw;
  final String? currency;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryColorBlack, AppColors.primaryColorBlack],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        // boxShadow: [
        //   BoxShadow(
        //     color:AppColors.primaryColorBlack,
        //     blurRadius: 32,
        //     offset: const Offset(0, 14),
        //   ),
        // ],
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
                color: AppColors.primaryColorBlack,
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
                color: AppColors.primaryColorBlack,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Label
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Available Balance',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: onToggleBalance,
                      visualDensity: VisualDensity.compact,
                      tooltip: balanceHidden ? 'Show balance' : 'Hide balance',
                      icon: Icon(
                        balanceHidden
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: Colors.white.withValues(alpha: 0.72),
                        size: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                // Balance
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (!balanceHidden) ...[
                      Text(
                        currencySymbol(currency),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Flexible(
                      child: Text(
                        balanceHidden ? '•••••••' : balance,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                          height: 1,
                        ),
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
                          '$mobileCount mobile${mobileCount == 1 ? '' : 's'}',
                    ),
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
                        loading: loading,
                        onPressed: loading ? null : onDeposit,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _HeroButton(
                        label: 'Withdraw',
                        icon: Icons.south_rounded,
                        filled: false,
                        loading: loading,
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
                            moneyText(totalDeposited, currency),
                        icon: Icons.north_east_rounded,
                        iconColor: const Color(0xFF4CAF50),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatPill(
                        label: 'Total Withdrawn',
                        value:
                            moneyText(totalWithdrawn, currency),
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
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
          width: 1,
        ),
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
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool filled;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    if (filled) {
      return FilledButton.icon(
        onPressed: onPressed,
        icon: loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon, size: 16),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.gambianGold,
          foregroundColor: const Color(0xFF2A1A00),
          disabledBackgroundColor: AppColors.gambianGold.withValues(
            alpha: 0.72,
          ),
          disabledForegroundColor: const Color(
            0xFF2A1A00,
          ).withValues(alpha: 0.72),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white.withValues(alpha: 0.68),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        padding: const EdgeInsets.symmetric(vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1,
        ),
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
            color: active ? AppColors.primaryColorBlack : Colors.transparent,
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
                foregroundColor: AppColors.primaryColorBlack,
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (methods.isEmpty)
          _EmptyState(
            icon: Icons.credit_card_off_outlined,
            message:
                'No payment methods yet.\nAdd a card to start transacting.',
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
              color: AppColors.primaryColorBlack.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isStripe ? Icons.credit_card_rounded : Icons.phone_iphone_rounded,
              color: AppColors.primaryColorBlack,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF0D1B3E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF8892A4),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryColorBlack.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              (method['provider'] ?? '').toString(),
              style: TextStyle(
                color: AppColors.primaryColorBlack,
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
    required this.currency,
  });

  final List<WalletTransferSummary> transfers;
  final List<WalletLedgerEntry> ledger;
  final bool loading;
  final ThemeData theme;
  final String? currency;

  bool _isEscrowLedger(WalletLedgerEntry entry) {
    if (entry.action.startsWith('Paid transaction') ||
        entry.action.startsWith('Received for transaction') ||
        entry.action.startsWith('Refunded for transaction') ||
        entry.action.startsWith('Refunded transaction')) {
      return true;
    }
    return false;
  }

  String _ledgerLabel(String action) {
    final parts = action.split(' — ').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      final title = parts[1];
      if (action.startsWith('Paid transaction')) return 'Escrow payment · $title';
      if (action.startsWith('Received for transaction')) return 'Escrow payout · $title';
      if (action.startsWith('Refunded for transaction') ||
          action.startsWith('Refunded transaction')) {
        return 'Escrow refund · $title';
      }
    }
    return action;
  }

  List<_WalletActivityItem> _activity() {
    final rows = transfers
        .map(
          (t) => _WalletActivityItem(
            id: 'transfer-${t.id}',
            label: _transferLabel(t),
            createdAt: t.createdAt,
            signedAmount: t.kind == 'DEPOSIT'
                ? double.tryParse(t.amount) ?? 0
                : -(double.tryParse(t.amount) ?? 0),
            status: t.status,
            isEscrow: false,
          ),
        )
        .toList();

    for (final entry in ledger) {
      if (!_isEscrowLedger(entry)) continue;
      rows.add(
        _WalletActivityItem(
          id: 'ledger-${entry.id}',
          label: _ledgerLabel(entry.action),
          createdAt: entry.createdAt,
          signedAmount: double.tryParse(entry.amount) ?? 0,
          isEscrow: true,
        ),
      );
    }

    rows.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return rows;
  }

  String _transferLabel(WalletTransferSummary transfer) {
    if (transfer.kind == 'DEPOSIT') {
      return transfer.provider == 'STRIPE'
          ? 'Deposited through card'
          : 'Deposited through mobile wallet';
    }
    if (transfer.kind == 'PAYOUT') return 'Withdrawn through Modem Pay';
    return transfer.kind;
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
        if (loading && activity.isEmpty)
          const _WalletTransactionsLoading()
        else if (activity.isEmpty)
          _EmptyState(
            icon: Icons.receipt_long_outlined,
            message: 'No transactions yet.',
          )
        else
          ...activity.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ActivityTile(item: item, currency: currency),
            ),
          ),
      ],
    );
  }
}

class _WalletTransactionsLoading extends StatelessWidget {
  const _WalletTransactionsLoading();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Center(
        child: Column(
          children: [
            SizedBox(
              height: 32,
              width: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppColors.primaryColorBlack,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Loading transactions...',
              style: TextStyle(
                color: Color(0xFF8892A4),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.item, required this.currency});
  final _WalletActivityItem item;
  final String? currency;

  @override
  Widget build(BuildContext context) {
    final positive = item.signedAmount >= 0;
    final color = positive ? const Color(0xFF22C55E) : const Color(0xFFEF4444);
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
            '${positive ? '+' : '-'}${moneyText(item.signedAmount.abs(), currency)}',
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
    final color = isDeposit ? const Color(0xFF22C55E) : const Color(0xFFEF4444);
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
              isDeposit ? Icons.north_east_rounded : Icons.south_west_rounded,
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
                    const SizedBox(width: 8),
                    _StatusBadge(status: transfer.status),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${isDeposit ? '+' : '-'}${moneyText(transfer.amount, transfer.currency)}',
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
  const _RefreshIconButton({required this.loading, required this.onPressed});
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
                color: AppColors.primaryColorBlack,
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
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
      ),
      content: Text(
        body,
        style: const TextStyle(color: Color(0xFF5A6478), height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryColorBlack,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
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
  final String? currency;

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
      title: Text(
        widget.title,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
      ),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          prefixText: currencySymbol(widget.currency).isEmpty ? null : '${currencySymbol(widget.currency)} ',
          hintText: widget.hint,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFDDE1EA)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.primaryColorBlack, width: 2),
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
            backgroundColor: AppColors.primaryColorBlack,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
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
              color: Color(0xFF0D1B3E),
            ),
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
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF8892A4)),
            ),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                color: AppColors.primaryColorBlack.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primaryColorBlack, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Color(0xFF0D1B3E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF8892A4),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFCDD2DE)),
          ],
        ),
      ),
    );
  }
}

/// Method selection dialog (reused for card deposit)
class _MethodSelectionDialog extends StatelessWidget {
  const _MethodSelectionDialog({required this.title, required this.methods});

  final String title;
  final List<Map<String, dynamic>> methods;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
      ),
      content: SizedBox(
        width: 400,
        child: methods.isEmpty
            ? const Text('No methods available')
            : ListView.separated(
                shrinkWrap: true,
                itemCount: methods.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
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
                      borderRadius: BorderRadius.circular(12),
                    ),
                    leading: Icon(
                      isStripe
                          ? Icons.credit_card_rounded
                          : Icons.phone_iphone_rounded,
                      color: AppColors.primaryColorBlack,
                    ),
                    title: Text(
                      label,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(sub),
                    onTap: () =>
                        Navigator.pop(context, (m['id'] ?? '').toString()),
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
