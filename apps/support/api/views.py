from django.http import Http404, HttpResponse
from django.shortcuts import get_object_or_404
from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.map_points.models import MapPointReview, UserMapMarker, UserMapMarkerComment
from apps.posts.models import Post, PostComment

from ..help_center_content import (
    get_help_center_content,
    get_help_document,
)
from ..legal_documents import LEGAL_DOCUMENTS_BY_SLUG
from ..models import ContentReport, SupportThread
from ..pdf_generation import generate_legal_document_pdf
from ..selectors import (
    list_support_knowledge,
    list_team_reports,
    list_team_threads,
    list_user_threads,
)
from ..services import (
    append_support_message,
    build_bot_reply,
    can_access_support_center,
    close_support_thread,
    create_content_report,
    create_support_thread,
    mark_thread_read,
    update_report_status,
)
from .serializers import (
    ContentReportSerializer,
    ContentReportUpdateSerializer,
    ContentReportWriteSerializer,
    SupportBotQuerySerializer,
    SupportKnowledgeEntrySerializer,
    SupportMessageSerializer,
    SupportMessageWriteSerializer,
    SupportThreadDetailSerializer,
    SupportThreadSummarySerializer,
    SupportThreadUpdateSerializer,
    SupportThreadWriteSerializer,
)


def _get_report_target(target_type: str, target_id: int):
    if target_type == ContentReport.TargetType.POST:
        post = get_object_or_404(Post, id=target_id)
        return post, (post.title or f"Пост #{post.id}")
    if target_type == ContentReport.TargetType.COMMENT:
        comment = get_object_or_404(PostComment, id=target_id)
        return comment, comment.body[:80]
    if target_type == ContentReport.TargetType.MAP_REVIEW:
        review = get_object_or_404(MapPointReview, id=target_id)
        return review, (review.body[:80] or f"Отзыв #{review.id}")
    if target_type == ContentReport.TargetType.USER_MARKER:
        marker = get_object_or_404(UserMapMarker, id=target_id)
        return marker, (marker.title[:80] or f"Метка #{marker.id}")
    if target_type == ContentReport.TargetType.USER_MARKER_COMMENT:
        comment = get_object_or_404(UserMapMarkerComment, id=target_id)
        return comment, (comment.body[:80] or f"Комментарий #{comment.id}")
    raise ValueError("Unknown target type")


def _get_thread_for_user(user, thread_id: int) -> SupportThread:
    queryset = (
        SupportThread.objects.all()
        if can_access_support_center(user)
        else list_user_threads(user)
    )
    return get_object_or_404(queryset.prefetch_related("messages__author"), id=thread_id)


class SupportKnowledgeView(APIView):
    permission_classes = [AllowAny]

    def get(self, request):
        knowledge = list_support_knowledge()
        serializer = SupportKnowledgeEntrySerializer
        return Response(
            {
                "featured": serializer(knowledge["featured"], many=True).data,
                "faq": serializer(knowledge["faq"], many=True).data,
                "suggested_prompts": knowledge["suggested_prompts"],
            }
        )


class HelpCenterView(APIView):
    permission_classes = [AllowAny]

    def get(self, request):
        return Response(get_help_center_content(request))


class HelpDocumentView(APIView):
    permission_classes = [AllowAny]

    def get(self, request, slug: str):
        document = get_help_document(slug, request=request)
        if document is None:
            raise Http404("Legal document not found")
        return Response(document)


class LegalDocumentDownloadView(APIView):
    permission_classes = [AllowAny]

    def get(self, request, slug: str):
        document = LEGAL_DOCUMENTS_BY_SLUG.get(slug)
        document_content = get_help_document(slug)
        if document is None or document_content is None:
            raise Http404("Legal document not found")

        return HttpResponse(
            generate_legal_document_pdf(document_content),
            content_type="application/pdf",
            headers={
                "Content-Disposition": (
                    f'attachment; filename="{document["file_name"]}"'
                ),
            },
        )


class SupportBotReplyView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = SupportBotQuerySerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        reply = build_bot_reply(serializer.validated_data["query"])
        return Response(
            {
                "reply": reply["reply"],
                "matched_article": (
                    SupportKnowledgeEntrySerializer(reply["matched_article"]).data
                    if reply["matched_article"]
                    else None
                ),
                "suggestions": SupportKnowledgeEntrySerializer(
                    reply["suggestions"],
                    many=True,
                ).data,
            }
        )


class SupportThreadListCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        threads = list_user_threads(request.user)
        return Response(
            SupportThreadSummarySerializer(
                threads,
                many=True,
                context={"request": request},
            ).data
        )

    def post(self, request):
        serializer = SupportThreadWriteSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        thread = create_support_thread(
            created_by=request.user,
            subject=serializer.validated_data["subject"],
            body=serializer.validated_data["body"],
            category=serializer.validated_data["category"],
        )
        thread = _get_thread_for_user(request.user, thread.id)
        return Response(
            SupportThreadDetailSerializer(thread, context={"request": request}).data,
            status=status.HTTP_201_CREATED,
        )


class SupportThreadDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, thread_id: int):
        thread = _get_thread_for_user(request.user, thread_id)
        mark_thread_read(thread=thread, viewer=request.user)
        thread = _get_thread_for_user(request.user, thread.id)
        return Response(
            SupportThreadDetailSerializer(
                thread,
                context={
                    "request": request,
                    "team_view": can_access_support_center(request.user)
                    and request.user.id != thread.created_by_id,
                },
            ).data
        )


class SupportThreadMessageCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, thread_id: int):
        thread = _get_thread_for_user(request.user, thread_id)
        serializer = SupportMessageWriteSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        as_support = can_access_support_center(request.user) and request.user.id != thread.created_by_id
        message = append_support_message(
            thread=thread,
            author=request.user,
            body=serializer.validated_data["body"],
            as_support=as_support,
        )
        return Response(
            SupportMessageSerializer(message, context={"request": request}).data,
            status=status.HTTP_201_CREATED,
        )


class SupportTeamThreadListView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if not can_access_support_center(request.user):
            return Response(status=status.HTTP_403_FORBIDDEN)

        threads = list_team_threads()
        return Response(
            SupportThreadSummarySerializer(
                threads,
                many=True,
                context={"request": request, "team_view": True},
            ).data
        )


class SupportTeamThreadUpdateView(APIView):
    permission_classes = [IsAuthenticated]

    def patch(self, request, thread_id: int):
        if not can_access_support_center(request.user):
            return Response(status=status.HTTP_403_FORBIDDEN)

        thread = get_object_or_404(SupportThread, id=thread_id)
        serializer = SupportThreadUpdateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        update_fields = ["updated_at"]
        if "status" in serializer.validated_data:
            next_status = serializer.validated_data["status"]
            if next_status == SupportThread.Status.CLOSED:
                close_support_thread(thread=thread, actor=request.user)
                update_fields = []
            else:
                thread.status = next_status
                update_fields.append("status")
        if "assigned_to_id" in serializer.validated_data:
            thread.assigned_to_id = serializer.validated_data["assigned_to_id"]
            update_fields.append("assigned_to")
        if update_fields:
            thread.save(update_fields=update_fields)

        thread = _get_thread_for_user(request.user, thread.id)
        return Response(
            SupportThreadDetailSerializer(
                thread,
                context={"request": request, "team_view": True},
            ).data
        )


class ContentReportCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = ContentReportWriteSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        target, target_label = _get_report_target(
            serializer.validated_data["target_type"],
            serializer.validated_data["target_id"],
        )
        report = create_content_report(
            reporter=request.user,
            target_type=serializer.validated_data["target_type"],
            target=target,
            target_snapshot=target_label,
            reason=serializer.validated_data["reason"],
            details=serializer.validated_data.get("details", ""),
        )
        return Response(
            ContentReportSerializer(report, context={"request": request}).data,
            status=status.HTTP_201_CREATED,
        )


class SupportTeamReportListView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if not can_access_support_center(request.user):
            return Response(status=status.HTTP_403_FORBIDDEN)

        reports = list_team_reports()
        return Response(ContentReportSerializer(reports, many=True).data)


class SupportTeamReportDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def patch(self, request, report_id: int):
        if not can_access_support_center(request.user):
            return Response(status=status.HTTP_403_FORBIDDEN)

        report = get_object_or_404(ContentReport, id=report_id)
        serializer = ContentReportUpdateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        report = update_report_status(
            report=report,
            reviewer=request.user,
            status=serializer.validated_data["status"],
            resolution_note=serializer.validated_data.get("resolution_note", ""),
            remove_target=serializer.validated_data.get("remove_target", False),
        )
        return Response(ContentReportSerializer(report, context={"request": request}).data)
