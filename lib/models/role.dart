class Role {
  final String id;
  final String name;

  const Role({required this.id, required this.name});

  @override
  String toString() {
    return "Rule: $name|$id";
  }
}
