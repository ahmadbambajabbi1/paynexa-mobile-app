import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/service_marketplace_api.dart' as sm;
import '../auth/auth_controller.dart';
import '../theme/app_colors.dart';
import '../widgets/marketplace_booking_payment_sheet.dart';

/// Layout and copy aligned with [escrow_web] `marketplace/bookings/[id]/page.tsx` `Inner`.
class MarketplaceBookingDetailScreen extends StatefulWidget {
  const MarketplaceBookingDetailScreen({
    super.key,
    required this.bookingId,
    required this.initialMode,
    this.resumePaymentAfterDeposit = false,
  });

  final String bookingId;
  final String initialMode; // me | provider
  final bool resumePaymentAfterDeposit;

  @override
  State<MarketplaceBookingDetailScreen> createState() =>
      _MarketplaceBookingDetailScreenState();
}

class _MarketplaceBookingDetailScreenState
    extends State<MarketplaceBookingDetailScreen> {
  bool _loading = true;
  String? _err;
  Map<String, dynamic>? _booking;
  late String _mode;
  String _tab = 'overview';
  String? _busyAction;
  final TextEditingController _commentCtrl = TextEditingController();
  bool _depositResumeAttempted = false;

  static const _slate100 = Color(0xFFF1F5F9);
  static const _slate500 = Color(0xFF64748B);
  static const _slate600 = Color(0xFF475569);
  static const _slate700 = Color(0xFF334155);
  static const _slate900 = Color(0xFF0F172A);
  static const _cardShadow = BoxShadow(
    color: Color(0x0F000000),
    blurRadius: 8,
    offset: Offset(0, 2),
  );

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _load();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Set<String> _flags(Map<String, dynamic> b) {
    final raw = b['workflowFlags'];
    if (raw is! List) return {};
    return raw.whereType<String>().toSet();
  }

  /// Same narrative as escrow_web `stepSummary`.
  String _stepSummary(String mode, Map<String, dynamic> b) {
    final status = '${b['status'] ?? ''}';
    final flags = _flags(b);
    if (mode == 'provider') {
      if (!flags.contains('provider_reached'))
        return 'Mark arrived when you reach the location';
      if (!flags.contains('client_confirmed_reached')) {
        return 'Waiting for client to confirm your arrival';
      }
      if (!flags.contains('provider_finished'))
        return 'Service in progress — complete when done';
      if (status == 'COMPLETED')
        return 'Service completed — awaiting client payment';
      return status;
    }
    if (!flags.contains('provider_reached')) return 'Provider is on their way';
    if (!flags.contains('client_confirmed_reached'))
      return 'Confirm provider has arrived';
    if (!flags.contains('provider_finished')) return 'Service in progress';
    if (!flags.contains('client_completed_confirmed'))
      return 'Confirm service completion';
    if (status == 'PENDING_PAYMENT' && !flags.contains('funded'))
      return 'Payment required to finalize';
    if (flags.contains('funded')) return 'Booking paid and completed';
    return status;
  }

  List<({String action, String label, bool primary})> _actionsFor(
    String mode,
    String status,
    Set<String> flags,
  ) {
    if (mode == 'provider') {
      final canReach =
          !flags.contains('provider_reached') &&
          !flags.contains('provider_finished') &&
          (status == 'PENDING_PAYMENT' ||
              status == 'FUNDED' ||
              status == 'ACCEPTED');
      if (canReach) {
        return [
          (
            action: 'PROVIDER_REACHED',
            label: 'I have arrived at location',
            primary: true,
          ),
        ];
      }
      if (status == 'IN_PROGRESS' &&
          flags.contains('client_confirmed_reached') &&
          !flags.contains('provider_finished')) {
        return [
          (
            action: 'PROVIDER_FINISHED',
            label: 'Mark service as completed',
            primary: true,
          ),
        ];
      }
      return [];
    }
    if (status == 'IN_PROGRESS' &&
        flags.contains('provider_reached') &&
        !flags.contains('client_confirmed_reached')) {
      return [
        (
          action: 'CLIENT_CONFIRMED_REACHED',
          label: 'Confirm provider arrived',
          primary: false,
        ),
      ];
    }
    if (status == 'COMPLETED' &&
        flags.contains('provider_finished') &&
        !flags.contains('client_completed_confirmed')) {
      return [
        (
          action: 'CLIENT_CONFIRMED_COMPLETED',
          label: 'Confirm work is completed',
          primary: true,
        ),
      ];
    }
    if (status == 'PENDING_PAYMENT' &&
        flags.contains('client_completed_confirmed') &&
        !flags.contains('funded')) {
      return [
        (action: 'MARK_FUNDED', label: 'Confirm Payment Completed', primary: true),
      ];
    }
    return [];
  }

  String? _mapDirectionsUrl(Map<String, dynamic> b) {
    final lat = b['serviceLatitude'];
    final lng = b['serviceLongitude'];
    if (lat is num && lng is num) {
      return 'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent('${lat.toDouble()},${lng.toDouble()}')}';
    }
    final label = (b['serviceLocationLabel'] as String?)?.trim() ?? '';
    final addr = (b['serviceAddressText'] as String?)?.trim() ?? '';
    final q = label.isNotEmpty ? label : addr;
    if (q.isEmpty) return null;
    return 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(q)}';
  }

  Future<void> _load() async {
    final token = context.read<AuthController>().token;
    if (token == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _err = 'Sign in to view this booking.';
        });
      }
      return;
    }
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final mine = await sm.listMyServiceBookings(token: token);
      final provider = await sm.listProviderServiceBookings(token: token);
      final preferred = widget.initialMode == 'provider' ? provider : mine;
      final fallback = widget.initialMode == 'provider' ? mine : provider;
      final preferredMode = widget.initialMode == 'provider'
          ? 'provider'
          : 'me';
      final fallbackMode = widget.initialMode == 'provider' ? 'me' : 'provider';
      final preferredMatch = preferred
          .where((b) => '${b['id']}' == widget.bookingId)
          .toList();
      if (preferredMatch.isNotEmpty) {
        setState(() {
          _booking = preferredMatch.first;
          _mode = preferredMode;
        });
        return;
      }
      final fallbackMatch = fallback
          .where((b) => '${b['id']}' == widget.bookingId)
          .toList();
      if (fallbackMatch.isNotEmpty) {
        setState(() {
          _booking = fallbackMatch.first;
          _mode = fallbackMode;
        });
        return;
      }
      setState(() => _err = 'Booking not found.');
    } catch (e) {
      setState(() => _err = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
      if (widget.resumePaymentAfterDeposit &&
          !_depositResumeAttempted &&
          _booking != null) {
        _depositResumeAttempted = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _maybeResumePayment());
      }
    }
  }

  Future<void> _maybeResumePayment() async {
    if (!mounted) return;
    final b = _booking;
    if (b == null) return;
    final flags = _flags(b);
    if (flags.contains('client_paid') || '${b['status']}' == 'FUNDED') return;
    if (!flags.contains('provider_finished')) return;
    await _runAction('MARK_FUNDED');
  }

  Future<void> _runAction(String action) async {
    final token = context.read<AuthController>().token;
    if (token == null || _booking == null) return;
    if (action == 'MARK_FUNDED') {
      final listing = _booking?['listing'] as Map<String, dynamic>?;
      final provider = listing?['provider'] as Map<String, dynamic>?;
      final providerUserId = (provider?['userId'] ?? '').toString();
      if (providerUserId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Missing provider reference for this booking.'),
          ),
        );
        return;
      }

      final pb = BookingPaymentBreakdown.fromJson(
        _booking?['paymentBreakdown'],
      );
      final amt =
          (pb?.totalDueFromCustomer ??
                  double.tryParse('${_booking?['amount'] ?? ''}') ??
                  0)
              .toDouble();
      if (amt <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid booking amount.')),
        );
        return;
      }

      final paid = await showMarketplaceBookingPaymentSheet(
        context: context,
        bookingId: widget.bookingId,
        providerUserId: providerUserId,
        amount: amt,
        breakdown: pb,
      );
      if (!mounted) return;
      if (paid) {
        await _load();
      }
      return;
    }
    setState(() => _busyAction = action);
    try {
      await sm.updateBookingState(
        token: token,
        bookingId: '${_booking!['id']}',
        action: action,
      );
      if (!mounted) return;
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busyAction = null);
    }
  }

  Future<void> _postComment() async {
    final token = context.read<AuthController>().token;
    if (token == null || _booking == null) return;
    final note = _commentCtrl.text.trim();
    if (note.isEmpty) return;
    setState(() => _busyAction = 'COMMENT');
    try {
      await sm.updateBookingState(
        token: token,
        bookingId: '${_booking!['id']}',
        action: 'COMMENT',
        notes: note,
      );
      _commentCtrl.clear();
      if (!mounted) return;
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busyAction = null);
    }
  }

  Future<void> _submitReview(int rating, String comment) async {
    final token = context.read<AuthController>().token;
    if (token == null || _booking == null) return;
    setState(() => _busyAction = 'REVIEW');
    try {
      await sm.submitBookingReview(
        token: token,
        bookingId: '${_booking!['id']}',
        rating: rating,
        comment: comment,
      );
      if (!mounted) return;
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busyAction = null);
    }
  }

  bool _canLeaveReview(Map<String, dynamic> b, Map<String, dynamic>? review) {
    if (_mode == 'provider' || review != null) return false;
    final flags = _flags(b);
    final status = '${b['status'] ?? ''}';
    const ok = ['COMPLETED', 'PENDING_PAYMENT', 'FUNDED'];
    return flags.contains('provider_finished') && ok.contains(status);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppColors.primaryColorBlack,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading booking details...',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }
    if (_err != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(title: const Text('Booking')),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: _ErrorBanner(message: _err!),
        ),
      );
    }
    final b = _booking;
    if (b == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final listing = b['listing'] as Map<String, dynamic>?;
    final status = '${b['status'] ?? ''}';
    final flags = _flags(b);
    final actions = _actionsFor(_mode, status, flags);
    final mapUrl = _mapDirectionsUrl(b);
    final review = b['review'] as Map<String, dynamic>?;
    final comments = (b['bookingComments'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final canRate = _canLeaveReview(b, review);
    final isProviderView = _mode == 'provider';
    final participants =
        (b['participantContact'] ?? b['participantTransparency'])
            as Map<String, dynamic>?;

    final mainBlock = <Widget>[
      _BackRow(onBack: () => Navigator.of(context).maybePop()),
      const SizedBox(height: 16),
      _SurfaceCard(
        child: _WorkflowStepper(isProvider: isProviderView, booking: b),
      ),
      const SizedBox(height: 16),
      _PriceRowCard(amount: '${b['amount'] ?? '0'}', status: status),
      const SizedBox(height: 16),
      _DetailTabBar(
        selected: _tab,
        isProviderView: isProviderView,
        onChanged: (t) => setState(() => _tab = t),
      ),
      const SizedBox(height: 16),
      _DetailTabBody(
        tab: _tab,
        booking: b,
        listing: listing,
        mapUrl: mapUrl,
        isProviderView: isProviderView,
        participants: participants,
        stepSummary: _stepSummary(_mode, b),
      ),
      const SizedBox(height: 16),
      _CommentsSection(
        commentCtrl: _commentCtrl,
        busyComment: _busyAction == 'COMMENT',
        onPost: _busyAction == null ? _postComment : null,
        comments: comments,
        currentUserId: context.watch<AuthController>().user?.id,
      ),
    ];

    final sidebar = <Widget>[
      _ActionsCard(
        actions: actions,
        busyAction: _busyAction,
        onAction: _runAction,
      ),
      if (canRate) ...[
        const SizedBox(height: 16),
        _RateProviderCard(
          busy: _busyAction == 'REVIEW',
          onSubmit: _submitReview,
        ),
      ],
      if (review != null) ...[
        const SizedBox(height: 16),
        _ExistingReviewCard(review: review),
      ],
      const SizedBox(height: 16),
      _BookingInfoCard(
        listing: listing,
        status: status,
        amount: '${b['amount'] ?? '0'}',
        isProviderView: isProviderView,
        bookingId: '${b['id'] ?? ''}',
        stepSummary: _stepSummary(_mode, b),
      ),
    ];

    // Same content order as escrow_web `Inner` (main column then sidebar blocks), always one
    // vertical scroll — no [Row]/[Expanded] under a vertical scroll (unbounded cross-axis breaks layout).
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [...mainBlock, const SizedBox(height: 16), ...sidebar],
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFE4E6)),
        boxShadow: const [_MarketplaceBookingDetailScreenState._cardShadow],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.error_outline,
              color: Colors.red.shade700,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Error loading booking',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.red.shade700,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BackRow extends StatelessWidget {
  const _BackRow({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onBack,
      borderRadius: BorderRadius.circular(10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Icon(
              Icons.arrow_back_ios_new,
              size: 16,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Back to bookings',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _MarketplaceBookingDetailScreenState._slate100,
        ),
        boxShadow: const [_MarketplaceBookingDetailScreenState._cardShadow],
      ),
      child: child,
    );
  }
}

