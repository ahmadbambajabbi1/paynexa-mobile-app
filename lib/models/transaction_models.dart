import 'product_models.dart';

class PartyProfile {
  PartyProfile({required this.id, this.displayName, this.email, this.phone});

  final String id;
  final String? displayName;
  final String? email;
  final String? phone;

  factory PartyProfile.fromJson(Map<String, dynamic> j) => PartyProfile(
    id: j['id'] as String,
    displayName: j['displayName'] as String?,
    email: j['email'] as String?,
    phone: j['phone'] as String?,
  );
}

class TransactionParties {
  TransactionParties({
    this.buyer,
    this.seller,
    this.buyerLawyer,
    this.buyerAgent,
    this.sellerLawyer,
    this.sellerAgent,
  });

  final PartyProfile? buyer;
  final PartyProfile? seller;
  final PartyProfile? buyerLawyer;
  final PartyProfile? buyerAgent;
  final PartyProfile? sellerLawyer;
  final PartyProfile? sellerAgent;

  factory TransactionParties.fromJson(Map<String, dynamic> j) =>
      TransactionParties(
        buyer: j['buyer'] != null
            ? PartyProfile.fromJson(j['buyer'] as Map<String, dynamic>)
            : null,
        seller: j['seller'] != null
            ? PartyProfile.fromJson(j['seller'] as Map<String, dynamic>)
            : null,
        buyerLawyer: j['buyerLawyer'] != null
            ? PartyProfile.fromJson(j['buyerLawyer'] as Map<String, dynamic>)
            : null,
        buyerAgent: j['buyerAgent'] != null
            ? PartyProfile.fromJson(j['buyerAgent'] as Map<String, dynamic>)
            : null,
        sellerLawyer: j['sellerLawyer'] != null
            ? PartyProfile.fromJson(j['sellerLawyer'] as Map<String, dynamic>)
            : null,
        sellerAgent: j['sellerAgent'] != null
            ? PartyProfile.fromJson(j['sellerAgent'] as Map<String, dynamic>)
            : null,
      );
}

class TransactionListItem {
  TransactionListItem({
    required this.id,
    required this.workflow,
    this.shareToken,
    this.sharePath,
    required this.type,
    required this.productTitle,
    this.quantity,
    this.unitPrice,
    required this.amount,
    required this.buyerId,
    required this.sellerId,
    required this.status,
    required this.updatedAt,
  });

  final String id;
  final String workflow;
  final String? shareToken;
  final String? sharePath;
  final String type;
  final String productTitle;
  final int? quantity;
  final String? unitPrice;
  final String amount;
  final String buyerId;
  final String sellerId;
  final String status;
  final String updatedAt;

  factory TransactionListItem.fromJson(Map<String, dynamic> j) =>
      TransactionListItem(
        id: j['id'] as String,
        workflow: j['workflow'] as String? ?? 'ESCROW_TWO_PARTY',
        shareToken: j['shareToken'] as String?,
        sharePath: j['sharePath'] as String?,
        type: j['type'] as String,
        productTitle: j['productTitle'] as String? ?? '',
        quantity: (j['quantity'] as num?)?.toInt(),
        unitPrice: j['unitPrice'] as String?,
        amount: j['amount'] as String? ?? '0',
        buyerId: j['buyerId'] as String? ?? '',
        sellerId: j['sellerId'] as String,
        status: j['status'] as String,
        updatedAt: j['updatedAt'] as String,
      );
}

class TransactionListResponse {
  TransactionListResponse({required this.items});

  final List<TransactionListItem> items;

  factory TransactionListResponse.fromJson(Map<String, dynamic> j) {
    final raw = j['items'];
    final list = <TransactionListItem>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map<String, dynamic>) {
          list.add(TransactionListItem.fromJson(e));
        }
      }
    }
    return TransactionListResponse(items: list);
  }
}

class PublicTransactionAnalytics {
  PublicTransactionAnalytics({
    required this.totalViews,
    required this.uniqueViewers,
    required this.paidCount,
    required this.totalEarnings,
    required this.conversionRate,
    required this.viewedNotBought,
    required this.recentViewers,
  });

