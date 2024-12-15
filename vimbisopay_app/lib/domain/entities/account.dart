import 'package:vimbisopay_app/domain/entities/base_entity.dart';

class Account extends Entity {
  final String handle;
  final String name;
  final String defaultDenom;
  final Map<String, double> balances;

  const Account({
    required String id,
    required this.handle,
    required this.name,
    required this.defaultDenom,
    required this.balances,
  }) : super(id);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Account &&
        other.id == id &&
        other.handle == handle &&
        other.name == name &&
        other.defaultDenom == defaultDenom;
  }

  @override
  int get hashCode => Object.hash(id, handle, name, defaultDenom);
}
