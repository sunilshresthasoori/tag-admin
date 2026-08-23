class VehicleType {
  final int id;
  final String name;
  final bool isActive;

  VehicleType({
    required this.id,
    required this.name,
    required this.isActive,
  });

  static List<VehicleType> get staticTypes => [
    VehicleType(id: 1, name: 'Car', isActive: true),
    VehicleType(id: 2, name: 'Jeep', isActive: true),
    VehicleType(id: 3, name: 'Van', isActive: true),
    VehicleType(id: 4, name: 'Pick-up', isActive: true),
    VehicleType(id: 5, name: 'Microbus', isActive: true),
    VehicleType(id: 5, name: 'Bus', isActive: true),
  ];

  factory VehicleType.fromJson(Map<String, dynamic> json) {
    return VehicleType(
      id: int.parse(json['id'].toString()),
      name: json['name'] as String,
      isActive: json['isActive'].toString() == 'true',
    );
  }
}