import 'package:pokem_app/core/config/api_config.dart';

String? resolveProductImage(
  String value, {
  String baseUrl = ApiConfig.baseUrl,
}) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null || value.trim().isEmpty) return null;
  final resolved = Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}/')
      .resolveUri(uri);
  if (!['http', 'https'].contains(resolved.scheme) || resolved.host.isEmpty) {
    return null;
  }
  return resolved.toString();
}
