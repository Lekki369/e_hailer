import 'package:serverpod/serverpod.dart';

/// Process liveness only; does not claim Firebase or Paystack availability.
class HealthRoute extends Route {
  HealthRoute() : super(methods: {Method.get});

  @override
  Future<Result> handleCall(Session session, Request request) async =>
      Response.ok();
}
