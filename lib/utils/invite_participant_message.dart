/// Matches server-side `defaultParticipantInviteMessage` in transaction-service.
String buildParticipantInviteMessageTemplate({
  required String inviterLabel,
  required String partySide,
  required String role,
  required String productTitle,
  required String amount,
  required String transactionId,
}) {
  final roleWord = role == 'LAWYER' ? 'lawyer' : 'agent';
  final shortId = transactionId.length >= 8 ? transactionId.substring(0, 8) : transactionId;
  return [
    'Hello,',
    '',
    '$inviterLabel ($partySide) would like to invite you to act as the $roleWord for their side of an escrow transaction on PayNexa.',
    '',
    'Product: $productTitle',
    'Amount: $amount',
    'Transaction: #$shortId…',
    '',
    'I would like to invite you to this transaction for you to be my $roleWord (I am the $partySide in this deal).',
    '',
    'Regards,',
    inviterLabel,
  ].join('\n');
}
