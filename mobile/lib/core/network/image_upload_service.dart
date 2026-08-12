import "package:dio/dio.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "api_client.dart";

final imageUploadServiceProvider = Provider<ImageUploadService>((ref) {
  return ImageUploadService(ref.watch(apiClientProvider));
});

class UploadedMedia {
  const UploadedMedia({required this.url, required this.mediaType});

  final String url;
  final String mediaType;
}

class ImageUploadService {
  ImageUploadService(this._dio);

  final Dio _dio;

  Future<String> uploadImage(String filePath, {String? fileName}) async {
    final resolvedFileName =
        fileName ?? filePath.split(RegExp(r"[\\\\/]")).last;
    final formData = FormData.fromMap({
      "file": await MultipartFile.fromFile(
        filePath,
        filename: resolvedFileName,
      ),
    });

    final response = await _dio.post(
      "/uploads/images",
      data: formData,
      options: Options(contentType: "multipart/form-data"),
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    return data["url"] as String;
  }

  Future<UploadedMedia> uploadMedia(String filePath) async {
    final fileName = filePath.split(RegExp(r"[\\\\/]")).last;
    final formData = FormData.fromMap({
      "file": await MultipartFile.fromFile(filePath, filename: fileName),
    });

    final response = await _dio.post(
      "/uploads/media",
      data: formData,
      options: Options(contentType: "multipart/form-data"),
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    return UploadedMedia(
      url: data["url"] as String,
      mediaType: data["media_type"] as String? ?? "image",
    );
  }
}
