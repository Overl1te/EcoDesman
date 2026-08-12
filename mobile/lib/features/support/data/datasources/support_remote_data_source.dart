import "package:dio/dio.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../../core/network/api_client.dart";
import "../../domain/models/support_models.dart";

final supportRemoteDataSourceProvider = Provider<SupportRemoteDataSource>((
  ref,
) {
  return SupportRemoteDataSource(ref.watch(apiClientProvider));
});

class SupportRemoteDataSource {
  SupportRemoteDataSource(this._dio);

  final Dio _dio;

  Future<HelpCenterContent> fetchHelpCenterContent() async {
    final response = await _dio.get("/support/help-center");
    return HelpCenterContent.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<HelpDocument> fetchHelpDocument(String slug) async {
    final response = await _dio.get("/support/help-center/$slug");
    return HelpDocument.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<SupportKnowledgeResponse> fetchKnowledge() async {
    final response = await _dio.get("/support/knowledge");
    return SupportKnowledgeResponse.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<SupportBotReply> askBot(String query) async {
    final response = await _dio.post(
      "/support/bot/reply",
      data: {"query": query},
    );
    return SupportBotReply.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<List<SupportThreadSummary>> fetchThreads({
    bool teamView = false,
  }) async {
    final response = await _dio.get(
      teamView ? "/support/team/threads" : "/support/threads",
    );
    return (response.data as List<dynamic>? ?? const [])
        .map(
          (item) => SupportThreadSummary.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<SupportThreadDetail> fetchThread(int threadId) async {
    final response = await _dio.get("/support/threads/$threadId");
    return SupportThreadDetail.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<SupportThreadDetail> createThread({
    required String subject,
    required String body,
    required String category,
  }) async {
    final response = await _dio.post(
      "/support/threads",
      data: {"subject": subject, "body": body, "category": category},
    );
    return SupportThreadDetail.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<SupportMessage> sendMessage({
    required int threadId,
    required String body,
  }) async {
    final response = await _dio.post(
      "/support/threads/$threadId/messages",
      data: {"body": body},
    );
    return SupportMessage.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<SupportThreadDetail> updateThread({
    required int threadId,
    String? status,
    int? assignedToId,
  }) async {
    final response = await _dio.patch(
      "/support/team/threads/$threadId",
      data: {
        ...?status != null ? {"status": status} : null,
        ...?assignedToId != null ? {"assigned_to_id": assignedToId} : null,
      },
    );
    return SupportThreadDetail.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<List<SupportReport>> fetchTeamReports() async {
    final response = await _dio.get("/support/team/reports");
    return (response.data as List<dynamic>? ?? const [])
        .map(
          (item) =>
              SupportReport.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<SupportReport> updateReport({
    required int reportId,
    required String status,
    required String resolutionNote,
    required bool removeTarget,
  }) async {
    final response = await _dio.patch(
      "/support/team/reports/$reportId",
      data: {
        "status": status,
        "resolution_note": resolutionNote,
        "remove_target": removeTarget,
      },
    );
    return SupportReport.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<SupportReport> createPostReport({
    required int postId,
    required String reason,
    required String details,
  }) async {
    final response = await _dio.post(
      "/posts/$postId/report",
      data: {"reason": reason, "details": details},
    );
    return SupportReport.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<SupportReport> createCommentReport({
    required int postId,
    required int commentId,
    required String reason,
    required String details,
  }) async {
    final response = await _dio.post(
      "/posts/$postId/comments/$commentId/report",
      data: {"reason": reason, "details": details},
    );
    return SupportReport.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<SupportReport> createMapReviewReport({
    required int pointId,
    required int reviewId,
    required String reason,
    required String details,
  }) async {
    final response = await _dio.post(
      "/map/points/$pointId/reviews/$reviewId/report",
      data: {"reason": reason, "details": details},
    );
    return SupportReport.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<SupportReport> createUserMarkerReport({
    required int markerId,
    required String reason,
    required String details,
  }) async {
    final response = await _dio.post(
      "/map/user-markers/$markerId/report",
      data: {"reason": reason, "details": details},
    );
    return SupportReport.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<SupportReport> createUserMarkerCommentReport({
    required int markerId,
    required int commentId,
    required String reason,
    required String details,
  }) async {
    final response = await _dio.post(
      "/map/user-markers/$markerId/comments/$commentId/report",
      data: {"reason": reason, "details": details},
    );
    return SupportReport.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }
}