class _PriceRowCard extends StatelessWidget {
  const _PriceRowCard({required this.amount, required this.status});

  final String amount;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _MarketplaceBookingDetailScreenState._slate100,
        ),
        boxShadow: const [_MarketplaceBookingDetailScreenState._cardShadow],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Amount',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade400,
                  ),
                ),
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'D',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryColorBlack,
                        ),
                      ),
                      TextSpan(
                        text: amount,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: _MarketplaceBookingDetailScreenState._slate900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _DetailStatusBadge(status: status),
        ],
      ),
    );
  }
}

class _DetailStatusBadge extends StatelessWidget {
  const _DetailStatusBadge({required this.status});

  final String status;

  static const _cfg =
      <String, ({String label, Color fg, Color bg, IconData icon})>{
        'PENDING': (
          label: 'Pending',
          fg: Color(0xFFB45309),
          bg: Color(0xFFFFFBEB),
          icon: Icons.schedule,
        ),
        'ACCEPTED': (
          label: 'Accepted',
          fg: Color(0xFF1D4ED8),
          bg: Color(0xFFEFF6FF),
          icon: Icons.check_circle_outline,
        ),
        'IN_PROGRESS': (
          label: 'In Progress',
          fg: Color(0xFF4338CA),
          bg: Color(0xFFEEF2FF),
          icon: Icons.bolt_outlined,
        ),
        'COMPLETED': (
          label: 'Completed',
          fg: Color(0xFF047857),
          bg: Color(0xFFECFDF5),
          icon: Icons.check_circle_outline,
        ),
        'PENDING_PAYMENT': (
          label: 'Payment Due',
          fg: Color(0xFFBE123C),
          bg: Color(0xFFFFF1F2),
          icon: Icons.payments_outlined,
        ),
        'FUNDED': (
          label: 'Paid',
          fg: Color(0xFF047857),
          bg: Color(0xFFECFDF5),
          icon: Icons.check_circle_outline,
        ),
        'CANCELLED': (
          label: 'Cancelled',
          fg: Color(0xFFB91C1C),
          bg: Color(0xFFFFF1F2),
          icon: Icons.close,
        ),
        'REJECTED': (
          label: 'Rejected',
          fg: Color(0xFF334155),
          bg: Color(0xFFF8FAFC),
          icon: Icons.block,
        ),
      };

