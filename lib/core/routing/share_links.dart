import 'app_routes.dart';

abstract final class ShareLinks {
  static const publicBaseUrl = String.fromEnvironment('E_HAILER_PUBLIC_URL');
  static String? tracking(String code, {String baseUrl = publicBaseUrl}) {
    final base = Uri.tryParse(baseUrl);
    if (base == null ||
        base.scheme != 'https' ||
        base.host.isEmpty ||
        base.userInfo.isNotEmpty) {
      return null;
    }
    return base.resolve(AppRoutes.publicTracking(code)).toString();
  }
}
