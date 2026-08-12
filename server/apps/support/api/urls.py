from django.urls import path

from .views import (
    ContentReportCreateView,
    HelpCenterView,
    HelpDocumentView,
    LegalDocumentDownloadView,
    SupportBotReplyView,
    SupportKnowledgeView,
    SupportTeamReportDetailView,
    SupportTeamReportListView,
    SupportTeamThreadListView,
    SupportTeamThreadUpdateView,
    SupportThreadDetailView,
    SupportThreadListCreateView,
    SupportThreadMessageCreateView,
)

urlpatterns = [
    path("support/help-center", HelpCenterView.as_view(), name="support-help-center"),
    path("support/help-center/<slug:slug>", HelpDocumentView.as_view(), name="support-help-document"),
    path("support/knowledge", SupportKnowledgeView.as_view(), name="support-knowledge"),
    path(
        "support/legal-documents/<slug:slug>/download",
        LegalDocumentDownloadView.as_view(),
        name="support-legal-document-download",
    ),
    path("support/bot/reply", SupportBotReplyView.as_view(), name="support-bot-reply"),
    path("support/threads", SupportThreadListCreateView.as_view(), name="support-thread-list"),
    path("support/threads/<int:thread_id>", SupportThreadDetailView.as_view(), name="support-thread-detail"),
    path(
        "support/threads/<int:thread_id>/messages",
        SupportThreadMessageCreateView.as_view(),
        name="support-thread-message-list",
    ),
    path(
        "support/team/threads",
        SupportTeamThreadListView.as_view(),
        name="support-team-thread-list",
    ),
    path(
        "support/team/threads/<int:thread_id>",
        SupportTeamThreadUpdateView.as_view(),
        name="support-team-thread-detail",
    ),
    path("support/reports", ContentReportCreateView.as_view(), name="support-report-create"),
    path(
        "support/team/reports",
        SupportTeamReportListView.as_view(),
        name="support-team-report-list",
    ),
    path(
        "support/team/reports/<int:report_id>",
        SupportTeamReportDetailView.as_view(),
        name="support-team-report-detail",
    ),
]
