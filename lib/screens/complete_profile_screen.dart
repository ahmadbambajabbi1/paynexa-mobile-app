import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_error.dart';
import '../auth/auth_controller.dart';
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

  String? _error;
  bool _busy = false;
  bool _seeded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    _seeded = true;
    final u = context.read<AuthController>().user;
    if (u == null) return;
    _displayCtrl.text = u.displayName ?? '';
    _fullCtrl.text = u.fullName ?? '';
  }

  @override
  void dispose() {
    _displayCtrl.dispose();
    _fullCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      final auth = context.read<AuthController>();
      await auth.submitProfileDetails(
        displayName: _displayCtrl.text.trim(),
        fullName: _fullCtrl.text.trim(),
      );
      if (!mounted) return;
      await auth.refreshUser();
    } catch (e) {
      if (!mounted) return;
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
                'Complete your profile',
                style: displayHeading(context),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                'Add your display name and legal full name to start using Paynexa.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
            ),
            const Spacer(),
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
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _busy ? null : _submitForm(),
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
            const Spacer(),
          ],
        ),
      ),
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
