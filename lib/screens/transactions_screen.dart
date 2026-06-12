// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:provider/provider.dart';

// import '../api/api_error.dart';
// import '../api/escrow_api.dart';
// import '../api/transactions_api.dart';
// import '../auth/auth_controller.dart';
// import '../models/transaction_models.dart';
// import '../models/wallet_models.dart';
// import '../theme/app_colors.dart';
// import '../widgets/create_transaction_sheet.dart';
// import '../widgets/transaction_list_tile.dart';
// import 'personal_kyc_apply_screen.dart';
// import 'transaction_detail_screen.dart';

// // ── Design tokens (mirrors the web's primaryColorBlack system) ────────────────
// const _black = Color(0xFF0F172A);
// const _blackBorder = Color(0x1A0F172A); // ~10% opacity
// const _blackSubtle = Color(0x0D0F172A); // ~5% opacity
// const _blackMuted = Color(0x990F172A); // ~60% opacity

// class TransactionsScreen extends StatefulWidget {
//   const TransactionsScreen({super.key});

//   @override
//   State<TransactionsScreen> createState() => _TransactionsScreenState();
// }

// class _TransactionsScreenState extends State<TransactionsScreen> {
//   List<TransactionListItem> _items = [];
//   String? _loadErr;
//   bool _loading = true;
//   String? _walletCurrency;
//   // ignore: prefer_final_fields
//   int _activeTab = 0;

//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback((_) => _load());
//   }

//   Future<void> _load() async {
//     final auth = context.read<AuthController>();
//     final t = auth.token;
//     final u = auth.user;
//     if (t == null || u == null) {
//       if (mounted) setState(() => _loading = false);
//       return;
//     }
//     setState(() => _loading = true);
//     try {
//       final results = await Future.wait<Object>([
//         listTransactionsForParty(t, u.id),
//         getWallet(t),
//       ]);
//       final res = results[0] as TransactionListResponse;
//       final wallet = results[1] as WalletSummary;
//       if (!mounted) return;
//       setState(() {
//         _items = res.items;
//         _walletCurrency = wallet.currency;
//         _loadErr = null;
//       });
//     } catch (e) {
//       if (mounted) setState(() => _loadErr = errorMessage(e));
//     } finally {
//       if (mounted) setState(() => _loading = false);
//     }
//   }

//   void _openCreate() {
//     final auth = context.read<AuthController>();
//     final t = auth.token;
//     final u = auth.user;
//     if (t == null || u == null) return;
//     if (!u.personalKycApproved) {
//       Navigator.of(context).push(
//         MaterialPageRoute<void>(builder: (_) => const PersonalKycApplyScreen()),
//       );
//       return;
//     }
//     showCreateTransactionSheet(
//       context: context,
//       token: t,
//       selfId: u.id,
//       onCreated: (id) {
//         Navigator.of(context).push(
//           MaterialPageRoute<void>(
//             builder: (_) => TransactionDetailScreen(transactionId: id),
//           ),
//         );
//         _load();
//       },
//     );
//   }

//   List<TransactionListItem> _filteredItems() {
//     if (_activeTab == 1) {
//       return _items.where((i) => i.workflow == 'PUBLIC_SHAREABLE').toList();
//     }
//     if (_activeTab == 2) {
//       return _items.where((i) => i.workflow == 'ESCROW_TWO_PARTY').toList();
//     }
//     return _items;
//   }

//   @override
//   Widget build(BuildContext context) {
//     final auth = context.watch<AuthController>();
//     final userId = auth.user?.id ?? '';
//     final u = auth.user;
//     final canCreate = u?.personalKycApproved == true;
//     final kycPending = u?.personalKycStatus == 'PENDING';

//     final publicCount = _items
//         .where((x) => x.workflow == 'PUBLIC_SHAREABLE')
//         .length;
//     final escrowCount = _items
//         .where((x) => x.workflow == 'ESCROW_TWO_PARTY')
//         .length;
//     final inEscrowCount = _items
//         .where(
//           (x) => {'FUNDED', 'IN_PROGRESS', 'INSPECTION'}.contains(x.status),
//         )
//         .length;

//     final filtered = _filteredItems();

