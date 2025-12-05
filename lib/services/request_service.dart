import '../config/api_config.dart';
import '../models/request_model.dart';
import 'api_service.dart';

class RequestService {
  final ApiService _apiService = ApiService();

  Future<RequestPayload> getRequests() async {
    try {
      final response = await _apiService.get(ApiConfig.requests);
      if (response.statusCode == 200) {
        return RequestPayload.fromJson(response.data['data']);
      }
      throw Exception('Gagal memuat data request');
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createRequest({
    required String type,
    required String reason,
    required String startDate,
    required String endDate,
  }) async {
    try {
      final response = await _apiService.post(
        ApiConfig.requests,
        data: {
          'type': type,
          'reason': reason,
          'startDate': startDate,
          'endDate': endDate,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'data': response.data['data'],
          'message': response.data['message'] ?? 'Request berhasil dikirim',
        };
      } else {
        throw Exception(response.data['message'] ?? 'Gagal mengirim request');
      }
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }
}