  @override
  Widget build(BuildContext context) {
    final c =
        _cfg[status] ??
        (
          label: status.isEmpty ? 'Unknown' : status,
          fg: _MarketplaceBookingDetailScreenState._slate700,
          bg: const Color(0xFFFFFBEB),
          icon: Icons.help_outline,
        );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(c.icon, size: 16, color: c.fg),
          const SizedBox(width: 6),
          Text(
            c.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: c.fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkflowStepper extends StatelessWidget {
  const _WorkflowStepper({required this.isProvider, required this.booking});

  final bool isProvider;
  final Map<String, dynamic> booking;

  @override
  Widget build(BuildContext context) {
    final status = '${booking['status'] ?? ''}';
    final flags = _wf(booking);
    final steps = isProvider
        ? <({String label, bool done, bool active})>[
            (
              label: 'Accepted',
              done: status != 'PENDING' && status != 'REJECTED',
              active: status == 'ACCEPTED',
            ),
            (
              label: 'Arrived',
              done: flags.contains('provider_reached'),
              active:
                  !flags.contains('provider_reached') && status != 'PENDING',
            ),
            (
              label: 'In Progress',
              done: flags.contains('client_confirmed_reached'),
              active:
                  flags.contains('provider_reached') &&
                  !flags.contains('client_confirmed_reached'),
            ),
            (
              label: 'Completed',
              done: flags.contains('provider_finished'),
              active:
                  flags.contains('client_confirmed_reached') &&
                  !flags.contains('provider_finished'),
            ),
            (
              label: 'Paid',
              done: flags.contains('funded'),
              active:
                  status == 'PENDING_PAYMENT' ||
                  (status == 'COMPLETED' && !flags.contains('funded')),
            ),
          ]
        : <({String label, bool done, bool active})>[
            (label: 'Booked', done: true, active: false),
            (
              label: 'Provider Arrives',
              done: flags.contains('provider_reached'),
              active: !flags.contains('provider_reached'),
            ),
            (
              label: 'Confirm Arrival',
              done: flags.contains('client_confirmed_reached'),
              active:
                  flags.contains('provider_reached') &&
                  !flags.contains('client_confirmed_reached'),
            ),
            (
              label: 'Service Done',
              done: flags.contains('provider_finished'),
              active:
                  flags.contains('client_confirmed_reached') &&
                  !flags.contains('provider_finished'),
            ),
            (
              label: 'Confirm & Pay',
              done:
                  flags.contains('client_completed_confirmed') &&
                  flags.contains('funded'),
              active:
                  flags.contains('provider_finished') &&
                  !flags.contains('client_completed_confirmed'),
            ),
          ];

    var currentStep = steps.indexWhere((s) => s.active);
    if (currentStep < 0) currentStep = steps.indexWhere((s) => !s.done);
    if (currentStep < 0) currentStep = 0;

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final n = steps.length;
        if (w <= 0 || n == 0) return const SizedBox(height: 72);
        final slot = w / n;
        return SizedBox(
          height: 72,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Positioned(
                left: slot * 0.5,
                right: slot * 0.5,
                top: 15,
                child: Row(
                  children: [
                    for (var i = 0; i < n - 1; i++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              color: (steps[i].done || i < currentStep)
                                  ? AppColors.primaryColorBlack
                                  : const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < n; i++)
                    SizedBox(
                      width: slot,
                      child: _StepNode(
                        index: i,
                        label: steps[i].label,
                        done: steps[i].done,
                        active: steps[i].active,
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Set<String> _wf(Map<String, dynamic> b) {
    final raw = b['workflowFlags'];
    if (raw is! List) return {};
    return raw.whereType<String>().toSet();
  }
}

class _StepNode extends StatelessWidget {
  const _StepNode({
    required this.index,
    required this.label,
    required this.done,
    required this.active,
  });

  final int index;
  final String label;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done
                ? AppColors.primaryColorBlack
                : (active ? Colors.white : Colors.white),
            border: Border.all(
              width: 2,
              color: done || active
                  ? AppColors.primaryColorBlack
                  : const Color(0xFFE2E8F0),
            ),
            boxShadow: active && !done
                ? [
                    BoxShadow(
                      color: AppColors.primaryColorBlack.withValues(alpha: 0.2),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: done
              ? const Icon(Icons.check, size: 18, color: Colors.white)
              : Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: active
                        ? AppColors.primaryColorBlack
                        : _MarketplaceBookingDetailScreenState._slate500,
                  ),
                ),
        ),
        const SizedBox(height: 6),
        Text(
          label.toUpperCase(),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
            height: 1.1,
            color: done || active
                ? AppColors.primaryColorBlack
                : _MarketplaceBookingDetailScreenState._slate500,
          ),
        ),
      ],
    );
  }
}

String? _formatBookingScheduledLocal(Object? raw) {
  if (raw == null) return null;
  final s = raw.toString().trim();
  if (s.isEmpty) return null;
  final d = DateTime.tryParse(s);
  if (d == null) return s;
  final l = d.toLocal();
  return '${l.year}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')} '
      '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
}

String _contactDisplayLine(sm.MarketplaceUserContact? u) {
  final a = u?.displayName?.trim();
  if (a != null && a.isNotEmpty) return a;
  final b = u?.fullName?.trim();
  if (b != null && b.isNotEmpty) return b;
  return '';
}

String _providerNameFromListing(Map<String, dynamic>? listing) {
  final p = listing?['provider'] as Map<String, dynamic>?;
  if (p == null) return '';
  final uid = p['userId'];
  final dn = (p['displayName'] as String?)?.trim();
  if (dn != null &&
      dn.isNotEmpty &&
      !sm.marketplaceLooksLikeOpaqueUserId(dn, uid)) {
    return dn;
  }
  return '';
}

class _BookingPartiesRow extends StatelessWidget {
  const _BookingPartiesRow({
    required this.isProviderView,
    required this.participants,
    required this.listing,
  });

  final bool isProviderView;
  final Map<String, dynamic>? participants;
  final Map<String, dynamic>? listing;

  @override
  Widget build(BuildContext context) {
    final providerU = sm.MarketplaceUserContact.fromJson(
      participants?['provider'],
    );
    final clientU = sm.MarketplaceUserContact.fromJson(participants?['client']);
    var providerLine = _contactDisplayLine(providerU);
    if (providerLine.isEmpty) providerLine = _providerNameFromListing(listing);
    if (providerLine.isEmpty) providerLine = '—';
    var clientLine = _contactDisplayLine(clientU);
    if (clientLine.isEmpty) clientLine = '—';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _MarketplaceBookingDetailScreenState._slate100,
        ),
        boxShadow: const [_MarketplaceBookingDetailScreenState._cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.people_outline,
                size: 18,
                color: AppColors.primaryColorBlack,
              ),
              const SizedBox(width: 8),
              const Text(
                'People on this booking',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _MarketplaceBookingDetailScreenState._slate900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _partyLine('Provider', providerLine, isProviderView),
          const SizedBox(height: 10),
          _partyLine('Client', clientLine, !isProviderView),
        ],
      ),
    );
  }

