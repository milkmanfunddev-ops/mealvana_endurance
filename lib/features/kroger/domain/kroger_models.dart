import 'package:uuid/uuid.dart';

class KrogerProduct {
  const KrogerProduct({
    required this.upc,
    required this.name,
    this.brand = '',
    this.size = '',
    this.price,
    this.available = false,
    this.image,
  });
  final String upc, name, brand, size;
  final double? price;
  final bool available;
  final String? image;
  factory KrogerProduct.fromJson(Map<String, dynamic> j) => KrogerProduct(
    upc: j['upc'] as String,
    name: j['name'] as String,
    brand: j['brand'] as String? ?? '',
    size: j['size'] as String? ?? '',
    price: (j['price'] as num?)?.toDouble(),
    available: j['available'] == true,
    image: j['image'] as String?,
  );
  Map<String, dynamic> toJson() => {
    'upc': upc,
    'name': name,
    'brand': brand,
    'size': size,
    'price': price,
    'available': available,
    'image': image,
  };
}

class KrogerStore {
  const KrogerStore({
    required this.id,
    required this.name,
    required this.address,
  });
  final String id, name, address;
  factory KrogerStore.fromJson(Map<String, dynamic> j) => KrogerStore(
    id: j['id'] as String,
    name: j['name'] as String,
    address: j['address'] as String? ?? '',
  );
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'address': address};
}

/// Retailer overlay: source quantities are preserved even when the shopper changes packages.
class KrogerLine {
  const KrogerLine({
    required this.id,
    required this.name,
    required this.requiredQty,
    this.product,
    this.quantity = 1,
    this.quantityEdited = false,
    this.approved = false,
    this.excluded = false,
    this.sourceExcluded = false,
    this.manual = false,
    this.noMatch = false,
  });
  final String id, name, requiredQty;
  final KrogerProduct? product;
  final int quantity;
  final bool quantityEdited, approved, excluded, sourceExcluded, manual;

  /// Kroger answered a search for this line, at this Location, with nothing
  /// it could use. False until one has: a line with no product is not a line
  /// Kroger has no match for until Kroger has been asked. Drafts stored
  /// before this was recorded read false, so they need no migration.
  final bool noMatch;
  static String sourceId(String planId, String name) =>
      const Uuid().v5(planId, name.trim().toLowerCase());
  factory KrogerLine.fromJson(Map<String, dynamic> j) => KrogerLine(
    id: j['id'] as String,
    name: j['name'] as String,
    requiredQty: j['requiredQty'] as String? ?? '',
    product: j['product'] is Map
        ? KrogerProduct.fromJson(Map<String, dynamic>.from(j['product'] as Map))
        : null,
    quantity: (j['quantity'] as num?)?.toInt() ?? 1,
    quantityEdited: j['quantityEdited'] == true,
    approved: j['approved'] == true,
    excluded: j['excluded'] == true,
    sourceExcluded: j['sourceExcluded'] == true,
    manual: j['manual'] == true,
    noMatch: j['noMatch'] == true,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'requiredQty': requiredQty,
    'product': product?.toJson(),
    'quantity': quantity,
    'quantityEdited': quantityEdited,
    'approved': approved,
    'excluded': excluded,
    'sourceExcluded': sourceExcluded,
    'manual': manual,
    'noMatch': noMatch,
  };
  KrogerLine copyWith({
    String? requiredQty,
    KrogerProduct? product,
    int? quantity,
    bool? quantityEdited,
    bool? approved,
    bool? excluded,
    bool? sourceExcluded,
    bool clearProduct = false,
    bool? noMatch,
  }) => KrogerLine(
    id: id,
    name: name,
    requiredQty: requiredQty ?? this.requiredQty,
    product: clearProduct ? null : product ?? this.product,
    quantity: quantity ?? this.quantity,
    quantityEdited: quantityEdited ?? this.quantityEdited,
    approved: approved ?? this.approved,
    excluded: excluded ?? this.excluded,
    sourceExcluded: sourceExcluded ?? this.sourceExcluded,
    manual: manual,
    // The answer belongs to the product it left the line without, so a new
    // product, or none, takes it with it unless the caller says otherwise.
    noMatch:
        noMatch ?? (product != null || clearProduct ? false : this.noMatch),
  );
}

class KrogerDraft {
  /// Delivery is the shopper's intent and the Location follows from it. A
  /// delivery-only market has no curbside catalog, so a pickup default makes
  /// every search there return nothing.
  static const String defaultModality = 'DELIVERY';
  const KrogerDraft({
    required this.planId,
    this.store,
    this.modality = defaultModality,
    this.environment = 'certification',
    this.lines = const [],
    this.revision = 0,
    this.dirty = false,
    this.receiptStatus,
  });
  final String planId, modality, environment;
  final KrogerStore? store;
  final List<KrogerLine> lines;
  final int revision;
  final bool dirty;