  final int totalViews;
  final int uniqueViewers;
  final int paidCount;
  final String totalEarnings;
  final String conversionRate;
  final int viewedNotBought;
  final List<PublicTransactionViewer> recentViewers;

  factory PublicTransactionAnalytics.fromJson(Map<String, dynamic> j) =>
      PublicTransactionAnalytics(
        totalViews: (j['totalViews'] as num?)?.toInt() ?? 0,
        uniqueViewers: (j['uniqueViewers'] as num?)?.toInt() ?? 0,
        paidCount: (j['paidCount'] as num?)?.toInt() ?? 0,
        totalEarnings: j['totalEarnings'] as String? ?? '0.00',
        conversionRate: j['conversionRate'] as String? ?? '0.0',
        viewedNotBought: (j['viewedNotBought'] as num?)?.toInt() ?? 0,
        recentViewers: (j['recentViewers'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(PublicTransactionViewer.fromJson)
            .toList(),
      );
}

class PublicTransactionViewer {
  PublicTransactionViewer({
    required this.label,
    required this.viewedAt,
    this.convertedAt,
  });

  final String label;
  final String viewedAt;
  final String? convertedAt;

  factory PublicTransactionViewer.fromJson(Map<String, dynamic> j) =>
      PublicTransactionViewer(
        label: j['label'] as String? ?? 'Visitor',
        viewedAt: j['viewedAt'] as String? ?? '',
        convertedAt: j['convertedAt'] as String?,
      );
}

class PublicTransactionSummary {
  PublicTransactionSummary({
    required this.id,
    required this.workflow,
    this.shareToken,
    required this.sharePath,
    required this.sellerId,
    this.buyerId,
    required this.seller,
    required this.item,
    this.itemDescription,
    required this.quantity,
    required this.unitPrice,
    required this.amount,
    required this.protectionFee,
    required this.totalBuyerPays,
    required this.deliveryNeeded,
    required this.status,
    this.sellerNote,
  });

  final String id;
  final String workflow;
  final String? shareToken;
  final String sharePath;
  final String sellerId;
  final String? buyerId;
  final String seller;
  final String item;
  final String? itemDescription;
  final int quantity;
  final String unitPrice;
  final String amount;
  final String protectionFee;
  final String totalBuyerPays;
  final bool deliveryNeeded;
  final String status;
  final String? sellerNote;

  factory PublicTransactionSummary.fromJson(Map<String, dynamic> j) =>
      PublicTransactionSummary(
        id: j['id'] as String,
        workflow: j['workflow'] as String? ?? 'PUBLIC_SHAREABLE',
        shareToken: j['shareToken'] as String?,
        sharePath: j['sharePath'] as String? ?? '',
        sellerId: j['sellerId'] as String,
        buyerId: j['buyerId'] as String?,
        seller: j['seller'] as String? ?? 'Seller',
        item: j['item'] as String? ?? '',
        itemDescription: j['itemDescription'] as String?,
        quantity: (j['quantity'] as num?)?.toInt() ?? 1,
        unitPrice: j['unitPrice'] as String? ?? '0.00',
        amount: j['amount'] as String? ?? '0.00',
        protectionFee: j['protectionFee'] as String? ?? '0.00',
        totalBuyerPays: j['totalBuyerPays'] as String? ?? '0.00',
        deliveryNeeded: j['deliveryNeeded'] as bool? ?? false,
        status: j['status'] as String? ?? '',
        sellerNote: j['sellerNote'] as String?,
      );

  bool get isFundedOrBeyond => {
    'FUNDED',
    'IN_PROGRESS',
    'INSPECTION',
    'COMPLETED',
    'CLOSED',
    'REFUNDED',
  }.contains(status.toUpperCase());
}

class PublicClaimResult {
  PublicClaimResult({
    required this.transactionId,
    required this.workflow,
    required this.buyerId,
    required this.status,
  });

  final String transactionId;
  final String workflow;
  final String buyerId;
  final String status;

  factory PublicClaimResult.fromJson(Map<String, dynamic> j) =>
      PublicClaimResult(
        transactionId: j['transactionId'] as String,
        workflow: j['workflow'] as String? ?? 'PUBLIC_SHAREABLE',
        buyerId: j['buyerId'] as String? ?? '',
        status: j['status'] as String? ?? '',
      );
}

class TransactionRoom {
  TransactionRoom({
    required this.transaction,
    required this.timeline,
    this.product,
    this.parties,
    this.publicAnalytics,
  });

  final TxEntity transaction;
  final List<TimelineEvent> timeline;
  final ProductRow? product;
  final TransactionParties? parties;
  final PublicTransactionAnalytics? publicAnalytics;

  factory TransactionRoom.fromJson(Map<String, dynamic> j) => TransactionRoom(
    transaction: TxEntity.fromJson(j['transaction'] as Map<String, dynamic>),
    timeline: (j['timeline'] as List<dynamic>? ?? [])
        .map((e) => TimelineEvent.fromJson(e as Map<String, dynamic>))
        .toList(),
    product: j['product'] != null
        ? ProductRow.fromJson(j['product'] as Map<String, dynamic>)
        : null,
    parties: j['parties'] != null
        ? TransactionParties.fromJson(j['parties'] as Map<String, dynamic>)
        : null,
    publicAnalytics: j['publicAnalytics'] != null
        ? PublicTransactionAnalytics.fromJson(
            j['publicAnalytics'] as Map<String, dynamic>,
          )
        : null,
  );
}

class TxEntity {
  TxEntity({
    required this.id,
    required this.workflow,
    this.shareToken,
    this.sharePath,
    required this.type,
    required this.productId,
    required this.productTitle,
    this.quantity,
    this.unitPrice,
    required this.amount,
    required this.fundedBy,
    required this.buyerId,
    required this.sellerId,
    required this.terms,
    required this.status,
    required this.acceptedPartyIds,
    this.buyerLawyerId,
    this.buyerLawyerInviteStatus = 'NONE',
    this.buyerAgentId,
    this.buyerAgentInviteStatus = 'NONE',
    this.sellerLawyerId,
    this.sellerLawyerInviteStatus = 'NONE',
    this.sellerAgentId,
    this.sellerAgentInviteStatus = 'NONE',
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String workflow;
  final String? shareToken;
  final String? sharePath;
  final String type;
  final String productId;
  final String productTitle;
  final int? quantity;
  final String? unitPrice;
  final String amount;
  final String fundedBy;
  final String buyerId;
  final String sellerId;
  final String terms;
  final String status;
  final List<String> acceptedPartyIds;
  final String? buyerLawyerId;
  final String buyerLawyerInviteStatus;
  final String? buyerAgentId;
  final String buyerAgentInviteStatus;
  final String? sellerLawyerId;
  final String sellerLawyerInviteStatus;
  final String? sellerAgentId;
  final String sellerAgentInviteStatus;
  final String createdAt;
  final String updatedAt;

  factory TxEntity.fromJson(Map<String, dynamic> j) => TxEntity(
    id: j['id'] as String,
    workflow: j['workflow'] as String? ?? 'ESCROW_TWO_PARTY',
    shareToken: j['shareToken'] as String?,
    sharePath: j['sharePath'] as String?,
    type: j['type'] as String,
    productId: j['productId'] as String? ?? '',
    productTitle: j['productTitle'] as String? ?? '',
    quantity: (j['quantity'] as num?)?.toInt(),
    unitPrice: j['unitPrice'] as String?,
    amount: j['amount'] as String? ?? '0',
    fundedBy: j['fundedBy'] as String? ?? '',
    buyerId: j['buyerId'] as String? ?? '',
    sellerId: j['sellerId'] as String,
    terms: j['terms'] as String? ?? '',
    status: j['status'] as String,
    acceptedPartyIds: (j['acceptedPartyIds'] as List<dynamic>? ?? [])
        .whereType<String>()
        .toList(),
    buyerLawyerId: j['buyerLawyerId'] as String?,
    buyerLawyerInviteStatus: j['buyerLawyerInviteStatus'] as String? ?? 'NONE',
    buyerAgentId: j['buyerAgentId'] as String?,
    buyerAgentInviteStatus: j['buyerAgentInviteStatus'] as String? ?? 'NONE',
    sellerLawyerId: j['sellerLawyerId'] as String?,
    sellerLawyerInviteStatus:
        j['sellerLawyerInviteStatus'] as String? ?? 'NONE',
    sellerAgentId: j['sellerAgentId'] as String?,
    sellerAgentInviteStatus: j['sellerAgentInviteStatus'] as String? ?? 'NONE',
    createdAt: j['createdAt'] as String,
    updatedAt: j['updatedAt'] as String,
  );
}

class ParticipantSearchResult {
  ParticipantSearchResult({
    required this.items,
    this.disabledReason,
    this.lawyerPricingEnabled,
    this.agentPricingEnabled,
  });

  final List<ProfessionalSearchItem> items;
  final String? disabledReason;
  final bool? lawyerPricingEnabled;
  final bool? agentPricingEnabled;

  factory ParticipantSearchResult.fromJson(Map<String, dynamic> j) {
    final raw = j['items'];
    final list = <ProfessionalSearchItem>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map<String, dynamic>) {
          list.add(ProfessionalSearchItem.fromJson(e));
        }
      }
    }
    final pp = j['productPricing'];
    bool? le;
    bool? ae;
    if (pp is Map<String, dynamic>) {
      le = pp['lawyerPricingEnabled'] as bool?;
      ae = pp['agentPricingEnabled'] as bool?;
    }
    return ParticipantSearchResult(
      items: list,
      disabledReason: j['disabledReason'] as String?,
      lawyerPricingEnabled: le,
      agentPricingEnabled: ae,
    );
  }
}

class ProfessionalSearchItem {
  ProfessionalSearchItem({
    required this.id,
    this.displayName,
    this.email,
    this.phone,
    this.invited = false,
    this.inviteStatus = 'NONE',
  });