  Widget _partyLine(String role, String name, bool isYou) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            role,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
            ),
          ),
        ),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _MarketplaceBookingDetailScreenState._slate900,
              ),
              children: [
                TextSpan(text: name),
                if (isYou)
                  TextSpan(
                    text: ' (you)',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: AppColors.primaryColorBlack.withValues(alpha: 0.85),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailTabBar extends StatelessWidget {
  const _DetailTabBar({
    required this.selected,
    required this.isProviderView,
    required this.onChanged,
  });

  final String selected;
  final bool isProviderView;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final third = isProviderView ? 'Client' : 'Provider';
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _MarketplaceBookingDetailScreenState._slate100,
        ),
        boxShadow: const [_MarketplaceBookingDetailScreenState._cardShadow],
      ),
      child: Row(
        children: [
          _TabPill(
            label: 'Overview',
            icon: Icons.grid_view_rounded,
            selected: selected == 'overview',
            onTap: () => onChanged('overview'),
          ),
          const SizedBox(width: 4),
          _TabPill(
            label: 'Service',
            icon: Icons.build_outlined,
            selected: selected == 'service',
            onTap: () => onChanged('service'),
          ),
          const SizedBox(width: 4),
          _TabPill(
            label: third,
            icon: Icons.person_outline,
            selected: selected == 'provider',
            onTap: () => onChanged('provider'),
          ),
        ],
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: selected ? AppColors.primaryColorBlack : Colors.transparent,
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AppColors.primaryColorBlack.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected
                      ? Colors.white
                      : _MarketplaceBookingDetailScreenState._slate500,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? Colors.white
                          : _MarketplaceBookingDetailScreenState._slate600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailTabBody extends StatelessWidget {
  const _DetailTabBody({
    required this.tab,
    required this.booking,
    required this.listing,
    required this.mapUrl,
    required this.isProviderView,
    required this.participants,
    required this.stepSummary,
  });

  final String tab;
  final Map<String, dynamic> booking;
  final Map<String, dynamic>? listing;
  final String? mapUrl;
  final bool isProviderView;
  final Map<String, dynamic>? participants;
  final String stepSummary;

  @override
  Widget build(BuildContext context) {
    if (tab == 'overview') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (listing?['category'] as Map<String, dynamic>?)?['name']
                          ?.toString()
                          .toUpperCase() ??
                      'SERVICE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    color: AppColors.primaryColorBlack.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  (listing?['title'] as String?) ?? 'Service Booking',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: _MarketplaceBookingDetailScreenState._slate900,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  stepSummary,
                  style: const TextStyle(
                    fontSize: 14,
                    color: _MarketplaceBookingDetailScreenState._slate500,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _BookingPartiesRow(
            isProviderView: isProviderView,
            participants: participants,
            listing: listing,
          ),
          const SizedBox(height: 16),
          if (!isProviderView)
            _SectionHeaderCard(
              title: 'About this service',
              icon: Icons.info_outline,
              child: () {
                final desc = (listing?['description'] as String?)?.trim();
                if (desc != null && desc.isNotEmpty) {
                  return Text(
                    desc,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: _MarketplaceBookingDetailScreenState._slate600,
                    ),
                  );
                }
                return Text(
                  'No description available',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade400,
                    fontStyle: FontStyle.italic,
                  ),
                );
              }(),
            ),
          if (!isProviderView) const SizedBox(height: 16),
          _SectionHeaderCard(
            title: 'Location',
            icon: Icons.location_on_outlined,
            child: _LocationBlock(booking: booking, mapUrl: mapUrl),
          ),
          if ((booking['notes'] != null &&
              '${booking['notes']}'.trim().isNotEmpty)) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.edit_note,
                        size: 18,
                        color: Colors.amber.shade800,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isProviderView ? 'Client notes' : 'Your notes',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${booking['notes']}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.amber.shade900,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    }
    if (tab == 'service') {
      if (isProviderView) {
        final desc = (listing?['description'] as String?)?.trim();
        return _SectionHeaderCard(
          title: 'Service scope (for you)',
          icon: Icons.build_outlined,
          child: desc != null && desc.isNotEmpty
              ? Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: _MarketplaceBookingDetailScreenState._slate600,
                  ),
                )
              : Text(
                  'No service details available',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade400,
                    fontStyle: FontStyle.italic,
                  ),
                ),
        );
      }
      final title = (listing?['title'] as String?)?.trim() ?? 'This booking';
      final cat =
          (listing?['category'] as Map<String, dynamic>?)?['name'] as String?;
      final when = _formatBookingScheduledLocal(booking['scheduledAt']);
      final ed = listing?['estimatedDeliveryMins'];
      final edStr = ed is num && ed > 0 ? '${ed.round()} min estimated' : null;
      return _SectionHeaderCard(
        title: 'Your booking summary',
        icon: Icons.receipt_long_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _MarketplaceBookingDetailScreenState._slate900,
              ),
            ),
            if (cat != null && cat.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Category: $cat',
                style: const TextStyle(
                  fontSize: 14,
                  color: _MarketplaceBookingDetailScreenState._slate600,
                ),
              ),
            ],
            if (when != null) ...[
              const SizedBox(height: 6),
              Text(
                'Scheduled: $when',
                style: const TextStyle(
                  fontSize: 14,
                  color: _MarketplaceBookingDetailScreenState._slate600,
                ),
              ),
            ],
            if (edStr != null) ...[
              const SizedBox(height: 6),
              Text(
                edStr,
                style: const TextStyle(
                  fontSize: 14,
                  color: _MarketplaceBookingDetailScreenState._slate600,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'The full public description is in the Overview tab. Use Comments if you need to coordinate details with your provider.',
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }
    return _ProviderTabBody(
      isProviderView: isProviderView,
      listing: listing,
      participants: participants,
    );
  }
}

