import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_error.dart';
import '../api/users_api.dart';
import '../auth/auth_controller.dart';
import '../theme/app_colors.dart';

class PersonalKycApplyScreen extends StatefulWidget {
  const PersonalKycApplyScreen({super.key});

  @override
  State<PersonalKycApplyScreen> createState() => _PersonalKycApplyScreenState();
}

class _PersonalKycApplyScreenState extends State<PersonalKycApplyScreen> {
  PlatformFile? _idDoc;
  PlatformFile? _selfieDoc;
  bool _busy = false;
  String? _err;

  Future<void> _pick(bool selfie) async {
    final r = await FilePicker.platform.pickFiles(withData: true);
    if (r == null || r.files.isEmpty) return;
    setState(() {
      if (selfie) {
        _selfieDoc = r.files.first;
      } else {
        _idDoc = r.files.first;
      }
    });
  }

  Future<void> _submit() async {
    final auth = context.read<AuthController>();
    final token = auth.token;
    if (token == null || _idDoc?.bytes == null || _selfieDoc?.bytes == null) {
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      final idKey = await uploadKycFile(token, _idDoc!.bytes!, _idDoc!.name);
      final selfieKey =
          await uploadKycFile(token, _selfieDoc!.bytes!, _selfieDoc!.name);
      await submitKycDocument(
        token,
        kind: 'PERSONAL',
        fileKey: idKey,
        uploader: 'personal:government_id',
      );
      await submitKycDocument(
        token,
        kind: 'PERSONAL',
        fileKey: selfieKey,
        uploader: 'personal:selfie',
      );
      await auth.refreshUser();
      if (!mounted) return;
      setState(() {
        _idDoc = null;
        _selfieDoc = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Submitted for admin review.')),
      );
    } catch (e) {
      setState(() => _err = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final u = auth.user;

    if (u != null && u.personalKycApproved) {
      return Scaffold(
        appBar: AppBar(title: const Text('Personal KYC')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'Your personal KYC is approved. You can create transactions from the Transactions tab.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 16),
            ),
          ),
        ),
      );
    }

    if (u?.personalKycStatus == 'PENDING') {
      return Scaffold(
        appBar: AppBar(title: const Text('Personal KYC')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'Your documents are with an administrator for review (version v${u?.personalKycVersion ?? '—'}). '
              'You cannot create transactions until they are approved.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 16),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Apply personal KYC')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Upload your ID card and selfie. After you submit, an administrator must approve your KYC before you can create transactions.',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          if (u?.personalKycStatus == 'REJECTED' &&
              u?.personalKycRejectedReason != null &&
              u!.personalKycRejectedReason!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Material(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Previous submission was not approved',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(u.personalKycRejectedReason!, style: TextStyle(color: Colors.red.shade900)),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          ListTile(
            title: const Text('Government ID card'),
            subtitle: Text(_idDoc?.name ?? 'Tap to choose file'),
            trailing: const Icon(Icons.upload_file),
            onTap: _busy ? null : () => _pick(false),
          ),
          ListTile(
            title: const Text('Selfie'),
            subtitle: Text(_selfieDoc?.name ?? 'Tap to choose file'),
            trailing: const Icon(Icons.camera_alt_outlined),
            onTap: _busy ? null : () => _pick(true),
          ),
          if (_err != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_err!, style: TextStyle(color: Colors.red.shade700)),
            ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _submit,
            style: FilledButton.styleFrom(backgroundColor: AppColors.gambianBlue),
            child: Text(_busy ? 'Submitting...' : 'Submit for review'),
          ),
        ],
      ),
    );
  }
}
