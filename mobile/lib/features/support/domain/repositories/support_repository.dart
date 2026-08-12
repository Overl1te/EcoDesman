import "../models/support_models.dart";

abstract class SupportRepository {
  Future<HelpCenterContent> fetchHelpCenterContent();

  Future<HelpDocument> fetchHelpDocument(String slug);

  Future<SupportKnowledgeResponse> fetchKnowledge();

  Future<SupportBotReply> askBot(String query);

  Future<List<SupportThreadSummary>> fetchThreads({bool teamView = false});

  Future<SupportThreadDetail> fetchThread(int threadId);

  Future<SupportThreadDetail> createThread({
    required String subject,
    required String body,
    required String category,
  });

  Future<SupportMessage> sendMessage({
    required int threadId,
    required String body,
  });

  Future<SupportThreadDetail> updateThread({
    required int threadId,
    String? status,
    int? assignedToId,
  });

  Future<List<SupportReport>> fetchTeamReports();

  Future<SupportReport> updateReport({
    required int reportId,
    required String status,
    required String resolutionNote,
    required bool removeTarget,
  });

  Future<SupportReport> createPostReport({
    required int postId,
    required String reason,
    required String details,
  });

  Future<SupportReport> createCommentReport({
    required int postId,
    required int commentId,
    required String reason,
    required String details,
  });

  Future<SupportReport> createMapReviewReport({
    required int pointId,
    required int reviewId,
    required String reason,
    required String details,
  });

  Future<SupportReport> createUserMarkerReport({
    required int markerId,
    required String reason,
    required String details,
  });

  Future<SupportReport> createUserMarkerCommentReport({
    required int markerId,
    required int commentId,
    required String reason,
    required String details,
  });
}
