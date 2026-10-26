import 'package:equatable/equatable.dart';

enum PackageCategory {
  document('Documents & Files'),
  parcel('Standard Box / Parcel'),
  food('Food & Groceries'),
  fragile('Fragile / Electronics'),
  heavy('Heavy Cargo / Furniture');

  final String label;
  const PackageCategory(this.label);

  static PackageCategory fromString(String? value) {
    return PackageCategory.values.firstWhere(
      (e) => e.name.toLowerCase() == (value ?? '').toLowerCase(),
      orElse: () => PackageCategory.parcel,
    );
  }
}

class ParcelDetails extends Equatable {
  final PackageCategory category;
  final double weightKg;
  final int quantity;
  final double? lengthCm;
  final double? widthCm;
  final double? heightCm;
  final String? description;
  final bool isFragile;

  const ParcelDetails({
    required this.category,
    required this.weightKg,
    this.quantity = 1,
    this.lengthCm,
    this.widthCm,
    this.heightCm,
    this.description,
    this.isFragile = false,
  });

  /// Volumetric weight calculation: (Length * Width * Height) / 5000 (from courierManagementSystem)
  double get volumetricWeightKg {
    if (lengthCm == null || widthCm == null || heightCm == null) {
      return 0.0;
    }
    return (lengthCm! * widthCm! * heightCm!) / 5000.0;
  }

  /// Billable weight is the max of physical weight vs volumetric weight
  double get billableWeightKg {
    final vol = volumetricWeightKg;
    return weightKg > vol ? weightKg : vol;
  }

  ParcelDetails copyWith({
    PackageCategory? category,
    double? weightKg,
    int? quantity,
    double? lengthCm,
    double? widthCm,
    double? heightCm,
    String? description,
    bool? isFragile,
  }) {
    return ParcelDetails(
      category: category ?? this.category,
      weightKg: weightKg ?? this.weightKg,
      quantity: quantity ?? this.quantity,
      lengthCm: lengthCm ?? this.lengthCm,
      widthCm: widthCm ?? this.widthCm,
      heightCm: heightCm ?? this.heightCm,
      description: description ?? this.description,
      isFragile: isFragile ?? this.isFragile,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'category': category.name,
      'weightKg': weightKg,
      'quantity': quantity,
      'lengthCm': lengthCm,
      'widthCm': widthCm,
      'heightCm': heightCm,
      'description': description,
      'isFragile': isFragile,
    };
  }

  factory ParcelDetails.fromMap(Map<String, dynamic> map) {
    return ParcelDetails(
      category: PackageCategory.fromString(map['category'] as String?),
      weightKg: (map['weightKg'] as num?)?.toDouble() ?? 0.0,
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      lengthCm: (map['lengthCm'] as num?)?.toDouble(),
      widthCm: (map['widthCm'] as num?)?.toDouble(),
      heightCm: (map['heightCm'] as num?)?.toDouble(),
      description: map['description'] as String?,
      isFragile: map['isFragile'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [
        category,
        weightKg,
        quantity,
        lengthCm,
        widthCm,
        heightCm,
        description,
        isFragile,
      ];
}