class _SectionHeaderCard extends StatelessWidget {
  const _SectionHeaderCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _MarketplaceBookingDetailScreenState._slate100,
        ),
        boxShadow: const [_MarketplaceBookingDetailScreenState._cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primaryColorBlack.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: AppColors.primaryColorBlack),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _MarketplaceBookingDetailScreenState._slate900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _LocationBlock extends StatelessWidget {
  const _LocationBlock({required this.booking, required this.mapUrl});

  final Map<String, dynamic> booking;
  final String? mapUrl;

  @override
  Widget build(BuildContext context) {
    final label = (booking['serviceLocationLabel'] as String?)?.trim() ?? '';
    final addr = (booking['serviceAddressText'] as String?)?.trim() ?? '';
    if (label.isEmpty && addr.isEmpty) {
      return Text(
        'No location information available',
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey.shade400,
          fontStyle: FontStyle.italic,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty)
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _MarketplaceBookingDetailScreenState._slate900,
            ),
          ),
        if (addr.isNotEmpty) ...[
          if (label.isNotEmpty) const SizedBox(height: 6),
          Text(
            addr,
            style: const TextStyle(
              fontSize: 14,
              height: 1.45,
              color: _MarketplaceBookingDetailScreenState._slate600,
            ),
          ),
        ],
        if (mapUrl != null) ...[
          const SizedBox(height: 12),
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryColorBlack,
              backgroundColor: AppColors.primaryColorBlack.withValues(alpha: 0.06),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              final uri = Uri.parse(mapUrl!);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            icon: const Icon(Icons.map_outlined, size: 18),
            label: const Text(
              'Open in Maps',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ],
    );
  }
}