//     return AnnotatedRegion<SystemUiOverlayStyle>(
//       value: const SystemUiOverlayStyle(
//         statusBarColor: Colors.white,
//         statusBarIconBrightness: Brightness.dark,
//         statusBarBrightness: Brightness.light,
//         systemNavigationBarColor: AppColors.primaryColorBlack,
//         systemNavigationBarIconBrightness: Brightness.light,
//       ),
//       child: Stack(
//         children: [
//           RefreshIndicator(
//             color: _black,
//             onRefresh: _load,
//             child: ListView(
//               physics: const AlwaysScrollableScrollPhysics(),
//               padding: const EdgeInsets.fromLTRB(16, 80, 16, 32),
//               children: [
//                 // ── Stats grid ───────────────────────────────────────────────
//                 _StatsGrid(
//                   total: _items.length,
//                   shareable: publicCount,
//                   active: inEscrowCount,
//                 ),
//                 const SizedBox(height: 20),

//                 // ── Listing panel ─────────────────────────────────────────────
//                 _ListingPanel(
//                   loading: _loading,
//                   loadErr: _loadErr,
//                   filtered: filtered,
//                   activeTab: _activeTab,
//                   userId: userId,
//                   walletCurrency: _walletCurrency,
//                   onTap: (id) => Navigator.of(context).push(
//                     MaterialPageRoute<void>(
//                       builder: (_) =>
//                           TransactionDetailScreen(transactionId: id),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),

//           // ── Floating header ───────────────────────────────────────────────
//           Positioned(
//             left: 0,
//             right: 0,
//             top: 0,
//             child: _Header(
//               canCreate: canCreate,
//               kycPending: kycPending,
//               onCreate: _openCreate,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// // ── Header ────────────────────────────────────────────────────────────────────

// class _Header extends StatelessWidget {
//   const _Header({
//     required this.canCreate,
//     required this.kycPending,
//     required this.onCreate,
//   });

//   final bool canCreate;
//   final bool kycPending;
//   final VoidCallback onCreate;

//   @override
//   Widget build(BuildContext context) {
//     final label = canCreate
//         ? 'Create transaction'
//         : kycPending
//         ? 'KYC pending review'
//         : 'Apply KYC';
//     final icon = canCreate
//         ? Icons.shield_outlined
//         : kycPending
//         ? Icons.hourglass_top_rounded
//         : Icons.verified_user_outlined;

//     return Container(
//       color: Colors.white.withValues(alpha: 0.96),
//       child: SafeArea(
//         bottom: false,
//         child: Padding(
//           padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
//           child: Row(
//             children: [
//               // Title block
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       'TRANSACTION DASHBOARD',
//                       style: TextStyle(
//                         fontSize: 10,
//                         fontWeight: FontWeight.w900,
//                         letterSpacing: 1.4,
//                         color: _blackMuted,
//                       ),
//                     ),
//                     const SizedBox(height: 2),
//                     const Text(
//                       'Transactions',
//                       style: TextStyle(
//                         fontSize: 22,
//                         fontWeight: FontWeight.w900,
//                         color: _black,
//                         letterSpacing: -0.5,
//                         height: 1.1,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               const SizedBox(width: 12),
//               // CTA button
//               GestureDetector(
//                 onTap: onCreate,
//                 child: Container(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 16,
//                     vertical: 10,
//                   ),
//                   decoration: BoxDecoration(
//                     color: _black,
//                     borderRadius: BorderRadius.circular(14),
//                   ),
//                   child: Row(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       Icon(icon, size: 16, color: Colors.white),
//                       const SizedBox(width: 8),
//                       Text(
//                         label,
//                         style: const TextStyle(
//                           color: Colors.white,
//                           fontSize: 13,
//                           fontWeight: FontWeight.w900,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// // ── Stats grid (colorful gradient cards) ──────────────────────────────────────

// class _StatsGrid extends StatelessWidget {
//   const _StatsGrid({
//     required this.total,
//     required this.shareable,
//     required this.active,
//   });

//   final int total;
//   final int shareable;
//   final int active;

//   @override
//   Widget build(BuildContext context) {
//     return LayoutBuilder(
//       builder: (context, constraints) {
//         final gap = 12.0;
//         final w = (constraints.maxWidth - gap) / 2;
//         return Wrap(
//           spacing: gap,
//           runSpacing: gap,
//           children: [
//             _GradientStatCard(
//               width: w,
//               label: 'Total Rooms',
//               value: total,
//               icon: Icons.layers_rounded,
//               gradientColors: const [Color(0xFFFBBF24), Color(0xFFF97316)],
//               borderColor: Color(0x4DFBBF24),
//             ),
//             _GradientStatCard(
//               width: w,
//               label: 'Shareable Links',
//               value: shareable,
//               icon: Icons.link_rounded,
//               gradientColors: const [Color(0xFF34D399), Color(0xFF0D9488)],
//               borderColor: Color(0x4D34D399),
//             ),
//             _GradientStatCard(
//               width: w * 2 + gap,
//               label: 'Currently in Escrow',
//               value: active,
//               icon: Icons.lock_outline_rounded,
//               gradientColors: const [Color(0xFFFB7185), Color(0xFFC026D3)],
//               borderColor: Color(0x4DFB7185),
//               fullWidth: true,
//             ),
//           ],
//         );
//       },
//     );
//   }
// }

