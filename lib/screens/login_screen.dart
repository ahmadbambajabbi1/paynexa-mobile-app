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
    setState(() { _error = null; _busy = true; });
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
    setState(() { _error = null; _busy = true; });
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
      await context.read<AuthController>().applySessionToken(res.token, pinBootstrap: res);
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
      await context.read<AuthController>().applySessionToken(res.token, pinBootstrap: res);
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
    final mq = MediaQuery.of(context);
    final screenHeight = mq.size.height - mq.padding.top - mq.padding.bottom;

    return AuthPageScaffold(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Use the taller of layout constraints or screen height
          final height = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : screenHeight;

          return SizedBox(
            height: height,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── TOP: logo + title + subtitle + dots ──────────
                  SizedBox(height: height * 0.07),
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
                  Center(child: Text(_title(), style: displayHeading(context))),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      _subtitle(),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(child: _buildStepDots()),

                  // ── MIDDLE gap: 35% of screen pushes form to center
                  SizedBox(height: height * 0.12),

                  // ── FORM ─────────────────────────────────────────
                  if (_step == _LoginStep.phone) _buildPhone(),
                  if (_step == _LoginStep.code) _buildCode(),
                  if (_step == _LoginStep.pinNew) _buildPinNew(),
                  if (_step == _LoginStep.pinLogin) _buildPinLogin(),

                  // ── BOTTOM: fills remaining space ─────────────────
                  const Spacer(),

                  // ── Disclaimer pinned to bottom ───────────────────
                  if (_step == _LoginStep.phone)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 32),
                      child: Text(
                        'By continuing you agree to use SMS verification for this account.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                      ),
                    )
                  else
                    const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStepDots() {
    final steps = [_LoginStep.phone, _LoginStep.code, _LoginStep.pinNew];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(steps.length, (i) {
        final stepIndex = steps.indexOf(_step);
        final isDone = i < stepIndex;
        final isActive = i == stepIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 20 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: isDone
                ? AppColors.gambianGreen
                : isActive
                    ? AppColors.primaryColorBlack
                    : Colors.grey.shade300,
          ),
        );
      }),
    );
  }

  String _title() {
    switch (_step) {
      case _LoginStep.phone:    return 'Sign in';
      case _LoginStep.code:     return 'Verify phone';
      case _LoginStep.pinNew:   return 'Create PIN';
      case _LoginStep.pinLogin: return 'Welcome back';
    }
  }

  String _subtitle() {
    switch (_step) {
      case _LoginStep.phone:
        return 'Enter your phone number and secure PIN.';
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
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IntlPhoneField(
          initialCountryCode: 'GM',
          decoration: InputDecoration(
            labelText: 'Phone number',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primaryColorBlack, width: 1.5),
            ),
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
            backgroundColor: AppColors.primaryColorBlack,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(_busy ? 'Sending…' : 'Send SMS code'),
        ),
      ],
    );
  }

  Widget _buildCode() {
    return Column(
      mainAxisSize: MainAxisSize.min,
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
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryColorBlack,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(_busy ? 'Checking…' : 'Continue'),
        ),
        TextButton(onPressed: _backToPhone, child: const Text('Change number')),
      ],
    );
  }

  Widget _buildPinNew() {
    return Column(
      mainAxisSize: MainAxisSize.min,
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
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.gambianGreen,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(_busy ? 'Saving…' : 'Create PIN and continue'),
        ),
      ],
    );
  }

  Widget _buildPinLogin() {
    return Column(
      mainAxisSize: MainAxisSize.min,
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
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryColorBlack,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
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