class _ProviderTabBody extends StatelessWidget {
  const _ProviderTabBody({
    required this.isProviderView,
    required this.listing,
    required this.participants,
  });

  final bool isProviderView;
  final Map<String, dynamic>? listing;
  final Map<String, dynamic>? participants;

  @override
  Widget build(BuildContext context) {
    final providerU = sm.MarketplaceUserContact.fromJson(
      participants?['provider'],
    );
    final clientU = sm.MarketplaceUserContact.fromJson(participants?['client']);
    final providerFromListing = listing?['provider'] as Map<String, dynamic>?;

    final bio = (providerFromListing?['bio'] as String?)?.trim();
    final ratingAvg = providerFromListing?['ratingAvg'];
    final ratingCount = providerFromListing?['ratingCount'];
    final rc = ratingCount is num
        ? ratingCount.toInt()
        : int.tryParse('$ratingCount') ?? 0;
    final ra = ratingAvg is num
        ? ratingAvg.toDouble()
        : double.tryParse('$ratingAvg') ?? 0.0;

    if (clientU == null && providerU == null) {
      return const _EmptyDashedCard(
        message: 'Contacts for this booking are unavailable.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (clientU != null)
          _ParticipantCard(
            role: 'Client',
            u: clientU,
            showBookedBadge: isProviderView,
          ),
        if (clientU != null && providerU != null) const SizedBox(height: 16),
        if (providerU != null)
          _ParticipantCard(
            role: 'Provider',
            u: providerU,
            showBookedBadge: !isProviderView,
          ),
        if (!isProviderView &&
            providerU != null &&
            bio != null &&
            bio.isNotEmpty) ...[
          const SizedBox(height: 16),
          _SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'About',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _MarketplaceBookingDetailScreenState._slate900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  bio,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: _MarketplaceBookingDetailScreenState._slate600,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (!isProviderView && providerU != null) ...[
          const SizedBox(height: 16),
          if (rc > 0)
            _SurfaceCard(
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: AppColors.primaryColorBlack.withValues(alpha: 0.1),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      ra.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryColorBlack,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            for (var i = 0; i < 5; i++)
                              Icon(
                                Icons.star,
                                size: 18,
                                color: i < ra.round().clamp(0, 5)
                                    ? Colors.amber.shade400
                                    : Colors.grey.shade300,
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Based on $rc review${rc == 1 ? '' : 's'}',
                          style: const TextStyle(
                            fontSize: 13,
                            color:
                                _MarketplaceBookingDetailScreenState._slate500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            const _EmptyDashedCard(
              message: 'No public reviews yet for this provider',
            ),
        ],
      ],
    );
  }
}

class _ParticipantCard extends StatelessWidget {
  const _ParticipantCard({
    required this.role,
    required this.u,
    required this.showBookedBadge,
  });

  final String role;
  final sm.MarketplaceUserContact u;
  final bool showBookedBadge;

  String? _nameLine() {
    final parts = [
      u.displayName?.trim(),
      u.fullName?.trim(),
    ].whereType<String>().where((s) => s.isNotEmpty);
    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }

  String _initials(String? line) {
    if (line == null || line.isEmpty) return '?';
    final bits = line
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .take(2)
        .map((s) => s[0])
        .join();
    return bits.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final primary = _nameLine();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _MarketplaceBookingDetailScreenState._slate100,
        ),
        boxShadow: const [_MarketplaceBookingDetailScreenState._cardShadow],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: AppColors.primaryColorBlack.withValues(alpha: 0.1),
            ),
            child: Text(
              _initials(primary),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryColorBlack,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      role.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: AppColors.primaryColorBlack.withValues(alpha: 0.7),
                      ),
                    ),
                    if (showBookedBadge && role.toLowerCase() == 'client')
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Booked you',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                  ],
                ),
                if (primary != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    primary,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _MarketplaceBookingDetailScreenState._slate900,
                    ),
                  ),
                ],
                if (u.phone != null && u.phone!.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () async {
                      final uri = Uri.parse('tel:${u.phone}');
                      if (await canLaunchUrl(uri)) await launchUrl(uri);
                    },
                    child: Row(
                      children: [
                        Icon(
                          Icons.phone_outlined,
                          size: 16,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            u.phone!,
                            style: const TextStyle(
                              fontSize: 14,
                              color: _MarketplaceBookingDetailScreenState
                                  ._slate600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (u.email != null && u.email!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final uri = Uri.parse('mailto:${u.email}');
                      if (await canLaunchUrl(uri)) await launchUrl(uri);
                    },
                    child: Row(
                      children: [
                        Icon(
                          Icons.email_outlined,
                          size: 16,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            u.email!,
                            style: const TextStyle(
                              fontSize: 14,
                              color: _MarketplaceBookingDetailScreenState
                                  ._slate600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDashedCard extends StatelessWidget {
  const _EmptyDashedCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          Icon(Icons.person_outline, size: 28, color: Colors.grey.shade400),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: _MarketplaceBookingDetailScreenState._slate500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionsCard extends StatelessWidget {
  const _ActionsCard({
    required this.actions,
    required this.busyAction,
    required this.onAction,
  });

  final List<({String action, String label, bool primary})> actions;
  final String? busyAction;
  final void Function(String) onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _MarketplaceBookingDetailScreenState._slate100,
        ),
        boxShadow: const [_MarketplaceBookingDetailScreenState._cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_outlined, size: 18, color: AppColors.primaryColorBlack),
              const SizedBox(width: 8),
              const Text(
                'Actions',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _MarketplaceBookingDetailScreenState._slate900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (actions.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Text(
                'No pending actions at this time',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: _MarketplaceBookingDetailScreenState._slate500,
                ),
              ),
            )
          else
            for (final a in actions)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: a.primary
                      ? FilledButton(
                          onPressed: busyAction == null
                              ? () => onAction(a.action)
                              : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primaryColorBlack,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(52),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            elevation: 3,
                            shadowColor: AppColors.primaryColorBlack.withValues(
                              alpha: 0.25,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            busyAction == a.action ? 'Processing...' : a.label,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )
                      : OutlinedButton(
                          onPressed: busyAction == null
                              ? () => onAction(a.action)
                              : null,
                          style: OutlinedButton.styleFrom(
                            foregroundColor:
                                _MarketplaceBookingDetailScreenState._slate700,
                            minimumSize: const Size.fromHeight(52),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            busyAction == a.action ? 'Processing...' : a.label,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                ),
              ),
        ],
      ),
    );
  }
}

class _RateProviderCard extends StatefulWidget {
  const _RateProviderCard({required this.busy, required this.onSubmit});

  final bool busy;
  final Future<void> Function(int rating, String comment) onSubmit;

  @override
  State<_RateProviderCard> createState() => _RateProviderCardState();
}

class _RateProviderCardState extends State<_RateProviderCard> {
  int _rating = 5;
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _MarketplaceBookingDetailScreenState._slate100,
        ),
        boxShadow: const [_MarketplaceBookingDetailScreenState._cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rate the provider',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: AppColors.primaryColorBlack,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Share how the service went. Your rating helps other clients.',
            style: TextStyle(
              fontSize: 12,
              color: _MarketplaceBookingDetailScreenState._slate500,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var n = 1; n <= 5; n++)
                IconButton(
                  onPressed: widget.busy
                      ? null
                      : () => setState(() => _rating = n),
                  icon: Icon(
                    Icons.star,
                    color: n <= _rating
                        ? AppColors.primaryColorBlack
                        : Colors.grey.shade300,
                  ),
                ),
              Text(
                '$_rating / 5',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          TextField(
            controller: _controller,
            minLines: 2,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Optional feedback',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: widget.busy
                ? null
                : () => widget.onSubmit(_rating, _controller.text),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryColorBlack,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(widget.busy ? 'Submitting...' : 'Submit review'),
          ),
        ],
      ),
    );
  }
}

class _ExistingReviewCard extends StatelessWidget {
  const _ExistingReviewCard({required this.review});

  final Map<String, dynamic> review;

  @override
  Widget build(BuildContext context) {
    final r = (review['rating'] as num?)?.toInt() ?? 0;
    final comment = (review['comment'] as String?)?.trim() ?? '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.star_rate_rounded,
                color: Colors.amber.shade600,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Your Review',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.amber.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < 5; i++)
                Icon(
                  Icons.star,
                  size: 22,
                  color: i < r ? Colors.amber.shade400 : Colors.grey.shade300,
                ),
              const SizedBox(width: 8),
              Text(
                '$r / 5',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              comment,
              style: const TextStyle(
                fontSize: 14,
                height: 1.45,
                color: _MarketplaceBookingDetailScreenState._slate600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BookingInfoCard extends StatelessWidget {
  const _BookingInfoCard({
    required this.listing,
    required this.status,
    required this.amount,
    required this.isProviderView,
    required this.bookingId,
    required this.stepSummary,
  });

  final Map<String, dynamic>? listing;
  final String status;
  final String amount;
  final bool isProviderView;
  final String bookingId;
  final String stepSummary;

  @override
  Widget build(BuildContext context) {
    final cat =
        (listing?['category'] as Map<String, dynamic>?)?['name']?.toString() ??
        'Service';
    final shortId = bookingId.length > 8
        ? '${bookingId.substring(0, 8)}…'
        : bookingId;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _MarketplaceBookingDetailScreenState._slate100,
        ),
        boxShadow: const [_MarketplaceBookingDetailScreenState._cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: AppColors.primaryColorBlack),
              const SizedBox(width: 8),
              const Text(
                'Booking Info',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _infoRow('Category', chip: cat),
          const SizedBox(height: 12),
          _infoRow('Status', trailing: _DetailStatusBadge(status: status)),
          const SizedBox(height: 12),
          _infoRow('Amount', value: 'D$amount'),
          const SizedBox(height: 12),
          _infoRow(
            'Perspective',
            value: isProviderView ? 'Provider' : 'Client',
          ),
          const SizedBox(height: 12),
          _infoRow('Booking ID', value: shortId, mono: true),
          const Divider(height: 28),
          Text(
            'Current Step',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 4),
          Text(
            stepSummary,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _MarketplaceBookingDetailScreenState._slate700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(
    String k, {
    String? value,
    String? chip,
    Widget? trailing,
    bool mono = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            k,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ),
        if (trailing != null)
          trailing
        else if (chip != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryColorBlack.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              chip,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryColorBlack,
              ),
            ),
          )
        else
          Text(
            value ?? '',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _MarketplaceBookingDetailScreenState._slate900,
              fontFamily: mono ? 'monospace' : null,
            ),
          ),
      ],
    );
  }
}

class _CommentsSection extends StatelessWidget {
  const _CommentsSection({
    required this.commentCtrl,
    required this.busyComment,
    required this.onPost,
    required this.comments,
    required this.currentUserId,
  });

  final TextEditingController commentCtrl;
  final bool busyComment;
  final Future<void> Function()? onPost;
  final List<Map<String, dynamic>> comments;
  final String? currentUserId;

  static String _when(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final m = months[d.month - 1];
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$m ${d.day}, $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _MarketplaceBookingDetailScreenState._slate100,
        ),
        boxShadow: const [_MarketplaceBookingDetailScreenState._cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 18,
                color: AppColors.primaryColorBlack,
              ),
              const SizedBox(width: 8),
              const Text(
                'Comments',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Visible to both parties on this booking',
            style: TextStyle(
              fontSize: 12,
              color: _MarketplaceBookingDetailScreenState._slate500,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: commentCtrl,
            minLines: 3,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Write your message...',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: busyComment || onPost == null ? null : () => onPost!(),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryColorBlack,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: busyComment
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send, size: 18),
            label: Text(busyComment ? 'Posting...' : 'Post comment'),
          ),
          const SizedBox(height: 20),
          if (comments.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  style: BorderStyle.solid,
                ),
              ),
              child: const Text(
                'No comments yet. Start the conversation!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: _MarketplaceBookingDetailScreenState._slate500,
                ),
              ),
            )
          else
            for (var idx = 0; idx < comments.length; idx++)
              _CommentTile(
                c: comments[idx],
                isSelf:
                    currentUserId != null &&
                    '${comments[idx]['authorUserId']}' == currentUserId,
                when: _when(comments[idx]['createdAt'] as String?),
              ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.c,
    required this.isSelf,
    required this.when,
  });

  final Map<String, dynamic> c;
  final bool isSelf;
  final String when;

  @override
  Widget build(BuildContext context) {
    final name = '${c['authorName'] ?? 'Someone'}';
    final role = '${c['authorRole'] ?? ''}';
    final roleLabel = role == 'client'
        ? 'Client'
        : role == 'provider'
        ? 'Provider'
        : 'Participant';
    final msg = '${c['message'] ?? ''}';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC).withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _MarketplaceBookingDetailScreenState._slate100,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: isSelf ? AppColors.primaryColorBlack : Colors.grey.shade300,
              ),
              child: Text(
                initial,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isSelf ? Colors.white : Colors.grey.shade700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (isSelf)
                        Text(
                          '(you)',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primaryColorBlack.withValues(alpha: 0.9),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: AppColors.primaryColorBlack.withValues(
                              alpha: 0.12,
                            ),
                          ),
                        ),
                        child: Text(
                          roleLabel.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryColorBlack,
                          ),
                        ),
                      ),
                      if (when.isNotEmpty)
                        Text(
                          when,
                          style: const TextStyle(
                            fontSize: 11,
                            color:
                                _MarketplaceBookingDetailScreenState._slate500,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    msg,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: _MarketplaceBookingDetailScreenState._slate700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