// class _GradientStatCard extends StatelessWidget {
//   const _GradientStatCard({
//     required this.width,
//     required this.label,
//     required this.value,
//     required this.icon,
//     required this.gradientColors,
//     required this.borderColor,
//     this.fullWidth = false,
//   });

//   final double width;
//   final String label;
//   final int value;
//   final IconData icon;
//   final List<Color> gradientColors;
//   final Color borderColor;
//   final bool fullWidth;

//   @override
//   Widget build(BuildContext context) {
//     return SizedBox(
//       width: width,
//       child: Container(
//         constraints: const BoxConstraints(minHeight: 120),
//         padding: const EdgeInsets.all(18),
//         decoration: BoxDecoration(
//           gradient: LinearGradient(
//             begin: Alignment.topLeft,
//             end: Alignment.bottomRight,
//             colors: gradientColors,
//           ),
//           borderRadius: BorderRadius.circular(20),
//           border: Border.all(color: borderColor, width: 1),
//           boxShadow: [
//             BoxShadow(
//               color: gradientColors.last.withValues(alpha: 0.35),
//               blurRadius: 18,
//               offset: const Offset(0, 8),
//             ),
//           ],
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               children: [
//                 // Live dot + label
//                 Container(
//                   width: 6,
//                   height: 6,
//                   decoration: const BoxDecoration(
//                     color: Colors.white,
//                     shape: BoxShape.circle,
//                   ),
//                 ),
//                 const SizedBox(width: 6),
//                 Expanded(
//                   child: Text(
//                     label.toUpperCase(),
//                     maxLines: 1,
//                     overflow: TextOverflow.ellipsis,
//                     style: const TextStyle(
//                       color: Colors.white,
//                       fontSize: 10,
//                       fontWeight: FontWeight.w900,
//                       letterSpacing: 1.4,
//                     ),
//                   ),
//                 ),
//                 // Icon pill
//                 Container(
//                   width: 40,
//                   height: 40,
//                   decoration: BoxDecoration(
//                     color: Colors.white.withValues(alpha: 0.2),
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                   child: Icon(icon, size: 20, color: Colors.white),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 14),
//             // Big number
//             Text(
//               '$value',
//               style: const TextStyle(
//                 color: Colors.white,
//                 fontSize: 52,
//                 fontWeight: FontWeight.w900,
//                 height: 1,
//                 letterSpacing: -2,
//               ),
//             ),
//             const SizedBox(height: 14),
//             // Bottom accent bar
//             ClipRRect(
//               borderRadius: BorderRadius.circular(4),
//               child: SizedBox(
//                 height: 4,
//                 child: Row(
//                   children: [
//                     Expanded(
//                       flex: 3,
//                       child: Container(
//                         color: Colors.white.withValues(alpha: 0.8),
//                       ),
//                     ),
//                     Expanded(
//                       flex: 1,
//                       child: Container(
//                         color: Colors.white.withValues(alpha: 0.2),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// // ── Listing panel ─────────────────────────────────────────────────────────────

// class _ListingPanel extends StatelessWidget {
//   const _ListingPanel({
//     required this.loading,
//     required this.loadErr,
//     required this.filtered,
//     required this.activeTab,
//     required this.userId,
//     required this.walletCurrency,
//     required this.onTap,
//   });

