import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_field/phone_number.dart';
import 'package:provider/provider.dart';

import '../api/api_error.dart';
import '../api/users_api.dart';
import '../auth/auth_controller.dart';
import '../data/device_id_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/page_scaffold.dart';

enum _LoginStep { phone, code, pinNew, pinLogin }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  _LoginStep _step = _LoginStep.phone;
  PhoneNumber? _phone;
  String _countryIso2 = 'GM';
  final _codeCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _pinConfirmCtrl = TextEditingController();
  String? _preAuthToken;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _pinCtrl.dispose();
    _pinConfirmCtrl.dispose();
    super.dispose();
  }

  String _e164() {
    final p = _phone;
    if (p == null) return '';
    final c = p.completeNumber;
    return c.startsWith('+') ? c : '+$c';
  }

  bool _phoneOk() {
    final e = _e164().trim();
    return RegExp(r'^\+\d{8,15}$').hasMatch(e);
  }

  Future<void> _sendCode() async {
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      await phoneSendCode(_e164().trim(), _countryIso2);
      setState(() => _step = _LoginStep.code);
    } catch (e) {
      setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifySms() async {
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      final res = await phoneVerifySms(_e164().trim(), _codeCtrl.text.trim());
      setState(() {
        _preAuthToken = res.preAuthToken;
        _step = res.nextStep == 'set_pin' ? _LoginStep.pinNew : _LoginStep.pinLogin;
        _pinCtrl.clear();
        _pinConfirmCtrl.clear();
      });
    } catch (e) {
      setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setPin() async {
    setState(() => _error = null);
    if (_pinCtrl.text != _pinConfirmCtrl.text) {
      setState(() => _error = 'PINs do not match.');
      return;
    }
    if (!RegExp(r'^\d{4}$').hasMatch(_pinCtrl.text)) {
      setState(() => _error = 'PIN must be exactly 4 digits.');
      return;
    }
    final pre = _preAuthToken;
    if (pre == null) {
      setState(() => _error = 'Session expired. Start again.');
      return;
    }
    setState(() => _busy = true);
    try {
      final deviceId = await DeviceIdService.instance.getOrCreate();
      final res = await phoneSetPin(
        preAuthToken: pre,
        pin: _pinCtrl.text,
        deviceId: deviceId,
        countryCode: _countryIso2,
      );
      if (!mounted) return;
      await context.read<AuthController>().applySessionToken(
            res.token,
            pinBootstrap: res,
          );
    } catch (e) {
      setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyPin() async {
    setState(() => _error = null);
    if (!RegExp(r'^\d{4}$').hasMatch(_pinCtrl.text)) {
      setState(() => _error = 'PIN must be exactly 4 digits.');
      return;
    }
    final pre = _preAuthToken;
    if (pre == null) {
      setState(() => _error = 'Session expired. Start again.');
      return;
    }
    setState(() => _busy = true);
    try {
      final deviceId = await DeviceIdService.instance.getOrCreate();
      final res = await phoneVerifyPin(
        preAuthToken: pre,
        pin: _pinCtrl.text,
        deviceId: deviceId,
        countryCode: _countryIso2,
      );
      if (!mounted) return;
      await context.read<AuthController>().applySessionToken(
            res.token,
            pinBootstrap: res,
          );
    } catch (e) {
      setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _backToPhone() {
    setState(() {
      _step = _LoginStep.phone;
      _codeCtrl.clear();
      _preAuthToken = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AuthPageScaffold(
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.heroIconGradient,
                boxShadow: [
                  BoxShadow(blurRadius: 12, offset: Offset(0, 4), color: Colors.black26),
                ],
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.phone_android, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 16),
            Text('Sign in', style: displayHeading(context)),
            const SizedBox(height: 8),
            Text(
              _subtitle(),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 24),
            if (_step == _LoginStep.phone) _buildPhone(),
            if (_step == _LoginStep.code) _buildCode(),
            if (_step == _LoginStep.pinNew) _buildPinNew(),
            if (_step == _LoginStep.pinLogin) _buildPinLogin(),
            if (_step == _LoginStep.phone) ...[
              const SizedBox(height: 24),
              Text(
                'By continuing you agree to use SMS verification for this account.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _subtitle() {
    switch (_step) {
      case _LoginStep.phone:
        return 'One account for buying and selling — phone number and secure PIN.';
      case _LoginStep.code:
        return 'Enter the code sent to ${_e164()}';
      case _LoginStep.pinNew:
        return 'Create your 4-digit PIN';
      case _LoginStep.pinLogin:
        return 'Enter your PIN';
    }
  }

  Widget _buildPhone() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IntlPhoneField(
          initialCountryCode: 'GM',
          decoration: InputDecoration(
            labelText: 'Phone number',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onChanged: (PhoneNumber p) {
            setState(() {
              _phone = p;
              _countryIso2 = p.countryISOCode;
            });
          },
        ),
        if (_error != null) _errorBox(),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy || !_phoneOk() ? null : _sendCode,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.gambianBlue,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: Text(_busy ? 'Sending…' : 'Send SMS code'),
        ),
      ],
    );
  }

  Widget _buildCode() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _codeCtrl,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'SMS code',
            counterText: '',
          ),
          style: const TextStyle(letterSpacing: 6, fontSize: 18),
          onChanged: (_) => setState(() {}),
        ),
        if (_error != null) _errorBox(),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy || _codeCtrl.text.length != 6 ? null : _verifySms,
          style: FilledButton.styleFrom(backgroundColor: AppColors.gambianBlue),
          child: Text(_busy ? 'Checking…' : 'Continue'),
        ),
        TextButton(onPressed: _backToPhone, child: const Text('Change number')),
      ],
    );
  }

  Widget _buildPinNew() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _pinCtrl,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 4,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(labelText: 'PIN', counterText: ''),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _pinConfirmCtrl,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 4,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(labelText: 'Confirm PIN', counterText: ''),
          onChanged: (_) => setState(() {}),
        ),
        if (_error != null) _errorBox(),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _setPin,
          style: FilledButton.styleFrom(backgroundColor: AppColors.gambianGreen),
          child: Text(_busy ? 'Saving…' : 'Create PIN and continue'),
        ),
      ],
    );
  }

  Widget _buildPinLogin() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _pinCtrl,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 4,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(labelText: 'PIN', counterText: ''),
          onChanged: (_) => setState(() {}),
        ),
        if (_error != null) _errorBox(),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _verifyPin,
          style: FilledButton.styleFrom(backgroundColor: AppColors.gambianBlue),
          child: Text(_busy ? 'Signing in…' : 'Sign in'),
        ),
      ],
    );
  }

  Widget _errorBox() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Text(_error!, style: TextStyle(color: Colors.red.shade900, fontSize: 14)),
      ),
    );
  }
}
