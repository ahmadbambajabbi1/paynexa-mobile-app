import 'package:flutter/material.dart';

import '../api/transactions_api.dart' as tx_api;
import '../models/transaction_models.dart';
import '../theme/app_colors.dart';

class DisputeThreadSection extends StatefulWidget {
  const DisputeThreadSection({
    super.key,
    required this.token,
    required this.transactionId,
    required this.actorId,
    required this.selfRole,
    required this.disputes,
    required this.onReload,
    required this.onOpenNewDispute,
  });

  final String token;
  final String transactionId;
  final String actorId;
  final String? selfRole;
  final List<DisputeItem> disputes;
  final Future<void> Function() onReload;
  final VoidCallback onOpenNewDispute;

  @override
  State<DisputeThreadSection> createState() => _DisputeThreadSectionState();
}

class _DisputeThreadSectionState extends State<DisputeThreadSection> {
  final _noteController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  DisputeItem? get _dispute => widget.disputes.isEmpty ? null : widget.disputes.first;

  List<DisputeThreadMessage> get _thread => _dispute?.thread ?? const [];

  bool get _isResolved =>
      _dispute?.status == 'RESOLVED' || (_dispute?.resolution?.isNotEmpty ?? false);

  bool get _hasSubmittedComplaint =>
      widget.selfRole != null &&
      _thread.any((m) => m.kind == 'opening' && m.actorRole == widget.selfRole);

  bool get _canOpenOrJoin =>
      widget.selfRole != null && !_hasSubmittedComplaint && !_isResolved;

  Future<void> _sendNote() async {
    final dispute = _dispute;
    if (dispute == null) return;
    final message = _noteController.text.trim();
    if (message.isEmpty) return;
    setState(() => _busy = true);
    try {
      await tx_api.respondToTransactionDispute(
        widget.token,
        widget.transactionId,
        dispute.id,
        actorId: widget.actorId,
        message: message,
      );
      _noteController.clear();
      await widget.onReload();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.disputes.isEmpty && widget.selfRole == null) {
      return const SizedBox.shrink();
    }

    final dispute = _dispute;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Dispute conversation',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              if (_canOpenOrJoin)
                TextButton(
                  onPressed: widget.onOpenNewDispute,
                  child: Text(dispute == null ? 'Open dispute' : 'Add your complaint'),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Buyer and seller share one thread. Both can file a complaint and reply.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          if (dispute != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Opened ${DateTime.tryParse(dispute.createdAt)?.toLocal() ?? dispute.createdAt}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
                Text(dispute.status, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
            const SizedBox(height: 10),
            ..._thread.map(_messageBubble),
            if (widget.selfRole != null && _hasSubmittedComplaint && !_isResolved) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _noteController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Reply in this conversation',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: _busy ? null : _sendNote,
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primaryColorBlack),
                  child: const Text('Send reply'),
                ),
              ),
            ],
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('No dispute messages yet.', style: TextStyle(color: Colors.grey.shade600)),
            ),
        ],
      ),
    );
  }

  Widget _messageBubble(DisputeThreadMessage m) {
    final isSelf = m.actorRole == widget.selfRole;
    final isOpening = m.kind == 'opening';
    final isResolution = m.kind == 'resolution';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: isSelf ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 300),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isResolution
                ? Colors.green.shade50
                : isOpening
                    ? Colors.red.shade50
                    : isSelf
                        ? AppColors.primaryColorBlack
                        : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
            border: isResolution
                ? Border.all(color: Colors.green.shade200)
                : isOpening
                    ? Border.all(color: Colors.red.shade100)
                    : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isResolution
                    ? 'paynexa · admin decision'
                    : isOpening
                        ? '${m.actorRole} · opening complaint'
                        : m.actorRole,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isResolution
                      ? Colors.green.shade800
                      : isOpening
                          ? Colors.red.shade800
                          : isSelf
                              ? Colors.white70
                              : Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                m.message,
                style: TextStyle(
                  color: isResolution || isOpening
                      ? Colors.black87
                      : isSelf
                          ? Colors.white
                          : Colors.black87,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
