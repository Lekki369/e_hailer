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

### Step 4: Register Route in `GoRouter` ([`lib/core/routing/app_router.dart`](file:///Users/olamilekanawomewe/Desktop/FLUTTER%20PROJECTS/e_hailer/lib/core/routing/app_router.dart))
Add a new `GoRoute` with path and builder:
```dart
GoRoute(
  path: '/wallet',
  name: 'wallet',
  builder: (context, state) => const WalletScreen(),
),
```

---

## 3. Generating Architecture Diagrams with Archify

The project includes an integrated local installation of **Archify** under `.agents/skills/archify/`.

To re-render or update the interactive architecture diagram at any time:
```bash
node .agents/skills/archify/bin/archify.mjs render architecture docs/architecture.json docs/architecture.html
```
Open `docs/architecture.html` in any browser to inspect the interactive nodes, component connections, search, and dark/light modes.