//   final bool loading;
//   final String? loadErr;
//   final List<TransactionListItem> filtered;
//   final int activeTab;
//   final String userId;
//   final String? walletCurrency;
//   final void Function(String id) onTap;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(24),
//         border: Border.all(color: _blackBorder),
//         boxShadow: [
//           BoxShadow(
//             color: _black.withValues(alpha: 0.04),
//             blurRadius: 20,
//             offset: const Offset(0, 8),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Panel header
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
//             decoration: BoxDecoration(
//               color: _blackSubtle,
//               borderRadius: const BorderRadius.vertical(
//                 top: Radius.circular(24),
//               ),
//               border: Border(bottom: BorderSide(color: _blackBorder)),
//             ),
//             child: Row(
//               children: [
//                 Expanded(
//                   child: Text(
//                     activeTab == 1
//                         ? 'Shareable sales'
//                         : activeTab == 2
//                         ? 'Two-party escrow'
//                         : 'All Transactions',
//                     style: const TextStyle(
//                       color: _black,
//                       fontSize: 18,
//                       fontWeight: FontWeight.w900,
//                       letterSpacing: -0.3,
//                     ),
//                   ),
//                 ),
//                 // Count pill
//                 Container(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 12,
//                     vertical: 6,
//                   ),
//                   decoration: BoxDecoration(
//                     color: Colors.white,
//                     borderRadius: BorderRadius.circular(50),
//                     border: Border.all(color: _blackBorder),
//                   ),
//                   child: Row(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       Icon(Icons.layers_rounded, size: 13, color: _black),
//                       const SizedBox(width: 5),
//                       Text(
//                         '${filtered.length} ${filtered.length == 1 ? "transaction" : "transactions"}',
//                         style: const TextStyle(
//                           color: _black,
//                           fontSize: 11,
//                           fontWeight: FontWeight.w900,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ),

//           // Error
//           if (loadErr != null)
//             Container(
//               margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
//               padding: const EdgeInsets.all(14),
//               decoration: BoxDecoration(
//                 color: Colors.red.shade50,
//                 borderRadius: BorderRadius.circular(14),
//                 border: Border.all(color: Colors.red.shade100),
//               ),
//               child: Text(
//                 loadErr!,
//                 style: TextStyle(color: Colors.red.shade800, fontSize: 13),
//               ),
//             ),

//           // Content
//           Padding(
//             padding: const EdgeInsets.all(16),
//             child: loading && filtered.isEmpty && loadErr == null
//                 ? const _TransactionsLoading()
//                 : filtered.isEmpty && loadErr == null
//                 ? _EmptyState(activeTab: activeTab)
//                 : Column(
//                     children: List.generate(filtered.length, (i) {
//                       final row = filtered[i];
//                       return Padding(
//                         padding: EdgeInsets.only(
//                           bottom: i == filtered.length - 1 ? 0 : 12,
//                         ),
//                         child: _TransactionRow(
//                           row: row,
//                           selfId: userId,
//                           currency: walletCurrency,
//                           onTap: () => onTap(row.id),
//                         ),
//                       );
//                     }),
//                   ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// // ── Transaction row card ──────────────────────────────────────────────────────

// class _TransactionRow extends StatelessWidget {
//   const _TransactionRow({
//     required this.row,
//     required this.selfId,
//     required this.currency,
//     required this.onTap,
//   });

//   final TransactionListItem row;
//   final String selfId;
//   final String? currency;
//   final VoidCallback onTap;

//   @override
//   Widget build(BuildContext context) {
//     final isPublic = row.workflow == 'PUBLIC_SHAREABLE';
//     final roleLabel = row.buyerId == selfId ? 'Buying' : 'Selling';
//     final progress = _statusProgress(row.status);
//     final formattedAmount = _formatMoney(row.amount, currency);
//     final formattedDate = _formatDate(DateTime.tryParse(row.updatedAt));

