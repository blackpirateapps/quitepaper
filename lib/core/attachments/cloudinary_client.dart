import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'attachment_models.dart';

/// Thrown when direct Cloudinary upload or download operations fail.
class CloudinaryException implements Exception {
  const CloudinaryException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => 'CloudinaryException($statusCode): $message';
}

/// Abstract contract for direct client-to-Cloudinary data plane operations.
abstract class CloudinaryClient {
  /// Uploads encrypted bytes directly to Cloudinary using backend-issued signed authorization.
  Future<CloudinaryUploadResult> uploadEncryptedBytes({
    required Uint8List encryptedBytes,
    required CloudinaryUploadAuth auth,
  });

  /// Downloads encrypted ciphertext bytes directly from Cloudinary.
  Future<Uint8List> downloadEncryptedBytes({
    required String cloudUrl,
  });
}

/// Production implementation of direct Cloudinary client.
class DefaultCloudinaryClient implements CloudinaryClient {
  DefaultCloudinaryClient({
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  @override
  Future<CloudinaryUploadResult> uploadEncryptedBytes({
    required Uint8List encryptedBytes,
    required CloudinaryUploadAuth auth,
  }) async {
    final uri = Uri.parse(auth.uploadUrl);
    final request = http.MultipartRequest('POST', uri);

    // Required Cloudinary signed upload parameters
    request.fields['api_key'] = auth.apiKey;
    request.fields['timestamp'] = auth.timestamp.toString();
    request.fields['signature'] = auth.signature;
    request.fields['public_id'] = auth.publicId;

    if (auth.folder != null && auth.folder!.isNotEmpty) {
      request.fields['folder'] = auth.folder!;
    }

    // Attach binary encrypted payload as raw file part (avoiding restricted extensions like .bin)
    final multipartFile = http.MultipartFile.fromBytes(
      'file',
      encryptedBytes,
      filename: auth.publicId,
    );
    request.files.add(multipartFile);

    final streamedResponse = await _httpClient.send(request);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final jsonMap = jsonDecode(response.body) as Map<String, dynamic>;
      return CloudinaryUploadResult.fromJson(jsonMap);
    } else {
      String errorMessage = 'Upload failed with HTTP ${response.statusCode}';
      try {
        final errJson = jsonDecode(response.body);
        if (errJson is Map && errJson['error'] is Map) {
          errorMessage = errJson['error']['message']?.toString() ?? errorMessage;
        }
      } catch (_) {}
      throw CloudinaryException(errorMessage, statusCode: response.statusCode);
    }
  }

  @override
  Future<Uint8List> downloadEncryptedBytes({
    required String cloudUrl,
  }) async {
    final uri = Uri.parse(cloudUrl);
    final response = await _httpClient.get(uri);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    } else {
      throw CloudinaryException(
        'Failed to download attachment from Cloudinary: HTTP ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }
  }
}
