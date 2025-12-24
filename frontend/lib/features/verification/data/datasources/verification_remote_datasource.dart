import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../../core/constants/api_config.dart';
import '../models/verification_response_model.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});
}

class VerificationRemoteDataSource {
  final http.Client _client;

  VerificationRemoteDataSource({http.Client? client})
      : _client = client ?? http.Client();

  Future<VerificationResponseModel> uploadAndPredict({
    required Uint8List? bytes,
    required File? file,
  }) async {
    if (bytes == null && file == null) {
      throw ApiException('Please select an image first');
    }

    final uri = ApiConfig.predictUri();
    final request = http.MultipartRequest('POST', uri);

    if (kIsWeb && bytes != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: 'image.jpg',
      ));
    } else if (file != null) {
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        file.path,
      ));
    }

    final streamedResponse = await _client.send(request).timeout(
      ApiConfig.requestTimeout,
      onTimeout: () {
        throw ApiException('Request timeout: API took too long to respond',
            statusCode: 408);
      },
    );

    final response = await http.Response.fromStream(streamedResponse).timeout(
      ApiConfig.responseTimeout,
      onTimeout: () {
        throw ApiException('Response timeout: Failed to read API response',
            statusCode: 408);
      },
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body.containsKey('error')) {
        throw ApiException(
          'API Error: ${body['error']}',
          statusCode: (body['error_code'] as int?),
        );
      }
      return VerificationResponseModel.fromJson(body);
    }

    if (response.statusCode == 413) {
      throw ApiException(
        'Error (${response.statusCode}): File too large. Please select a smaller image (max 10MB).',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode == 503) {
      throw ApiException(
        'Error (${response.statusCode}): Model not loaded. Please restart the API server and ensure the model file is available.',
        statusCode: response.statusCode,
      );
    }

    try {
      final errorBody = jsonDecode(response.body) as Map<String, dynamic>;
      final detail = (errorBody['detail'] ?? 'Unknown error').toString();
      throw ApiException('Error (${response.statusCode}): $detail',
          statusCode: response.statusCode);
    } catch (_) {
      throw ApiException(
        'Error (${response.statusCode}): Server returned an error',
        statusCode: response.statusCode,
      );
    }
  }
}
