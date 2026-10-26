# Developer Guide & Template Reference

This guide explains how to use **e-Hailer** as a reference boilerplate or starter template for future Flutter & Firebase applications.

---

## 1. Quick Start & Prerequisites

### Prerequisites
- **Flutter SDK**: `^3.47` (Dart `^3.13`)
- **Node.js**: `>=18` (optional, for Archify diagram rendering)

### Clone & Bootstrap
```bash
# 1. Clone repository
git clone <your-repo-url> my_new_app
cd my_new_app

# 2. Install dependencies
flutter pub get

# 3. Configure Firebase
flutterfire configure

# 4. Verify static analysis
flutter analyze
```

---

## 2. Recipe: Adding a New Feature (DDD Pattern)

To add a new feature (e.g., `features/wallet/` or `features/notifications/`), follow the three-tier DDD convention:

### Step 1: Create Domain Entity ([`domain/entities/`](file:///Users/olamilekanawomewe/Desktop/FLUTTER%20PROJECTS/e_hailer/lib/features/))
Create a pure Dart class extending `Equatable`:
```dart
import 'package:equatable/equatable.dart';

class WalletTransaction extends Equatable {
  final String id;
  final double amount;
  final DateTime createdAt;

  const WalletTransaction({
    required this.id,
    required this.amount,
    required this.createdAt,
  });

  WalletTransaction copyWith({String? id, double? amount, DateTime? createdAt}) {
    return WalletTransaction(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'amount': amount,
    'createdAt': createdAt.toIso8601String(),
  };

  factory WalletTransaction.fromMap(Map<String, dynamic> map, [String? docId]) {
    return WalletTransaction(
      id: docId ?? map['id'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [id, amount, createdAt];
}
```

### Step 2: Implement Infrastructure Remote Service ([`infrastructure/`](file:///Users/olamilekanawomewe/Desktop/FLUTTER%20PROJECTS/e_hailer/lib/features/))
Use `fpdart`'s `Either<AppFailure, T>` for return types:
```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/domain/failures/app_failure.dart';
import '../../../../core/presentation/utils/fp_framework.dart';

class WalletRemoteService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Either<AppFailure, Unit>> topUpWallet(String userId, double amount) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'walletBalance': FieldValue.increment(amount),
      });
      return right(unit);
    } catch (e) {
      return left(ServerFailure(message: 'Top-up failed: $e'));
    }
  }
}
```

### Step 3: Define Riverpod Providers ([`presentation/providers/`](file:///Users/olamilekanawomewe/Desktop/FLUTTER%20PROJECTS/e_hailer/lib/features/))
Expose pure Riverpod providers without code generation:
```dart
import 'package:hooks_riverpod/hooks_riverpod.dart';

final walletRemoteServiceProvider = Provider<WalletRemoteService>((ref) {
  return WalletRemoteService();
});

final walletBalanceStreamProvider = StreamProvider.family<double, String>((ref, userId) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .snapshots()
      .map((doc) => (doc.data()?['walletBalance'] as num?)?.toDouble() ?? 0.0);
});
```

### Step 4: Define Feature Route & Screen GoRoute (`presentation/routes/`)
1. Create `lib/features/<feature>/presentation/routes/<feature>_routes.dart`:
```dart
abstract class WalletScreenRoute {
  static const String path = '/wallet';
  static const String name = 'wallet';

  static GoRoute get route => GoRoute(
        path: path,
        name: name,
        builder: (context, state) => const WalletScreen(),
      );
}

abstract class WalletRoutes {
  static const String walletPath = WalletScreenRoute.path;
  static const String walletName = WalletScreenRoute.name;
  static GoRoute get walletRoute => WalletScreenRoute.route;
  static List<GoRoute> get routes => [WalletScreenRoute.route];
}
```
2. Export in [`lib/core/routing/app_routes.dart`](file:///Users/olamilekanawomewe/Desktop/FLUTTER%20PROJECTS/e_hailer/lib/core/routing/app_routes.dart) and register `...WalletRoutes.routes` in [`lib/core/routing/app_router.dart`](file:///Users/olamilekanawomewe/Desktop/FLUTTER%20PROJECTS/e_hailer/lib/core/routing/app_router.dart).
3. Navigate type-safely in the presentation layer:
```dart
context.push(WalletScreenRoute.path);
```

### Step 5: Register Asset Paths in `AppAssets`
If the feature introduces new graphics, icons, or vehicle assets, register them in [`lib/core/presentation/styles/app_assets.dart`](file:///Users/olamilekanawomewe/Desktop/FLUTTER%20PROJECTS/e_hailer/lib/core/presentation/styles/app_assets.dart):
```dart
abstract class WalletAssets {
  static const String cardChip = 'assets/icons/card_chip.svg';
  static const String topUpSuccess = 'assets/images/top_up_success.png';
}
```

---

## 3. Generating Architecture Diagrams with Archify

The project includes an integrated local installation of **Archify** under `.agents/skills/archify/`.

To re-render or update the interactive architecture diagram at any time:
```bash
node .agents/skills/archify/bin/archify.mjs render architecture docs/architecture.json docs/architecture.html
```
Open `docs/architecture.html` in any browser to inspect the interactive nodes, component connections, search, and dark/light modes.

---

## 4. Running Unit & Domain Tests

The application features a zero-codegen unit test suite validating pricing formulas, IATA dimensional metrics, value objects, and serialization:

```bash
# Run all unit tests
flutter test

# Run a specific test suite
flutter test test/features/delivery/domain/pricing_calculator_test.dart
```

### Key Test Coverage
- **`PricingCalculator`**: Base vehicle multiplier rates ($1.0\times$ to $3.5\times$), distance fare calculation ($₦120$/km), volumetric & physical surcharge thresholds ($₦80$/kg over 2.0kg), fragile handling fee ($₦300$), 80/20 driver/platform commission splits, and nearest-10 fare rounding.
- **`ParcelDetails`**: IATA formula $\frac{L \times W \times H}{5000}$, billable weight selection ($\max(\text{Physical}, \text{Volumetric})$), category fallbacks, and serialization.
- **`PricingDetails`**: Payment method mapping, copyWith immutability, and full map serialization.
- **`DeliveryOrder` & `LocationPoint`**: Lifecycle statuses (`isOngoing`, `isCompleted`, `isCancelled`), driver GPS assignment, cancellation audit logging, and handover verification OTP.
- **`UserEntity` & `AppFailure`**: Multi-role support, fleet vehicle attributes, and sealed failure hierarchy.
