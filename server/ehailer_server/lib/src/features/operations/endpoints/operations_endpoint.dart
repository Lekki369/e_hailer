import 'dart:convert';
import 'package:serverpod/serverpod.dart';
import '../../../core/domain/operation_failure.dart';
import '../../../generated/protocol.dart';
import '../domain/operations_service.dart';
import '../../payments/domain/payment_service.dart';

class OperationsEndpoint extends Endpoint {
  static late OperationsService service;
  static PaymentService? payments;
  @override
  bool get requireLogin => true;

  Future<CommandReply> execute(
    Session session,
    String command,
    String payload,
    String requestId,
  ) async {
    try {
      final identity = session.authenticated;
      if (identity == null) {
        return CommandReply(
          dataJson: '{}',
          errorCode: 'unauthenticated',
          errorMessage: 'Please sign in again.',
        );
      }
      final decoded = jsonDecode(payload);
      requireCondition(decoded is Map<String, dynamic>, 'Invalid request.');
      if (PaymentService.commands.contains(command) && payments == null) {
        throw const OperationFailure(
          'payment-unavailable',
          'Wallet funding is unavailable. Contact support if you already paid.',
        );
      }
      final result = PaymentService.commands.contains(command)
          ? await payments!.execute(
              command,
              identity.userIdentifier,
              decoded as Json,
              requestId,
            )
          : await service.execute(
              command,
              identity.userIdentifier,
              decoded as Json,
              requestId,
            );
      return CommandReply(dataJson: jsonEncode(result));
    } on OperationFailure catch (failure) {
      return CommandReply(
        dataJson: '{}',
        errorCode: failure.code,
        errorMessage: failure.message,
      );
    } on FormatException {
      return CommandReply(
        dataJson: '{}',
        errorCode: 'invalid-argument',
        errorMessage: 'Invalid request.',
      );
    } catch (_) {
      // Do not write payloads, tokens, PINs, banking details or raw SDK errors to logs.
      session.log('Operation failed.', level: LogLevel.error);
      return CommandReply(
        dataJson: '{}',
        errorCode: 'unavailable',
        errorMessage: 'We could not complete this action. Please retry.',
      );
    }
  }
}