  /// A receipt is historical: it never claims to reflect Kroger's current cart.
  final String? receiptStatus;
  bool get exported => receiptStatus != null;

  /// A send Kroger acknowledged. `sending` may still be in flight and after
  /// `unknown` nothing here knows what reached the cart, so only this one can
  /// be described to a shopper deciding whether to send it all again.
  bool get sent => receiptStatus == 'sent';
  List<KrogerLine> get included => lines.where((l) => !l.excluded).toList();

  /// The four parts of the review, which every line belongs to exactly one
  /// of. What matched is what Kroger will be sent; what Kroger had nothing
  /// for is the shopper's own to add on Kroger's site, and is listed rather
  /// than sent; what has not been searched for yet is waiting on a matching
  /// run and says nothing about Kroger; what is skipped is out of the order
  /// but not off the screen.
  List<KrogerLine> get matched =>
      included.where((l) => l.product != null).toList();
  List<KrogerLine> get unmatched =>
      included.where((l) => l.product == null && l.noMatch).toList();
  List<KrogerLine> get unsearched =>
      included.where((l) => l.product == null && !l.noMatch).toList();
  List<KrogerLine> get skipped => lines.where((l) => l.excluded).toList();

  /// Whether what the shopper has approved is fit to send.
  ///
  /// An unmatched line does not hold the order back. A delivery catalogue
  /// will not cover a whole week's shopping, and refusing to send anything
  /// until it does would make the feature inert in the market it is for.
  bool get reviewed =>
      store != null &&
      matched.isNotEmpty &&
      matched.every(
        (l) =>
            l.approved &&
            l.product?.available == true &&
            l.quantity >= 1 &&
            l.quantity <= 99,
      );

  /// Whether it can be sent, which a draft that has been is not.
  bool get ready => reviewed && !exported;

  /// Whether it can be sent a second time — something the shopper asks for
  /// outright, having been told what that does to a cart nothing can take
  /// items out of. Only over a send Kroger acknowledged: what a `sending` or
  /// `unknown` receipt would be adding to cannot be described to them.
  bool get resendable => reviewed && sent;
  Map<String, dynamic> toJson() => {
    'planId': planId,
    'store': store?.toJson(),
    'modality': modality,
    'environment': environment,
    'lines': lines.map((l) => l.toJson()).toList(),
    'revision': revision,
    'dirty': dirty,
    'receiptStatus': receiptStatus,
  };
  factory KrogerDraft.fromJson(Map<String, dynamic> j) => KrogerDraft(
    planId: j['planId'] as String,
    store: j['store'] is Map
        ? KrogerStore.fromJson(Map<String, dynamic>.from(j['store'] as Map))
        : null,
    modality: j['modality'] as String? ?? defaultModality,
    environment: j['environment'] as String? ?? 'certification',
    lines: [
      for (final l in j['lines'] as List? ?? [])
        KrogerLine.fromJson(Map<String, dynamic>.from(l as Map)),
    ],
    revision: (j['revision'] as num?)?.toInt() ?? 0,
    dirty: j['dirty'] == true,
    receiptStatus: j['receiptStatus'] as String?,
  );
  KrogerDraft copyWith({
    KrogerStore? store,
    String? modality,
    String? environment,
    bool clearStore = false,
    List<KrogerLine>? lines,
    int? revision,
    bool? dirty,
    String? receiptStatus,
    bool clearReceipt = false,
  }) => KrogerDraft(
    planId: planId,
    store: clearStore ? null : store ?? this.store,
    modality: modality ?? this.modality,
    environment: environment ?? this.environment,
    lines: lines ?? this.lines,
    revision: revision ?? this.revision,
    dirty: dirty ?? this.dirty,
    receiptStatus: clearReceipt ? null : receiptStatus ?? this.receiptStatus,
  );
}

/// The delivery area a string names, or null when it names none.
///
/// One rule, because both callers arrive with something looser than Kroger's
/// Locations filter accepts: the device's reverse lookup can return ZIP+4,
/// and the shopper types whatever they like.
String? krogerArea(String? raw) =>
    RegExp(r'^(\d{5})(?:-?\d{4})?$').firstMatch(raw?.trim() ?? '')?.group(1);

class KrogerException implements Exception {
  const KrogerException(this.code);
  final String code;
  @override
  String toString() => code;
}
