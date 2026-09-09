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
  });
  final String id, name, requiredQty;
  final KrogerProduct? product;
  final int quantity;
  final bool quantityEdited, approved, excluded, sourceExcluded, manual;
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
  List<KrogerLine> get included => lines.where((l) => !l.excluded).toList();
  bool get ready =>
      !exported &&
      store != null &&
      included.isNotEmpty &&
      included.every(
        (l) =>
            l.approved &&
            l.product?.available == true &&
            l.quantity >= 1 &&
            l.quantity <= 99,
      );
  double get estimate =>
      included.fold(0, (sum, l) => sum + (l.product?.price ?? 0) * l.quantity);
  int get unknownPrices =>
      included.where((l) => l.product?.price == null).length;
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

class KrogerException implements Exception {
  const KrogerException(this.code);
  final String code;
  @override
  String toString() => code;
}
