import 'package:flutter/material.dart';

void showSnack(BuildContext context, String message) {
  final msg = message.trim().isEmpty ? 'Something went wrong' : message.trim();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg)),
  );
}

