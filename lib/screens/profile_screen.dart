// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';

// import '../auth/auth_controller.dart';
// import '../models/me_user.dart';
// import '../theme/app_colors.dart';
// import '../widgets/glass_card.dart';
// import '../widgets/profile_pricing_section.dart';
// import 'billings_screen.dart';
// import 'kyc_apply_screen.dart';

// bool _hasApprovedProfessional(MeUser user) {
//   final l = user.applicationForRole('LAWYER');
//   if (l?.isApproved == true) return true;
//   final a = user.applicationForRole('AGENT');
//   return a?.isApproved == true;
// }

// class ProfileScreen extends StatelessWidget {
//   const ProfileScreen({super.key});

//   String _initials(MeUser user) {
//     final d = user.displayName?.trim();
//     final f = user.fullName?.trim();
//     final src = (d != null && d.isNotEmpty)
//         ? d
//         : (f != null && f.isNotEmpty)
//             ? f
//             : (user.phone ?? user.email ?? '?');
//     final parts = src.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
//     if (parts.length >= 2) {
//       return (parts[0][0] + parts[1][0]).toUpperCase();
//     }
//     return src.substring(0, src.length >= 2 ? 2 : 1).toUpperCase();
//   }

//   Future<void> _openApplyFlow(BuildContext context, MeUser user) async {
//     final canLawyer = user.canApplyProfessionalKyc('LAWYER');
//     final canAgent = user.canApplyProfessionalKyc('AGENT');
//     if (!canLawyer && !canAgent) return;
//     String? selectedRole;
//     if (canLawyer && canAgent) {
//       selectedRole = await showModalBottomSheet<String>(
//         context: context,
//         shape: const RoundedRectangleBorder(
//           borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
//         ),
//         builder: (context) => SafeArea(
//           child: Padding(
//             padding: const EdgeInsets.all(20),
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 const Text('Choose role', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//                 const SizedBox(height: 8),
//                 Text(
//                   'You can apply as either Lawyer or Agent.',
//                   style: TextStyle(color: Colors.grey.shade600),
//                 ),
//                 const SizedBox(height: 16),
//                 ListTile(
//                   leading: const Icon(Icons.gavel_rounded),
//                   title: const Text('Lawyer'),
//                   onTap: () => Navigator.of(context).pop('LAWYER'),
//                 ),
//                 ListTile(
//                   leading: const Icon(Icons.handshake_rounded),
//                   title: const Text('Agent'),
//                   onTap: () => Navigator.of(context).pop('AGENT'),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       );
//     } else {
//       selectedRole = canLawyer ? 'LAWYER' : 'AGENT';
//     }
//     if (selectedRole == null || !context.mounted) return;
//     await Navigator.of(context).push<void>(
//       MaterialPageRoute<void>(
//         builder: (_) => KycApplyScreen(initialRole: selectedRole),
//       ),
//     );
//   }

//   Widget _igTitleRow(BuildContext context, String displayTitle, bool canApplyAny, MeUser user) {
//     return Row(
//       crossAxisAlignment: CrossAxisAlignment.center,
//       children: [
//         Expanded(
//           child: Text(
//             displayTitle,
//             style: const TextStyle(
//               fontSize: 24,
//               fontWeight: FontWeight.w600,
//               letterSpacing: -0.4,
//             ),
//             maxLines: 2,
//             overflow: TextOverflow.ellipsis,
//           ),
//         ),
//         if (canApplyAny) ...[
//           const SizedBox(width: 12),
//           FilledButton(
//             onPressed: () => _openApplyFlow(context, user),
//             style: FilledButton.styleFrom(
//               backgroundColor: AppColors.primaryColorBlack,
//               foregroundColor: Colors.white,
//               padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
//               minimumSize: Size.zero,
//               tapTargetSize: MaterialTapTargetSize.shrinkWrap,
//             ),
//             child: const Text('Apply'),
//           ),
//         ],
//       ],
//     );
//   }

//   Widget _igInfoLine(IconData icon, String value) {
//     return Row(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Padding(
//           padding: const EdgeInsets.only(top: 1),
//           child: Icon(icon, size: 18, color: Colors.grey.shade600),
//         ),
//         const SizedBox(width: 10),
//         Expanded(
//           child: SelectableText(
//             value,
//             style: TextStyle(
//               fontSize: 14,
//               height: 1.35,
//               color: Colors.grey.shade900,
//             ),
//             textAlign: TextAlign.start,
//           ),
//         ),
//       ],
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final auth = context.watch<AuthController>();
//     final user = auth.user;
//     final token = auth.token;
//     if (user == null) {
//       return const Center(child: CircularProgressIndicator());
//     }

//     final lawyer = user.applicationForRole('LAWYER');
//     final agent = user.applicationForRole('AGENT');
//     final canApplyAny = user.canApplyProfessionalKyc('LAWYER') || user.canApplyProfessionalKyc('AGENT');
//     final approvedApp = lawyer?.isApproved == true
//         ? lawyer
//         : (agent?.isApproved == true ? agent : null);
//     final professionalLabel = approvedApp == null
//         ? 'Professional account'
//         : (approvedApp.role == 'LAWYER' ? 'Lawyer' : 'Agent');

//     final displayTitle = user.displayName?.trim().isNotEmpty == true
//         ? user.displayName!.trim()
//         : (user.fullName?.trim().isNotEmpty == true ? user.fullName!.trim() : 'Your account');

//     return RefreshIndicator(
//       onRefresh: () => context.read<AuthController>().refreshUser(),
//       child: ListView(
//         padding: const EdgeInsets.only(bottom: 32),
//         children: [
//         GlassCard(
//           padding: EdgeInsets.zero,
//           child: ClipRRect(
//             borderRadius: BorderRadius.circular(16),
//             child: LayoutBuilder(
//               builder: (context, constraints) {
//                 final wide = constraints.maxWidth >= 520;
//                 final avatar = Container(
//                   width: wide ? 148 : 132,
//                   height: wide ? 148 : 132,
//                   padding: const EdgeInsets.all(3),
//                   decoration: BoxDecoration(
//                     shape: BoxShape.circle,
//                     border: Border.all(color: Colors.grey.shade300, width: 1),
//                     color: Colors.white,
//                   ),
//                   child: DecoratedBox(
//                     decoration: BoxDecoration(
//                       shape: BoxShape.circle,
//                       gradient: LinearGradient(
//                         begin: Alignment.topLeft,
//                         end: Alignment.bottomRight,
//                         colors: [Colors.grey.shade100, Colors.grey.shade50],
//                       ),
//                     ),
//                     child: Center(
//                       child: Text(
//                         _initials(user),
//                         style: TextStyle(
//                           color: Colors.grey.shade800,
//                           fontSize: wide ? 44 : 38,
//                           fontWeight: FontWeight.w600,
//                           letterSpacing: 0.5,
//                         ),
//                       ),
//                     ),
//                   ),
//                 );

//                 final infoColumn = Column(
//                   crossAxisAlignment: CrossAxisAlignment.stretch,
//                   children: [
//                     Row(
//                       crossAxisAlignment: CrossAxisAlignment.center,
//                       children: [
//                         if (wide) Expanded(child: _igTitleRow(context, displayTitle, canApplyAny, user)),
//                         if (!wide) ...[
//                           Expanded(
//                             child: Text(
//                               displayTitle,
//                               textAlign: TextAlign.start,
//                               style: const TextStyle(
//                                 fontSize: 22,
//                                 fontWeight: FontWeight.w600,
//                                 letterSpacing: -0.3,
//                               ),
//                             ),
//                           ),
//                           if (canApplyAny)
//                             FilledButton(
//                               onPressed: () => _openApplyFlow(context, user),
//                               style: FilledButton.styleFrom(
//                                 backgroundColor: AppColors.primaryColorBlack,
//                                 foregroundColor: Colors.white,
//                                 padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
//                                 minimumSize: Size.zero,
//                                 tapTargetSize: MaterialTapTargetSize.shrinkWrap,
//                               ),
//                               child: const Text('Apply'),
//                             ),
//                         ],
//                       ],
//                     ),
//                     if (!wide && canApplyAny) const SizedBox(height: 4),
//                     if (user.fullName?.trim().isNotEmpty == true &&
//                         user.displayName?.trim() != user.fullName?.trim())
//                       Padding(
//                         padding: EdgeInsets.only(top: wide ? 6 : 10),
//                         child: Text(
//                           user.fullName!.trim(),
//                           textAlign: TextAlign.start,
//                           style: TextStyle(
//                             fontSize: 15,
//                             fontWeight: FontWeight.w600,
//                             color: Colors.grey.shade900,
//                           ),
//                         ),
//                       ),
//                     SizedBox(height: wide ? 14 : 12),
//                     _igInfoLine(
//                       Icons.alternate_email_rounded,
//                       user.email?.isNotEmpty == true ? user.email! : '—',
//                     ),
//                     const SizedBox(height: 8),
//                     _igInfoLine(
//                       Icons.phone_iphone_rounded,
//                       user.phone?.isNotEmpty == true ? user.phone! : '—',
//                     ),
//                     const SizedBox(height: 12),
//                     Wrap(
//                       alignment: WrapAlignment.start,
//                       spacing: 8,
//                       runSpacing: 8,
//                       children: [
//                         Container(
//                           padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//                           decoration: BoxDecoration(
//                             borderRadius: BorderRadius.circular(6),
//                             border: Border.all(color: Colors.grey.shade300),
//                           ),
//                           child: Text(
//                             professionalLabel,
//                             style: TextStyle(
//                               fontSize: 12,
//                               fontWeight: FontWeight.w600,
//                               color: Colors.grey.shade800,
//                             ),
//                           ),
//                         ),
//                         if (user.emailVerifiedAt != null)
//                           Container(
//                             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//                             decoration: BoxDecoration(
//                               borderRadius: BorderRadius.circular(6),
//                               border: Border.all(
//                                 color: AppColors.gambianGreen.withValues(alpha: 0.45),
//                               ),
//                               color: AppColors.gambianGreen.withValues(alpha: 0.08),
//                             ),
//                             child: Row(
//                               mainAxisSize: MainAxisSize.min,
//                               children: [
//                                 Icon(Icons.verified_outlined, size: 16, color: AppColors.gambianGreen),
//                                 const SizedBox(width: 4),
//                                 Text(
//                                   'Email verified',
//                                   style: TextStyle(
//                                     fontSize: 12,
//                                     fontWeight: FontWeight.w600,
//                                     color: AppColors.gambianGreen,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                       ],
//                     ),
//                   ],
//                 );

//                 return Padding(
//                   padding: EdgeInsets.fromLTRB(wide ? 28 : 20, 28, wide ? 28 : 20, 24),
//                   child: wide
//                       ? Row(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             avatar,
//                             const SizedBox(width: 36),
//                             Expanded(child: infoColumn),
//                           ],
//                         )
//                       : Column(
//                           children: [
//                             Center(child: avatar),
//                             const SizedBox(height: 20),
//                             infoColumn,
//                           ],
//                         ),
//                 );
//               },
//             ),
//           ),
//         ),
//         if (token != null && token.isNotEmpty && _hasApprovedProfessional(user)) ...[
//           const SizedBox(height: 16),
//           ProfilePricingSection(token: token),
//         ],
//         const SizedBox(height: 16),
//         GlassCard(
//           child: ListTile(
//             contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
//             leading: const Icon(Icons.account_balance_wallet_outlined),
//             title: const Text('Wallet'),
//             subtitle: const Text('Manage balance, deposits, and withdrawals'),
//             trailing: const Icon(Icons.chevron_right),
//             onTap: () {
//               Navigator.of(context).push(
//                 MaterialPageRoute<void>(
//                   builder: (_) => const BillingsScreen(),
//                 ),
//               );
//             },
//           ),
//         ),
//         ],
//       ),
//     );
//   }
// }
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../auth/auth_controller.dart';
import '../models/me_user.dart';
import '../theme/app_colors.dart';
import 'billings_screen.dart';
import 'kyc_apply_screen.dart';
import '../widgets/profile_pricing_section.dart';

bool _hasApprovedProfessional(MeUser user) {
  final l = user.applicationForRole('LAWYER');
  if (l?.isApproved == true) return true;
  final a = user.applicationForRole('AGENT');
  return a?.isApproved == true;
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  String _initials(MeUser user) {
    final d = user.displayName?.trim();
    final f = user.fullName?.trim();
    final src = (d != null && d.isNotEmpty)
        ? d
        : (f != null && f.isNotEmpty)
        ? f
        : (user.phone ?? user.email ?? '?');
    final parts = src.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return src.substring(0, src.length >= 2 ? 2 : 1).toUpperCase();
  }

  Future<void> _openApplyFlow(BuildContext context, MeUser user) async {
    final canLawyer = user.canApplyProfessionalKyc('LAWYER');
    final canAgent = user.canApplyProfessionalKyc('AGENT');
    if (!canLawyer && !canAgent) return;
    String? selectedRole;
    if (canLawyer && canAgent) {
      selectedRole = await showModalBottomSheet<String>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose role',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'You can apply as either Lawyer or Agent.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
                const SizedBox(height: 16),
                _RoleOption(
                  icon: Icons.gavel_rounded,
                  title: 'Lawyer',
                  subtitle: 'Provide legal services',
                  onTap: () => Navigator.of(context).pop('LAWYER'),
                ),
                const SizedBox(height: 8),
                _RoleOption(
                  icon: Icons.handshake_rounded,
                  title: 'Agent',
                  subtitle: 'Provide escrow facilitation',
                  onTap: () => Navigator.of(context).pop('AGENT'),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      selectedRole = canLawyer ? 'LAWYER' : 'AGENT';
    }
    if (selectedRole == null || !context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => KycApplyScreen(initialRole: selectedRole),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.user;
    final token = auth.token;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final lawyer = user.applicationForRole('LAWYER');
    final agent = user.applicationForRole('AGENT');
    final canApplyAny =
        user.canApplyProfessionalKyc('LAWYER') ||
        user.canApplyProfessionalKyc('AGENT');
    final approvedApp = lawyer?.isApproved == true
        ? lawyer
        : (agent?.isApproved == true ? agent : null);
    final professionalLabel = approvedApp == null
        ? 'Personal account'
        : (approvedApp.role == 'LAWYER' ? 'Lawyer' : 'Agent');

    final displayTitle = user.displayName?.trim().isNotEmpty == true
        ? user.displayName!.trim()
        : (user.fullName?.trim().isNotEmpty == true
              ? user.fullName!.trim()
              : 'Your account');

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: AppColors.primaryColorBlack,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: AppColors.primaryColorBlack,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.pageGradientStart,
        body: RefreshIndicator(
          onRefresh: () => context.read<AuthController>().refreshUser(),
          color: AppColors.primaryColorBlack,
          backgroundColor: Colors.white,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Profile Header
              SliverToBoxAdapter(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primaryColorBlack,
                        // Color(0xFF102A18),
                        AppColors.primaryColorBlack,
                        // Color(0xFF2B0710),
                        AppColors.primaryColorBlack,
                      ],
                    ),
                    // border: Border(
                    //   bottom: BorderSide(
                    //     color: AppColors.gambianGold,
                    //     width: 2,
                    //   ),
                    // ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 18, 24, 42),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.15),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.30),
                                    width: 3,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    _initials(user),
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displayTitle,
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                    if (user.fullName?.trim().isNotEmpty ==
                                            true &&
                                        user.displayName?.trim() !=
                                            user.fullName?.trim())
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          user.fullName!.trim(),
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.white.withValues(
                                              alpha: 0.72,
                                            ),
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: [
                                        _HeaderBadge(
                                          label: professionalLabel,
                                          isPrimary: true,
                                        ),
                                        if (user.emailVerifiedAt != null)
                                          _HeaderBadge(
                                            label: 'Verified',
                                            icon: Icons.verified_outlined,
                                            isSuccess: true,
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          // if (canApplyAny) ...[
                          //   const SizedBox(height: 16),
                          //   SizedBox(
                          //     width: double.infinity,
                          //     child: FilledButton.icon(
                          //       onPressed: () => _openApplyFlow(context, user),
                          //       icon: const Icon(Icons.add, size: 18),
                          //       label: const Text('Apply for Professional'),
                          //       style: FilledButton.styleFrom(
                          //         backgroundColor: Colors.white,
                          //         foregroundColor: AppColors.primaryColorBlack,
                          //         padding: const EdgeInsets.symmetric(vertical: 12),
                          //         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          //       ),
                          //     ),
                          //   ),
                          // ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Content
              SliverToBoxAdapter(
                child: Transform.translate(
                  offset: const Offset(0, -8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.pageGradientStart,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Contact Info
                          _ProfileSection(
                            title: 'Contact Information',
                            children: [
                              _InfoTile(
                                icon: Icons.alternate_email_rounded,
                                iconColor: Colors.blue.shade600,
                                iconBg: Colors.blue.shade50,
                                label: 'Email',
                                value: user.email?.isNotEmpty == true
                                    ? user.email!
                                    : '—',
                                badge: user.emailVerifiedAt != null
                                    ? 'Verified'
                                    : null,
                              ),
                              const SizedBox(height: 10),
                              _InfoTile(
                                icon: Icons.phone_iphone_rounded,
                                iconColor: Colors.green.shade600,
                                iconBg: Colors.green.shade50,
                                label: 'Phone',
                                value: user.phone?.isNotEmpty == true
                                    ? user.phone!
                                    : '—',
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Account Details
                          _ProfileSection(
                            title: 'Account Details',
                            children: [
                              _DetailRow(
                                label: 'Account Type',
                                value: professionalLabel,
                              ),
                              const Divider(height: 1),
                              _DetailRow(
                                label: 'Verification Status',
                                value: user.emailVerifiedAt != null
                                    ? 'Verified'
                                    : 'Pending',
                                valueColor: user.emailVerifiedAt != null
                                    ? Colors.green.shade700
                                    : Colors.orange.shade700,
                              ),
                              if (approvedApp != null) ...[
                                const Divider(height: 1),
                                _DetailRow(
                                  label: 'Personal Role',
                                  value: approvedApp.role,
                                ),
                              ],
                            ],
                          ),
                          if (token != null &&
                              token.isNotEmpty &&
                              _hasApprovedProfessional(user)) ...[
                            const SizedBox(height: 16),
                            ProfilePricingSection(token: token),
                          ],
                          const SizedBox(height: 16),
                          // Wallet Link
                          // _WalletTile(
                          //   onTap: () {
                          //     Navigator.of(context).push(
                          //       MaterialPageRoute<void>(builder: (_) => const BillingsScreen()),
                          //     );
                          //   },
                          // ),
                          // const SizedBox(height: 12),
                          const _SignOutSection(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderBadge extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isPrimary;
  final bool isSuccess;

  const _HeaderBadge({
    required this.label,
    this.icon,
    this.isPrimary = false,
    this.isSuccess = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isPrimary
            ? Colors.white.withValues(alpha: 0.15)
            : isSuccess
            ? Colors.green.withValues(alpha: 0.20)
            : Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPrimary
              ? Colors.white.withValues(alpha: 0.25)
              : isSuccess
              ? Colors.green.withValues(alpha: 0.30)
              : Colors.white.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 12,
              color: isSuccess
                  ? Colors.green.shade300
                  : Colors.white.withValues(alpha: 0.90),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isSuccess
                  ? Colors.green.shade100
                  : Colors.white.withValues(alpha: 0.90),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _RoleOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primaryColorBlack.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primaryColorBlack),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _ProfileSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.grey.shade500,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String value;
  final String? badge;

  const _InfoTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.value,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                badge!,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.green.shade700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: valueColor ?? Colors.grey.shade900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SignOutSection extends StatelessWidget {
  const _SignOutSection();

  Future<void> _confirmAndSignOut(BuildContext context) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out'),
        content: const Text(
          'You will need to sign in again to access your account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.gambianRed,
            ),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (go == true && context.mounted) {
      await context.read<AuthController>().logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _confirmAndSignOut(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.gambianRed.withValues(alpha: 0.35),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.gambianRed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.logout_rounded,
                color: Colors.red.shade800,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sign out',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: Colors.red.shade900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'End this session on this device',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}

class _WalletTile extends StatelessWidget {
  final VoidCallback onTap;

  const _WalletTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryColorBlack.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.account_balance_wallet_outlined,
                color: AppColors.primaryColorBlack,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Wallet',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Manage balance, deposits, and withdrawals',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
