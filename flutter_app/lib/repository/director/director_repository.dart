import 'package:pokem_app/model/director/director_dashboard.dart';
import 'package:pokem_app/service/director/director_api_service.dart';

class DirectorRepository {
  const DirectorRepository(this._api);
  final DirectorApiService _api;
  Future<DirectorDashboard> load(String token) async =>
      DirectorDashboard.fromJson(await _api.dashboard(token));
  Future<void> reviewProposal(String token, String number, String status) =>
      _api.reviewProposal(token, number, status);
}
