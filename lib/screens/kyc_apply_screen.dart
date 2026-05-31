import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../api/api_error.dart';
import '../api/users_api.dart';
import '../auth/auth_controller.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_card.dart';

class KycApplyScreen extends StatefulWidget {
  const KycApplyScreen({super.key, this.initialRole});

  /// Uppercase `LAWYER` or `AGENT` when opened from profile.
  final String? initialRole;

  @override
  State<KycApplyScreen> createState() => _KycApplyScreenState();
}

class _KycApplyScreenState extends State<KycApplyScreen> {
  int _step = 0;
  String? _role;
  bool _busy = false;
  String? _err;
  bool _done = false;
  String? _ineligibleMessage;

  final _lawyerBar = TextEditingController();
  final _lawyerBody = TextEditingController();
  final _lawyerFirm = TextEditingController();
  final _lawyerYears = TextEditingController();

  final _agentId = TextEditingController();
  final _agentLicense = TextEditingController();
  final _agentEmployer = TextEditingController();

  PlatformFile? _govFile;
  PlatformFile? _certFile;
  PlatformFile? _extraFile;
  Uint8List? _selfieBytes;
  String? _selfieName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthController>().user;
      final raw = widget.initialRole?.toUpperCase().trim();
      if (user == null) return;
      final canLawyer = user.canApplyProfessionalKyc('LAWYER');
      final canAgent = user.canApplyProfessionalKyc('AGENT');
      if (!canLawyer && !canAgent) {
        setState(() {
          _ineligibleMessage =
              'You already have an application submitted. You can apply again only after a rejection.';
        });
        return;
      }
      if (raw == null || (raw != 'LAWYER' && raw != 'AGENT')) return;
      if (!user.canApplyProfessionalKyc(raw)) {
        setState(() {
          _ineligibleMessage = raw == 'LAWYER'
              ? 'You already have a lawyer application in progress or approved.'
              : 'You already have an agent application in progress or approved.';
        });
      } else {
        setState(() {
          _role = raw;
          _step = 1;
        });
      }
    });
  }

  @override
  void dispose() {
    _lawyerBar.dispose();
    _lawyerBody.dispose();
    _lawyerFirm.dispose();
    _lawyerYears.dispose();
    _agentId.dispose();
    _agentLicense.dispose();
    _agentEmployer.dispose();
    super.dispose();
  }

  void _setRole(String r) {
    setState(() {
      _role = r;
      _err = null;
      _step = 1;
      _ineligibleMessage = null;
    });
    final user = context.read<AuthController>().user;
    if (user != null && !user.canApplyProfessionalKyc(r)) {
      setState(() {
        _ineligibleMessage =
            'You are not eligible to start this application right now.';
      });
    }
  }

  Future<void> _pick(String which) async {
    final r = await FilePicker.platform.pickFiles(withData: true);
    if (r == null || r.files.isEmpty) return;
    final f = r.files.first;
    final name = f.name;
    if (!isAllowedKycUploadFilename(name)) {
      setState(() {
        _err = 'Please choose a PDF, JPEG, PNG, WebP, or GIF file (not HEIC).';
      });
      return;
    }
    setState(() {
      _err = null;
      if (which == 'gov') _govFile = f;
      if (which == 'cert') _certFile = f;
      if (which == 'extra') _extraFile = f;
    });
  }

  Future<void> _captureSelfie() async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 85,
    );
    if (photo == null) return;
    final bytes = await photo.readAsBytes();
    if (!mounted) return;
    setState(() {
      _selfieBytes = bytes;
      _selfieName = photo.name.isEmpty ? 'selfie.jpg' : photo.name;
      _err = null;
    });
  }

  Future<void> _submit() async {
    final auth = context.read<AuthController>();
    final token = auth.token;
    final user = auth.user;
    final role = _role;
    if (token == null || role == null || user == null) return;
    if (!user.canApplyProfessionalKyc(role)) {
      setState(() => _err = 'You are not eligible to apply for this role.');
      return;
    }

    setState(() {
      _busy = true;
      _err = null;
    });

    try {
      if (role == 'LAWYER') {
        if (_lawyerBar.text.trim().isEmpty || _lawyerBody.text.trim().isEmpty) {
          throw Exception('Bar registration and regulatory body are required.');
        }
      } else {
        if (_agentId.text.trim().isEmpty) {
          throw Exception('National ID or passport number is required.');
        }
      }
      if (_govFile?.bytes == null) {
        throw Exception('Government ID card or passport is required.');
      }
      if (_selfieBytes == null || _selfieBytes!.isEmpty) {
        throw Exception('Live selfie from camera is required.');
      }
      if (role == 'LAWYER' && _certFile?.bytes == null) {
        throw Exception('Bar certificate is required.');
      }
      if (role == 'AGENT' && _extraFile?.bytes == null) {
        throw Exception('Second ID or license document is required.');
      }

      final details = role == 'LAWYER'
          ? <String, dynamic>{
              'barRegistrationNumber': _lawyerBar.text.trim(),
              'regulatoryBody': _lawyerBody.text.trim(),
              'lawFirmName': _lawyerFirm.text.trim(),
              'yearsLicensed': _lawyerYears.text.trim(),
            }
          : <String, dynamic>{
              'nationalIdOrPassportNumber': _agentId.text.trim(),
              'agentLicenseId': _agentLicense.text.trim(),
              'employerOrAgencyName': _agentEmployer.text.trim(),
            };

      final applied = await applyProfessionalRole(
        token,
        role: role,
        details: details,
      );

      Future<void> docBytes(
        List<int> bytes,
        String filename,
        String uploader,
      ) async {
        if (bytes.isEmpty) throw Exception('Could not read file');
        final name = filename.isEmpty ? 'document.jpg' : filename;
        if (!isAllowedKycUploadFilename(name)) {
          throw Exception('Unsupported file type.');
        }
        final key = await uploadKycFile(token, bytes, name);
        await submitKycDocument(
          token,
          kind: role,
          professionalApplicationId: applied.applicationId,
          fileKey: key,
          uploader: uploader,
        );
      }

      Future<void> doc(PlatformFile f, String uploader) async {
        final bytes = f.bytes;
        if (bytes == null) throw Exception('Could not read file');
        await docBytes(bytes, f.name, uploader);
      }

      await docBytes(
        _selfieBytes!,
        _selfieName ?? 'selfie.jpg',
        '${role.toLowerCase()}:selfie_camera',
      );
      await doc(_govFile!, '${role.toLowerCase()}:government_id');
      if (role == 'LAWYER' && _certFile?.bytes != null) {
        await doc(_certFile!, 'lawyer:bar_certificate');
      }
      if (role == 'AGENT' && _extraFile?.bytes != null) {
        await doc(_extraFile!, 'agent:secondary_id_or_license');
      }
      if (role == 'LAWYER' && _extraFile?.bytes != null) {
        await doc(_extraFile!, 'lawyer:supplemental');
      }

      await auth.refreshUser();
      if (!mounted) return;
      setState(() => _done = true);
    } catch (e) {
      setState(() => _err = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_done) {
      return Scaffold(
        appBar: AppBar(title: const Text('KYC')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: GlassCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.verified_user_rounded,
                    size: 56,
                    color: AppColors.gambianGreen,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Application submitted',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your documents were uploaded securely. An administrator will review your application.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryColorBlack,
                    ),
                    child: const Text('Back to profile'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_ineligibleMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Professional KYC'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: GlassCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 48,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _ineligibleMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryColorBlack,
                    ),
                    child: const Text('OK'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Professional KYC'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          _stepIndicator(context),
          const SizedBox(height: 20),
          if (_step == 0) ..._buildRoleStep(context),
          if (_step == 1 && _role != null) ..._buildDetailsStep(context),
          if (_step == 2 && _role != null) ..._buildUploadStep(context),
          if (_err != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_err!, style: TextStyle(color: Colors.red.shade700)),
            ),
        ],
      ),
    );
  }

  Widget _stepIndicator(BuildContext context) {
    final labels = ['Role', 'Details', 'Documents'];
    return Row(
      children: List.generate(3, (i) {
        final active = _step == i;
        final done = _step > i;
        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: done
                            ? AppColors.gambianGreen
                            : active
                            ? AppColors.primaryColorBlack
                            : Colors.grey.shade300,
                      ),
                      child: done
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 18,
                            )
                          : Text(
                              '${i + 1}',
                              style: TextStyle(
                                color: active
                                    ? Colors.white
                                    : Colors.grey.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      labels[i],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        color: active
                            ? AppColors.primaryColorBlack
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (i < 2)
                Padding(
                  padding: const EdgeInsets.only(bottom: 22),
                  child: Container(
                    height: 2,
                    width: 12,
                    color: _step > i
                        ? AppColors.gambianGreen
                        : Colors.grey.shade300,
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  List<Widget> _buildRoleStep(BuildContext context) {
    return [
      Text(
        'Select your role',
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      Text(
        'KYC is only for lawyers and agents. Choose one to continue.',
        style: TextStyle(color: Colors.grey.shade600, height: 1.4),
      ),
      const SizedBox(height: 20),
      _roleCard(
        context,
        title: 'Lawyer',
        subtitle: 'Bar registration, regulatory body, and ID documents.',
        icon: Icons.gavel_rounded,
        selected: _role == 'LAWYER',
        onTap: () => _setRole('LAWYER'),
      ),
      const SizedBox(height: 12),
      _roleCard(
        context,
        title: 'Agent',
        subtitle: 'ID numbers, license details, and documents.',
        icon: Icons.handshake_rounded,
        selected: _role == 'AGENT',
        onTap: () => _setRole('AGENT'),
      ),
    ];
  }

  Widget _roleCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              width: selected ? 2 : 1,
              color: selected ? AppColors.primaryColorBlack : Colors.grey.shade300,
            ),
            color: selected
                ? AppColors.primaryColorBlack.withValues(alpha: 0.06)
                : Colors.white,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryColorBlack.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primaryColorBlack, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle, color: AppColors.primaryColorBlack),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildDetailsStep(BuildContext context) {
    final role = _role!;
    return [
      Row(
        children: [
          IconButton(
            onPressed: () => setState(() {
              _step = 0;
              _err = null;
            }),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          ),
          Expanded(
            child: Text(
              role == 'LAWYER' ? 'Lawyer credentials' : 'Agent credentials',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      if (role == 'LAWYER') ...[
        TextField(
          controller: _lawyerBar,
          decoration: const InputDecoration(
            labelText: 'Bar registration number *',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _lawyerBody,
          decoration: const InputDecoration(
            labelText: 'Regulatory body *',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _lawyerFirm,
          decoration: const InputDecoration(
            labelText: 'Law firm name',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _lawyerYears,
          decoration: const InputDecoration(
            labelText: 'Years in practice',
            border: OutlineInputBorder(),
          ),
        ),
      ] else ...[
        TextField(
          controller: _agentId,
          decoration: const InputDecoration(
            labelText: 'National ID or passport number *',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _agentLicense,
          decoration: const InputDecoration(
            labelText: 'Agent / license ID',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _agentEmployer,
          decoration: const InputDecoration(
            labelText: 'Employer or agency',
            border: OutlineInputBorder(),
          ),
        ),
      ],
      const SizedBox(height: 24),
      FilledButton(
        onPressed: _busy
            ? null
            : () => setState(() {
                _step = 2;
                _err = null;
              }),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryColorBlack,
          minimumSize: const Size.fromHeight(48),
        ),
        child: const Text('Continue to documents'),
      ),
    ];
  }

  List<Widget> _buildUploadStep(BuildContext context) {
    final role = _role!;
    return [
      Row(
        children: [
          IconButton(
            onPressed: () => setState(() {
              _step = 1;
              _err = null;
            }),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          ),
          Expanded(
            child: Text(
              'Documents',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),
      _uploadTile(
        title: 'Selfie',
        isMandatory: true,
        file: _selfieBytes == null
            ? null
            : PlatformFile(
                name: _selfieName ?? 'selfie.jpg',
                size: _selfieBytes!.length,
                bytes: _selfieBytes,
              ),
        onTap: _captureSelfie,
        emptyLabel: 'Take photo',
        emptyIcon: Icons.photo_camera_outlined,
        filledIcon: Icons.photo_camera_rounded,
      ),
      const SizedBox(height: 12),
      _uploadTile(
        title: 'Government ID card or passport',
        isMandatory: true,
        file: _govFile,
        onTap: () => _pick('gov'),
      ),
      if (role == 'LAWYER') ...[
        const SizedBox(height: 12),
        _uploadTile(
          title: 'Bar certificate',
          isMandatory: true,
          file: _certFile,
          onTap: () => _pick('cert'),
        ),
      ],
      const SizedBox(height: 12),
      _uploadTile(
        title: role == 'LAWYER'
            ? 'Supplemental (optional)'
            : 'Second ID or license *',
        isMandatory: role == 'AGENT',
        file: _extraFile,
        onTap: () => _pick('extra'),
      ),
      const SizedBox(height: 28),
      FilledButton(
        onPressed: _busy ? null : _submit,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryColorBlack,
          minimumSize: const Size.fromHeight(52),
        ),
        child: Text(_busy ? 'Submitting…' : 'Submit application'),
      ),
    ];
  }

  Widget _uploadTile({
    required String title,
    required bool isMandatory,
    required PlatformFile? file,
    required VoidCallback onTap,
    String emptyLabel = 'Tap to choose a file',
    IconData emptyIcon = Icons.cloud_upload_outlined,
    IconData filledIcon = Icons.description_rounded,
  }) {
    final f = file;
    final has = f != null && f.name.isNotEmpty;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _busy ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: has ? AppColors.primaryColorBlack : Colors.grey.shade300,
              width: has ? 2 : 1,
            ),
            color: has
                ? AppColors.primaryColorBlack.withValues(alpha: 0.04)
                : Colors.grey.shade50,
          ),
          child: Row(
            children: [
              Icon(
                has ? filledIcon : emptyIcon,
                size: 32,
                color: has ? AppColors.primaryColorBlack : Colors.grey.shade500,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (isMandatory)
                          Text(
                            ' *',
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      has ? f.name : emptyLabel,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
