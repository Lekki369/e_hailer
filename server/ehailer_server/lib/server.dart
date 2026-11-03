import 'dart:io';
import 'package:firebase_admin_sdk/firebase_admin_sdk.dart';
import 'package:http/http.dart' as http;
import 'src/core/infrastructure/firestore_command_store.dart';
import 'src/core/domain/command_rate_limiter.dart';
import 'src/core/infrastructure/health_route.dart';
import 'src/core/infrastructure/runtime_environment.dart';
import 'src/features/payments/domain/payment_service.dart';
import 'src/features/payments/infrastructure/paystack_gateway.dart';
import 'src/features/payments/endpoints/paystack_webhook_route.dart';
import 'src/features/map/infrastructure/osrm_route_service.dart';
import 'src/features/operations/domain/operations_service.dart';
import 'src/features/operations/endpoints/operations_endpoint.dart';
import 'src/generated/serverpod.dart';

Future<void> run(List<String> args) async {
  final env = Platform.environment;
  validateRuntimeEnvironment(env);
  final project = env['FIREBASE_PROJECT_ID']!;
  final admin = FirebaseApp.initializeApp(
    options: AppOptions(projectId: project),
  );
  final routeClient = http.Client();
  final routeService = OsrmRouteService(
    client: routeClient,
    baseUrl: env['OSRM_BASE_URL'] ?? 'https://router.project-osrm.org',
  );
  final store = FirestoreCommandStore(admin.firestore());
  OperationsEndpoint.rateLimiter = CommandRateLimiter(store);
  OperationsEndpoint.service = OperationsService(
    store: store,
    routeLookup: routeService.lookup,
  );
  final auth = admin.auth();
  final secret = env['PAYSTACK_SECRET_KEY'];
  final gateway = secret == null || secret.isEmpty
      ? null
      : PaystackGateway(
          client: routeClient,
          secret: secret,
          mode: env['PAYSTACK_MODE'] ?? 'test',
          baseUrl: env['PAYSTACK_BASE_URL'] == null
              ? null
              : Uri.parse(env['PAYSTACK_BASE_URL']!),
          callbackUrl: env['PAYSTACK_CALLBACK_URL'],
        );
  final payments = gateway == null
      ? null
      : PaymentService(store: store, gateway: gateway);
  OperationsEndpoint.payments = payments;
  final pod = Serverpod(
    args,
    authenticationHandler: (session, token) async {
      try {
        final decoded = await auth.verifyIdToken(token, checkRevoked: true);
        return AuthenticationInfo(decoded.uid, {}, authId: decoded.uid);
      } catch (_) {
        return null;
      }
    },
  );
  pod.webServer.addRoute(HealthRoute(), '/healthz');
  if (payments != null && gateway != null) {
    pod.webServer.addRoute(
      PaystackWebhookRoute(payments, gateway),
      '/payments/paystack/webhook',
    );
  }
  await pod.start();
}
