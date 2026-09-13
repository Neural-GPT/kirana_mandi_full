class CallLogModel {
  final String id;
  final String shopId;
  final String? callerLabel;
  final String calledAt; // ISO-8601

  CallLogModel({
    required this.id,
    required this.shopId,
    this.callerLabel,
    required this.calledAt,
  });

  DateTime get calledAtDateTime => DateTime.parse(calledAt);

  Map<String, Object?> toMap() => {
        'id': id,
        'shop_id': shopId,
        'caller_label': callerLabel,
        'called_at': calledAt,
      };

  factory CallLogModel.fromMap(Map<String, Object?> map) => CallLogModel(
        id: map['id'] as String,
        shopId: map['shop_id'] as String,
        callerLabel: map['caller_label'] as String?,
        calledAt: map['called_at'] as String,
      );
}
