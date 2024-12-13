// Base class for all domain entities
abstract class Entity {
  final String id;
  
  const Entity(this.id);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Entity && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// Marker interface for value objects
abstract class ValueObject {
  const ValueObject();
  
  bool isValid();
}