//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         padding: const EdgeInsets.all(18),
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(18),
//           border: Border.all(color: _blackBorder),
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Top row: icon + info
//             Row(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 // Icon box
//                 Container(
//                   width: 46,
//                   height: 46,
//                   decoration: BoxDecoration(
//                     color: _blackSubtle,
//                     borderRadius: BorderRadius.circular(13),
//                   ),
//                   child: Icon(
//                     isPublic ? Icons.link_rounded : Icons.shield_outlined,
//                     size: 22,
//                     color: _black,
//                   ),
//                 ),
//                 const SizedBox(width: 12),
//                 // Title + meta
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Row(
//                         children: [
//                           Expanded(
//                             child: Text(
//                               row.productTitle?.isNotEmpty == true
//                                   ? row.productTitle!
//                                   : 'Secure sale ${row.id.substring(0, 8)}...',
//                               maxLines: 1,
//                               overflow: TextOverflow.ellipsis,
//                               style: const TextStyle(
//                                 color: _black,
//                                 fontSize: 15,
//                                 fontWeight: FontWeight.w900,
//                               ),
//                             ),
//                           ),
//                           const SizedBox(width: 8),
//                           _WorkflowBadge(isPublic: isPublic),
//                         ],
//                       ),
//                       const SizedBox(height: 5),
//                       Text(
//                         '$roleLabel · ${_formatType(row.type)} · $formattedDate',
//                         style: TextStyle(
//                           color: _blackMuted,
//                           fontSize: 11,
//                           fontWeight: FontWeight.w800,
//                           letterSpacing: 0.5,
//                         ),
//                       ),
//                       const SizedBox(height: 8),
//                       Text(
//                         formattedAmount,
//                         style: const TextStyle(
//                           color: _black,
//                           fontSize: 22,
//                           fontWeight: FontWeight.w900,
//                           letterSpacing: -0.5,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),

//             const SizedBox(height: 16),
//             const Divider(color: _blackBorder, height: 1),
//             const SizedBox(height: 14),

//             // Progress row
//             Row(
//               children: [
//                 _StatusBadge(status: row.status),
//                 const Spacer(),
//                 Text(
//                   '$progress%',
//                   style: const TextStyle(
//                     color: _black,
//                     fontSize: 12,
//                     fontWeight: FontWeight.w900,
//                   ),
//                 ),
//                 const SizedBox(width: 10),
//                 // Progress bar
//                 SizedBox(
//                   width: 100,
//                   child: ClipRRect(
//                     borderRadius: BorderRadius.circular(4),
//                     child: LinearProgressIndicator(
//                       value: progress / 100,
//                       minHeight: 6,
//                       backgroundColor: _blackSubtle,
//                       valueColor: const AlwaysStoppedAnimation<Color>(_black),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(width: 12),
//                 // Chevron circle
//                 Container(
//                   width: 34,
//                   height: 34,
//                   decoration: BoxDecoration(
//                     color: _blackSubtle,
//                     shape: BoxShape.circle,
//                     border: Border.all(color: _blackBorder),
//                   ),
//                   child: const Icon(
//                     Icons.chevron_right_rounded,
//                     size: 18,
//                     color: _black,
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   int _statusProgress(String status) {
//     switch (status) {
//       case 'CREATED':
//         return 10;
//       case 'PENDING_PAYMENT':
//         return 20;
//       case 'FUNDED':
//         return 40;
//       case 'IN_PROGRESS':
//         return 60;
//       case 'INSPECTION':
//         return 75;
//       case 'COMPLETED':
//       case 'CLOSED':
//         return 100;
//       case 'DISPUTED':
//         return 50;
//       default:
//         return 0;
//     }
//   }

//   String _formatMoney(dynamic amount, String? currency) {
//     final sym = currency ?? 'USD';
//     return '$sym ${amount?.toString() ?? '0'}';
//   }

//   String _formatDate(DateTime? dt) {
//     if (dt == null) return '';
//     return '${dt.day}/${dt.month}/${dt.year}';
//   }

//   String _formatType(String? type) {
//     if (type == null) return '';
//     return type
//         .toLowerCase()
//         .replaceAll('_', ' ')
//         .split(' ')
//         .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
//         .join(' ');
//   }
// }

// class _WorkflowBadge extends StatelessWidget {
//   const _WorkflowBadge({required this.isPublic});
//   final bool isPublic;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
//       decoration: BoxDecoration(
//         color: isPublic ? _blackSubtle : _black,
//         borderRadius: BorderRadius.circular(50),
//       ),
//       child: Text(
//         isPublic ? 'Shareable' : 'Escrow',
//         style: TextStyle(
//           color: isPublic ? _black : Colors.white,
//           fontSize: 10,
//           fontWeight: FontWeight.w900,
//         ),
//       ),
//     );
//   }
// }

// class _StatusBadge extends StatelessWidget {
//   const _StatusBadge({required this.status});
//   final String status;

//   @override
//   Widget build(BuildContext context) {
//     final (bg, fg, label) = switch (status) {
//       'COMPLETED' || 'CLOSED' => (_black, Colors.white, 'Completed'),
//       'DISPUTED' => (
//         const Color(0xFFFEE2E2),
//         const Color(0xFFB91C1C),
//         'Disputed',
//       ),
//       'FUNDED' => (_blackSubtle, _black, 'Funded'),
//       'IN_PROGRESS' => (_blackSubtle, _black, 'In Progress'),
//       'INSPECTION' => (_blackSubtle, _black, 'Inspection'),
//       _ => (_blackSubtle, _black, _formatStatusLabel(status)),
//     };

//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
//       decoration: BoxDecoration(
//         color: bg,
//         borderRadius: BorderRadius.circular(50),
//       ),
//       child: Text(
//         label,
//         style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w900),
//       ),
//     );
//   }

//   String _formatStatusLabel(String status) {
//     return status
//         .toLowerCase()
//         .replaceAll('_', ' ')
//         .split(' ')
//         .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
//         .join(' ');
//   }
// }

// // ── Loading & empty states ─────────────────────────────────────────────────────

// class _TransactionsLoading extends StatelessWidget {
//   const _TransactionsLoading();

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
//       decoration: BoxDecoration(
//         color: _blackSubtle,
//         borderRadius: BorderRadius.circular(18),
//         border: Border.all(color: _blackBorder, style: BorderStyle.solid),
//       ),
//       child: Column(
//         children: [
//           SizedBox(
//             height: 36,
//             width: 36,
//             child: CircularProgressIndicator(strokeWidth: 2.5, color: _black),
//           ),
//           const SizedBox(height: 16),
//           const Text(
//             'Loading transactions...',
//             textAlign: TextAlign.center,
//             style: TextStyle(
//               color: _blackMuted,
//               fontWeight: FontWeight.w700,
//               fontSize: 14,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _EmptyState extends StatelessWidget {
//   const _EmptyState({required this.activeTab});
//   final int activeTab;

//   @override
//   Widget build(BuildContext context) {
//     final message = activeTab == 1
//         ? 'No shareable sales yet.'
//         : activeTab == 2
//         ? 'No two-party escrow rooms yet.'
//         : 'No transactions yet.';

//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
//       decoration: BoxDecoration(
//         color: _blackSubtle,
//         borderRadius: BorderRadius.circular(18),
//         border: Border.all(color: _blackBorder),
//       ),
//       child: Column(
//         children: [
//           Container(
//             height: 48,
//             width: 48,
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(16),
//               border: Border.all(color: _blackBorder),
//             ),
//             child: const Icon(Icons.receipt_long_rounded, color: _black),
//           ),
//           const SizedBox(height: 14),
//           Text(
//             message,
//             textAlign: TextAlign.center,
//             style: const TextStyle(
//               color: _blackMuted,
//               height: 1.5,
//               fontSize: 14,
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../api/api_error.dart';
import '../api/escrow_api.dart';
import '../api/transactions_api.dart';
import '../auth/auth_controller.dart';
import '../models/transaction_models.dart';
import '../models/wallet_models.dart';
import '../theme/app_colors.dart';
import '../widgets/create_transaction_sheet.dart';
import 'personal_kyc_apply_screen.dart';
import 'transaction_detail_screen.dart';

// Use the app’s primary color instead of a hardcoded black
Color get _primary => AppColors.primaryColorBlack;
Color get _primaryBorder => _primary.withValues(alpha: 0.1);
Color get _primarySubtle => _primary.withValues(alpha: 0.05);
Color get _primaryMuted => _primary.withValues(alpha: 0.6);

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  List<TransactionListItem> _items = [];
  String? _loadErr;
  bool _loading = true;
  String? _walletCurrency;
  int _activeTab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final auth = context.read<AuthController>();
    final t = auth.token;
    final u = auth.user;
    if (t == null || u == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final results = await Future.wait<Object>([
        listTransactionsForParty(t, u.id),
        getWallet(t),
      ]);
      final res = results[0] as TransactionListResponse;
      final wallet = results[1] as WalletSummary;
      if (!mounted) return;
      setState(() {
        _items = res.items;
        _walletCurrency = wallet.currency;
        _loadErr = null;
      });
    } catch (e) {
      if (mounted) setState(() => _loadErr = errorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openCreate() {
    final auth = context.read<AuthController>();
    final t = auth.token;
    final u = auth.user;
    if (t == null || u == null) return;
    if (!u.personalKycApproved) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const PersonalKycApplyScreen()),
      );
      return;
    }
    showCreateTransactionSheet(
      context: context,
      token: t,
      selfId: u.id,
      onCreated: (id) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => TransactionDetailScreen(transactionId: id),
          ),
        );
        _load();
      },
    );
  }

  List<TransactionListItem> _filteredItems() {
    if (_activeTab == 1) {
      return _items.where((i) => i.workflow == 'PUBLIC_SHAREABLE').toList();
    }
    if (_activeTab == 2) {
      return _items.where((i) => i.workflow == 'ESCROW_TWO_PARTY').toList();
    }
    return _items;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final userId = auth.user?.id ?? '';
    final u = auth.user;
    final canCreate = u?.personalKycApproved == true;
    final kycPending = u?.personalKycStatus == 'PENDING';

    final publicCount = _items.where((x) => x.workflow == 'PUBLIC_SHAREABLE').length;
    final inEscrowCount = _items.where((x) => {'FUNDED', 'IN_PROGRESS', 'INSPECTION'}.contains(x.status)).length;
    final filtered = _filteredItems();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.primaryColorBlack,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        body: Stack(
          children: [
            RefreshIndicator(
              color: _primary,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: MediaQuery.of(context).padding.top + 90, // space for the fixed button
                  bottom: 32,
                ),
                children: [
                  _StatsGrid(
                    total: _items.length,
                    shareable: publicCount,
                    active: inEscrowCount,
                  ),
                  const SizedBox(height: 20),
                  _ListingPanel(
                    loading: _loading,
                    loadErr: _loadErr,
                    filtered: filtered,
                    activeTab: _activeTab,
                    userId: userId,
                    walletCurrency: _walletCurrency,
                    onTap: (id) => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => TransactionDetailScreen(transactionId: id),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Fixed header with the create button (no extra title)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: _Header(
                canCreate: canCreate,
                kycPending: kycPending,
                onCreate: _openCreate,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Full‑width create button, uses primaryColorBlack ─────────────────────────
class _Header extends StatelessWidget {
  const _Header({
    required this.canCreate,
    required this.kycPending,
    required this.onCreate,
  });

  final bool canCreate;
  final bool kycPending;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final label = canCreate
        ? 'Create transaction'
        : kycPending
            ? 'KYC pending review'
            : 'Apply KYC';
    final icon = canCreate
        ? Icons.add_rounded
        : kycPending
            ? Icons.hourglass_top_rounded
            : Icons.verified_user_outlined;

    return Container(
      color: Colors.white.withValues(alpha: 0.98),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: GestureDetector(
            onTap: onCreate,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: _primary,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _primary.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18, color: Colors.white),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Stats grid – uses primaryColorBlack for borders / text / icons ───────────
class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.total,
    required this.shareable,
    required this.active,
  });

  final int total;
  final int shareable;
  final int active;

  @override
  Widget build(BuildContext context) {
    final gap = 12.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final double w = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            _StatCard(width: w, label: 'Total', value: total, icon: Icons.layers_rounded),
            _StatCard(width: w, label: 'Shareable', value: shareable, icon: Icons.link_rounded),
            _StatCard(
              width: w * 2 + gap,
              label: 'in Escrow',
              value: active,
              icon: Icons.lock_outline_rounded,
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
  });

  final double width;
  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _primaryBorder),
          boxShadow: [
            BoxShadow(
              color: _primary.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: _primary, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                      color: _primaryMuted,
                    ),
                  ),
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _primarySubtle,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 18, color: _primary),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '$value',
              style: TextStyle(
                color: _primary,
                fontSize: 42,
                fontWeight: FontWeight.w900,
                height: 1,
                letterSpacing: -1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Listing panel – full width, no weird gaps ────────────────────────────────
class _ListingPanel extends StatelessWidget {
  const _ListingPanel({
    required this.loading,
    required this.loadErr,
    required this.filtered,
    required this.activeTab,
    required this.userId,
    required this.walletCurrency,
    required this.onTap,
  });

  final bool loading;
  final String? loadErr;
  final List<TransactionListItem> filtered;
  final int activeTab;
  final String userId;
  final String? walletCurrency;
  final void Function(String id) onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _primaryBorder),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: _primarySubtle,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(bottom: BorderSide(color: _primaryBorder)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    activeTab == 1
                        ? 'Shareable sales'
                        : activeTab == 2
                            ? 'Two-party escrow'
                            : 'All Transactions',
                    style: TextStyle(
                      color: _primary,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(color: _primaryBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.layers_rounded, size: 13, color: _primary),
                      const SizedBox(width: 5),
                      Text(
                        '${filtered.length} ${filtered.length == 1 ? "transaction" : "transactions"}',
                        style: TextStyle(color: _primary, fontSize: 11, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (loadErr != null)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.red.shade100),
              ),
              child: Text(loadErr!, style: TextStyle(color: Colors.red.shade800, fontSize: 13)),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: loading && filtered.isEmpty && loadErr == null
                ? const _TransactionsLoading()
                : filtered.isEmpty && loadErr == null
                    ? _EmptyState(activeTab: activeTab)
                    : Column(
                        children: List.generate(filtered.length, (i) {
                          final row = filtered[i];
                          return Padding(
                            padding: EdgeInsets.only(bottom: i == filtered.length - 1 ? 0 : 12),
                            child: _TransactionRow(
                              row: row,
                              selfId: userId,
                              currency: walletCurrency,
                              onTap: () => onTap(row.id),
                            ),
                          );
                        }),
                      ),
          ),
        ],
      ),
    );
  }
}

// ── Transaction row – uses primaryColorBlack, improved spacing ───────────────
class _TransactionRow extends StatelessWidget {
  const _TransactionRow({
    required this.row,
    required this.selfId,
    required this.currency,
    required this.onTap,
  });

  final TransactionListItem row;
  final String selfId;
  final String? currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isPublic = row.workflow == 'PUBLIC_SHAREABLE';
    final roleLabel = row.buyerId == selfId ? 'Buying' : 'Selling';
    final progress = _statusProgress(row.status);
    final formattedAmount = _formatMoney(row.amount, currency);
    final formattedDate = _formatDate(DateTime.tryParse(row.updatedAt));

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _primaryBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: _primarySubtle,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    isPublic ? Icons.link_rounded : Icons.shield_outlined,
                    size: 22,
                    color: _primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              row.productTitle?.isNotEmpty == true
                                  ? row.productTitle!
                                  : 'Secure sale ${row.id.substring(0, 8)}...',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: _primary, fontSize: 15, fontWeight: FontWeight.w900),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _WorkflowBadge(isPublic: isPublic),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '$roleLabel · ${_formatType(row.type)} · $formattedDate',
                        style: TextStyle(color: _primaryMuted, fontSize: 11, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        formattedAmount,
                        style: TextStyle(
                          color: _primary,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.black, height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                Flexible(
                  fit: FlexFit.loose,
                  child: _StatusBadge(status: row.status),
                ),
                const SizedBox(width: 8),
                Text(
                  '$progress%',
                  style: TextStyle(
                    color: _primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress / 100,
                      minHeight: 6,
                      backgroundColor: _primarySubtle,
                      valueColor: AlwaysStoppedAnimation<Color>(_primary),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, size: 20, color: _primary),
              ],
            ),
          ],
        ),
      ),
    );
  }

  int _statusProgress(String status) {
    switch (status) {
      case 'CREATED': return 10;
      case 'PENDING_PAYMENT': return 20;
      case 'FUNDED': return 40;
      case 'IN_PROGRESS': return 60;
      case 'INSPECTION': return 75;
      case 'COMPLETED': case 'CLOSED': return 100;
      case 'DISPUTED': return 50;
      default: return 0;
    }
  }

  String _formatMoney(dynamic amount, String? currency) {
    final sym = currency ?? 'USD';
    return '$sym ${amount?.toString() ?? '0'}';
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _formatType(String? type) {
    if (type == null) return '';
    return type.toLowerCase().replaceAll('_', ' ').split(' ').map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
  }
}