  final String id;
  final String? displayName;
  final String? email;
  final String? phone;
  final bool invited;
  final String inviteStatus;

  factory ProfessionalSearchItem.fromJson(Map<String, dynamic> j) =>
      ProfessionalSearchItem(
        id: j['id'] as String,
        displayName: j['displayName'] as String?,
        email: j['email'] as String?,
        phone: j['phone'] as String?,
        invited: j['invited'] as bool? ?? false,
        inviteStatus: j['inviteStatus'] as String? ?? 'NONE',
      );
}

class TransactionNotificationItem {
  TransactionNotificationItem({
    required this.id,
    required this.transactionId,
    required this.message,
    required this.role,
    required this.status,
    required this.createdAt,
    required this.readAt,
  });

  final String id;
  final String transactionId;
  final String message;
  final String role;
  final String status;
  final String createdAt;
  final String? readAt;

  factory TransactionNotificationItem.fromJson(Map<String, dynamic> j) =>
      TransactionNotificationItem(
        id: j['id'] as String,
        transactionId: j['transactionId'] as String,
        message: j['message'] as String? ?? '',
        role: j['role'] as String? ?? '',
        status: j['status'] as String? ?? '',
        createdAt: j['createdAt'] as String? ?? '',
        readAt: j['readAt'] as String?,
      );
}

class TransactionNotificationResponse {
  TransactionNotificationResponse({required this.items});
  final List<TransactionNotificationItem> items;

  factory TransactionNotificationResponse.fromJson(Map<String, dynamic> j) =>
      TransactionNotificationResponse(
        items: (j['items'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(TransactionNotificationItem.fromJson)
            .toList(),
      );
}

class TimelineEvent {
  TimelineEvent({
    required this.at,
    required this.action,
    required this.actorId,
    required this.detail,
  });

  final String at;
  final String action;
  final String actorId;
  final String detail;

  factory TimelineEvent.fromJson(Map<String, dynamic> j) => TimelineEvent(
    at: j['at'] as String,
    action: j['action'] as String,
    actorId: j['actorId'] as String,
    detail: j['detail'] as String? ?? '',
  );
}
