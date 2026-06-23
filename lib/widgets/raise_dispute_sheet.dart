import 'package:flutter/material.dart';

class RaiseDisputeSheet extends StatefulWidget {
  const RaiseDisputeSheet({super.key, required this.onSubmit});

  final Future<void> Function(String reason) onSubmit;

  static Future<void> show(
    BuildContext context, {
    required Future<void> Function(String reason) onSubmit,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: RaiseDisputeSheet(onSubmit: onSubmit),
      ),
    );
  }

  @override
  State<RaiseDisputeSheet> createState() => _RaiseDisputeSheetState();
}

class _RaiseDisputeSheetState extends State<RaiseDisputeSheet> {
  static const _max = 500;
  final _controller = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final len = _controller.text.length;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Raise dispute', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text('Please describe the issue with this transaction.'),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              maxLength: _max,
              maxLines: 5,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Problem description',
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Text('$len/$_max', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy || _controller.text.trim().isEmpty
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      try {
                        await widget.onSubmit(_controller.text.trim());
                        if (context.mounted) Navigator.of(context).pop();
                      } finally {
                        if (mounted) setState(() => _busy = false);
                      }
                    },
              child: Text(_busy ? 'Submitting…' : 'Submit dispute'),
            ),
          ],
        ),
      ),
    );
  }
}