class _WorkflowBadge extends StatelessWidget {
  const _WorkflowBadge({required this.isPublic});
  final bool isPublic;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: isPublic ? _primarySubtle : _primary,
        borderRadius: BorderRadius.circular(50),
      ),
      child: Text(
        isPublic ? 'Shareable' : 'Escrow',
        style: TextStyle(
          color: isPublic ? _primary : Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = switch (status) {
      'COMPLETED' || 'CLOSED' => (_primary, Colors.white, 'Completed'),
      'DISPUTED' => (const Color(0xFFFEE2E2), const Color(0xFFB91C1C), 'Disputed'),
      'FUNDED' => (_primarySubtle, _primary, 'Funded'),
      'IN_PROGRESS' => (_primarySubtle, _primary, 'In Progress'),
      'INSPECTION' => (_primarySubtle, _primary, 'Inspection'),
      _ => (_primarySubtle, _primary, _formatStatusLabel(status)),
    };

    return Container(
      constraints: const BoxConstraints(maxWidth: 120),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(50)),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w900),
      ),
    );
  }

  String _formatStatusLabel(String status) {
    return status.toLowerCase().replaceAll('_', ' ').split(' ').map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
  }
}

// ── Full‑width loading state ─────────────────────────────────────────────────
class _TransactionsLoading extends StatelessWidget {
  const _TransactionsLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        color: _primarySubtle,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _primaryBorder),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 36,
            width: 36,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: _primary),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading transactions...',
            style: TextStyle(color: _primaryMuted, fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.activeTab});
  final int activeTab;

  @override
  Widget build(BuildContext context) {
    final message = activeTab == 1
        ? 'No shareable sales yet.'
        : activeTab == 2
            ? 'No two-party escrow rooms yet.'
            : 'No transactions yet.';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      decoration: BoxDecoration(
        color: _primarySubtle,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _primaryBorder),
      ),
      child: Column(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _primaryBorder),
            ),
            child: Icon(Icons.receipt_long_rounded, color: _primary),
          ),
          const SizedBox(height: 14),
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: _primaryMuted, height: 1.5, fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}