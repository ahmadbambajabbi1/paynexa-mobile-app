import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../api/api_error.dart';
import '../auth/auth_controller.dart';
import '../models/me_user.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/page_scaffold.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _displayCtrl = TextEditingController();
  final _fullCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  bool _emailStep = false;
  String? _error;
  bool _busy = false;
  bool _seeded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    _seeded = true;
    final u = context.read<AuthController>().user;
    _applyUser(u);
  }

  void _applyUser(MeUser? u) {
    if (u == null) return;
    _displayCtrl.text = u.displayName ?? '';
    _fullCtrl.text = u.fullName ?? '';
    _emailCtrl.text = u.email ?? '';
    if (u.email != null && u.email!.isNotEmpty && u.emailVerifiedAt == null) {
      _emailStep = true;
    }
  }

  @override
  void dispose() {
    _displayCtrl.dispose();
    _fullCtrl.dispose();
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    setState(() { _error = null; _busy = true; });
    try {
      final auth = context.read<AuthController>();
      final res = await auth.submitProfileDetails(
        displayName: _displayCtrl.text.trim(),
        fullName: _fullCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
      );
      if (!mounted) return;
      if (res.profileComplete == true && res.profileCompletedAt != null) {
        await auth.refreshUser();
        return;
      }
      if (res.needsEmailVerification) {
        setState(() { _emailStep = true; _codeCtrl.clear(); });
      }
    } catch (e) {
      setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyEmail() async {
    setState(() { _error = null; _busy = true; });
    try {
      await context.read<AuthController>().verifyEmailCode(_codeCtrl.text.trim());
    } catch (e) {
      setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    setState(() { _error = null; _busy = true; });
    try {
      await context.read<AuthController>().resendEmailVerification();
    } catch (e) {
      setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthPageScaffold(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── TOP: logo + title + subtitle ─────────────────────
            const SizedBox(height: 48),
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryColorBlack.withOpacity(0.18),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  'assets/images/logo.jpeg',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                _emailStep ? 'Verify your email' : 'Complete your profile',
                style: displayHeading(context),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                _emailStep
                    ? 'Enter the 6-digit code sent to ${_emailCtrl.text}.'
                    : 'Add your display name, full name, and email.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
            ),

            // ── MIDDLE gap ────────────────────────────────────────
            const Spacer(),

            // ── FORM ─────────────────────────────────────────────
            if (!_emailStep) _form(),
            if (_emailStep) _emailPanel(),

            // ── BOTTOM gap ────────────────────────────────────────
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _form() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _displayCtrl,
          decoration: InputDecoration(
            labelText: 'Display name',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primaryColorBlack, width: 1.5),
            ),
          ),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _fullCtrl,
          decoration: InputDecoration(
            labelText: 'Full legal name',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primaryColorBlack, width: 1.5),
            ),
          ),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _emailCtrl,
          decoration: InputDecoration(
            labelText: 'Email',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primaryColorBlack, width: 1.5),
            ),
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        if (_error != null) _err(),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _submitForm,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryColorBlack,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(_busy ? 'Saving…' : 'Continue'),
        ),
      ],
    );
  }

  Widget _emailPanel() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _codeCtrl,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: 'Email code',
            counterText: '',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primaryColorBlack, width: 1.5),
            ),
          ),
          style: const TextStyle(letterSpacing: 6, fontSize: 18),
          onChanged: (_) => setState(() {}),
        ),
        if (_error != null) _err(),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy || _codeCtrl.text.length != 6 ? null : _verifyEmail,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryColorBlack,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(_busy ? 'Verifying…' : 'Verify and continue'),
        ),
        TextButton(onPressed: _busy ? null : _resend, child: const Text('Resend code')),
        TextButton(
          onPressed: () => setState(() { _emailStep = false; _error = null; }),
          child: const Text('Edit profile details'),
        ),
      ],
    );
  }

  Widget _err() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Text(_error!, style: TextStyle(color: Colors.red.shade900)),
      ),
    );
  }
}