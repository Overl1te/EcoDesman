import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../domain/models/support_models.dart";
import "../../domain/repositories/support_repository.dart";
import "../datasources/support_remote_data_source.dart";

final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  return SupportRepositoryImpl(
    remoteDataSource: ref.watch(supportRemoteDataSourceProvider),
  );
});

class SupportRepositoryImpl implements SupportRepository {
  SupportRepositoryImpl({required SupportRemoteDataSource remoteDataSource})
    : _remoteDataSource = remoteDataSource;

  final SupportRemoteDataSource _remoteDataSource;

  @override
  Future<HelpCenterContent> fetchHelpCenterContent() {
    return _remoteDataSource.fetchHelpCenterContent();
  }

  @override
  Future<HelpDocument> fetchHelpDocument(String slug) {
    return _remoteDataSource.fetchHelpDocument(slug);
  }

  @override
  Future<SupportKnowledgeResponse> fetchKnowledge() {
    return _remoteDataSource.fetchKnowledge();
  }

  @override
  Future<SupportBotReply> askBot(String query) {
    return _remoteDataSource.askBot(query);
  }

  @override
  Future<List<SupportThreadSummary>> fetchThreads({bool teamView = false}) {
    return _remoteDataSource.fetchThreads(teamView: teamView);
  }

  @override
  Future<SupportThreadDetail> fetchThread(int threadId) {
    return _remoteDataSource.fetchThread(threadId);
  }

  @override
  Future<SupportThreadDetail> createThread({
    required String subject,
    required String body,
    required String category,
  }) {
    return _remoteDataSource.createThread(
      subject: subject,
      body: body,
      category: category,
    );
  }

  @override
  Future<SupportMessage> sendMessage({
    required int threadId,
    required String body,
  }) {
    return _remoteDataSource.sendMessage(threadId: threadId, body: body);
  }

  @override
  Future<SupportThreadDetail> updateThread({
    required int threadId,
    String? status,
    int? assignedToId,
  }) {
    return _remoteDataSource.updateThread(
      threadId: threadId,
      status: status,
      assignedToId: assignedToId,
    );
  }

  @override
  Future<List<SupportReport>> fetchTeamReports() {
    return _remoteDataSource.fetchTeamReports();
  }

  @override
  Future<SupportReport> updateReport({
    required int reportId,
    required String status,
    required String resolutionNote,
    required bool removeTarget,
  }) {
    return _remoteDataSource.updateReport(
      reportId: reportId,
      status: status,
      resolutionNote: resolutionNote,
      removeTarget: removeTarget,
    );
  }

  @override
  Future<SupportReport> createPostReport({
    required int postId,
    required String reason,
    required String details,
  }) {
    return _remoteDataSource.createPostReport(
      postId: postId,
      reason: reason,
      details: details,
    );
  }

  @override
  Future<SupportReport> createCommentReport({
    required int postId,
    required int commentId,
    required String reason,
    required String details,
  }) {
    return _remoteDataSource.createCommentReport(
      postId: postId,
      commentId: commentId,
      reason: reason,
      details: details,
    );
  }

  @override
  Future<SupportReport> createMapReviewReport({
    required int pointId,
    required int reviewId,
    required String reason,
    required String details,
  }) {
    return _remoteDataSource.createMapReviewReport(
      pointId: pointId,
      reviewId: reviewId,
      reason: reason,
      details: details,
    );
  }

  @override
  Future<SupportReport> createUserMarkerReport({
    required int markerId,
    required String reason,
    required String details,
  }) {
    return _remoteDataSource.createUserMarkerReport(
      markerId: markerId,
      reason: reason,
      details: details,
    );
  }

  @override
  Future<SupportReport> createUserMarkerCommentReport({
    required int markerId,
    required int commentId,
    required String reason,
    required String details,
  }) {
    return _remoteDataSource.createUserMarkerCommentReport(
      markerId: markerId,
      commentId: commentId,
      reason: reason,
      details: details,
    );
  }
}
