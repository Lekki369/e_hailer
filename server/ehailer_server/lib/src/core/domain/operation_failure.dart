import 'package:equatable/equatable.dart';

class OperationFailure extends Equatable implements Exception {
  final String code;
  final String message;
  const OperationFailure(this.code, this.message);
  @override
  List<Object?> get props => [code, message];
  @override
  String toString() => 'OperationFailure($code)';
}

void requireCondition(
  bool condition,
  String message, [
  String code = 'invalid-argument',
]) {
  if (!condition) throw OperationFailure(code, message);
}

String identifier(dynamic value) {
  requireCondition(
    value is String && RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(value),
    'Invalid record identifier.',
  );
  return value as String;
}

String requiredText(dynamic value, String label, [int max = 300]) {
  requireCondition(
    value is String && value.trim().isNotEmpty && value.trim().length <= max,
    '$label is required (maximum $max characters).',
  );
  return (value as String).trim();
}

double finiteNumber(dynamic value, double min, double max, String label) {
  requireCondition(
    value is num && value.isFinite && value >= min && value <= max,
    'Invalid $label.',
  );
  return (value as num).toDouble();
}

int minorUnits(dynamic value, {bool allowNegative = false}) {
  final amount = finiteNumber(
    value,
    allowNegative ? -1000000000 : 0,
    1000000000,
    'amount',
  );
  final minor = (amount * 100).round();
  requireCondition(
    (amount * 100 - minor).abs() < 0.00001,
    'Amounts must have at most two decimal places.',
  );
  return minor;
}

typedef Json = Map<String, dynamic>;

Json existing(Json? value) {
  if (value == null) {
    throw const OperationFailure(
      'not-found',
      'The requested record was not found.',
    );
  }
  return value;
}
