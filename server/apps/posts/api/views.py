import calendar
from datetime import date

from django.shortcuts import get_object_or_404
from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.support.api.serializers import ContentReportSerializer, ContentReportWriteSerializer
from apps.support.models import ContentReport
from apps.support.services import create_content_report

from ..models import Post, PostComment
from ..selectors import (
    get_post,
    get_post_by_author_username_and_slug,
    list_comments,
    list_event_calendar_posts,
    list_posts,
)
from ..services import (
    add_comment,
    can_edit_comment,
    can_edit_post,
    create_post,
    favorite_post,
    increment_post_view,
    like_post,
    set_event_cancellation,
    unfavorite_post,
    unlike_post,
    update_post,
)
from .pagination import PostPagination
from .serializers import (
    CommentWriteSerializer,
    FavoriteStateSerializer,
    LikeStateSerializer,
    PostCommentSerializer,
    PostDetailSerializer,
    EventCalendarEntrySerializer,
    PostListSerializer,
    PostWriteSerializer,
)


def _parse_bool(value: str | None) -> bool:
    return str(value).strip().lower() in {"1", "true", "yes", "on"}


class PostListCreateView(APIView):
    def get_permissions(self):
        if self.request.method == "POST":
            return [IsAuthenticated()]
        return [AllowAny()]

    def get(self, request):
        author_id = request.query_params.get("author_id")
        search = request.query_params.get("search")
        kind = request.query_params.get("kind")
        ordering = request.query_params.get("ordering")
        event_scope = request.query_params.get("event_scope")
        try:
            author_id_value = int(author_id) if author_id else None
        except ValueError:
            return Response(
                {"detail": "author_id must be an integer"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        queryset = list_posts(
            viewer=request.user,
            author_id=author_id_value,
            search=search,
            kind=kind,
            ordering=ordering,
            has_images=_parse_bool(request.query_params.get("has_images")),
            favorites_only=_parse_bool(request.query_params.get("favorites_only")),
            event_scope=event_scope,
        )
        paginator = PostPagination()
        page = paginator.paginate_queryset(queryset, request)
        serializer = PostListSerializer(page, many=True, context={"request": request})
        return paginator.get_paginated_response(serializer.data)

    def post(self, request):
        serializer = PostWriteSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        post = create_post(author=request.user, validated_data=serializer.validated_data)
        post = get_object_or_404(get_post(post.id, viewer=request.user))
        return Response(
            PostDetailSerializer(post, context={"request": request}).data,
            status=status.HTTP_201_CREATED,
        )


class PostDetailView(APIView):
    permission_classes = [AllowAny]

    def get(self, request, post_id: int):
        post = get_object_or_404(get_post(post_id, viewer=request.user))
        increment_post_view(post, viewer=request.user)
        post = get_object_or_404(get_post(post_id, viewer=request.user))
        return Response(PostDetailSerializer(post, context={"request": request}).data)

    def patch(self, request, post_id: int):
        if not request.user.is_authenticated:
            return Response(status=status.HTTP_401_UNAUTHORIZED)

        post = get_object_or_404(Post, id=post_id)
        if not can_edit_post(request.user, post):
            return Response(status=status.HTTP_403_FORBIDDEN)

        serializer = PostWriteSerializer(
            data=request.data,
            partial=True,
            context={"post": post},
        )
        serializer.is_valid(raise_exception=True)
        update_post(post=post, validated_data=serializer.validated_data)
        post = get_object_or_404(get_post(post_id, viewer=request.user))
        return Response(PostDetailSerializer(post, context={"request": request}).data)

    def delete(self, request, post_id: int):
        if not request.user.is_authenticated:
            return Response(status=status.HTTP_401_UNAUTHORIZED)

        post = get_object_or_404(Post, id=post_id)
        if not can_edit_post(request.user, post):
            return Response(status=status.HTTP_403_FORBIDDEN)

        post.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class PostLikeView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, post_id: int):
        post = get_object_or_404(Post, id=post_id, is_published=True)
        like_post(post=post, user=request.user)
        post = get_object_or_404(get_post(post_id, viewer=request.user))
        return Response(
            LikeStateSerializer(
                {
                    "likes_count": post.likes_count,
                    "is_liked": True,
                }
            ).data
        )

    def delete(self, request, post_id: int):
        post = get_object_or_404(Post, id=post_id, is_published=True)
        unlike_post(post=post, user=request.user)
        post = get_object_or_404(get_post(post_id, viewer=request.user))
        return Response(
            LikeStateSerializer(
                {
                    "likes_count": post.likes_count,
                    "is_liked": False,
                }
            ).data
        )


class PostBySlugView(APIView):
    permission_classes = [AllowAny]

    def get(self, request, username: str, post_slug: str):
        post = get_object_or_404(
            get_post_by_author_username_and_slug(
                username,
                post_slug,
                viewer=request.user,
            )
        )
        increment_post_view(post, viewer=request.user)
        post = get_object_or_404(
            get_post_by_author_username_and_slug(
                username,
                post_slug,
                viewer=request.user,
            )
        )
        return Response(PostDetailSerializer(post, context={"request": request}).data)


class PostFavoriteView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, post_id: int):
        post = get_object_or_404(Post, id=post_id, is_published=True)
        favorite_post(post=post, user=request.user)
        post = get_object_or_404(get_post(post_id, viewer=request.user))
        return Response(
            FavoriteStateSerializer(
                {
                    "favorites_count": post.favorites_count,
                    "is_favorited": True,
                }
            ).data
        )

    def delete(self, request, post_id: int):
        post = get_object_or_404(Post, id=post_id, is_published=True)
        unfavorite_post(post=post, user=request.user)
        post = get_object_or_404(get_post(post_id, viewer=request.user))
        return Response(
            FavoriteStateSerializer(
                {
                    "favorites_count": post.favorites_count,
                    "is_favorited": False,
                }
            ).data
        )


class EventCalendarView(APIView):
    permission_classes = [AllowAny]

    def get(self, request):
        today = date.today()
        raw_year = request.query_params.get("year")
        raw_month = request.query_params.get("month")

        try:
            year = int(raw_year) if raw_year else today.year
            month = int(raw_month) if raw_month else today.month
        except ValueError:
            return Response(
                {"detail": "year and month must be integers"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if month < 1 or month > 12:
            return Response(
                {"detail": "month must be between 1 and 12"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        month_start = date(year, month, 1)
        month_end = date(year, month, calendar.monthrange(year, month)[1])
        events = list_event_calendar_posts(
            start_date=month_start,
            end_date=month_end,
            viewer=request.user,
        )
        serializer = EventCalendarEntrySerializer(
            events,
            many=True,
            context={"request": request},
        )
        return Response(
            {
                "year": year,
                "month": month,
                "starts_on": month_start.isoformat(),
                "ends_on": month_end.isoformat(),
                "events": serializer.data,
            }
        )


class PostEventCancellationView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, post_id: int):
        post = get_object_or_404(Post, id=post_id, is_published=True)
        if not can_edit_post(request.user, post):
            return Response(status=status.HTTP_403_FORBIDDEN)
        if post.kind != Post.Kind.EVENT:
            return Response(
                {"detail": "Only event posts can be cancelled"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        set_event_cancellation(post=post, actor=request.user, is_cancelled=True)
        post = get_object_or_404(get_post(post_id, viewer=request.user))
        return Response(PostDetailSerializer(post, context={"request": request}).data)

    def delete(self, request, post_id: int):
        post = get_object_or_404(Post, id=post_id, is_published=True)
        if not can_edit_post(request.user, post):
            return Response(status=status.HTTP_403_FORBIDDEN)
        if post.kind != Post.Kind.EVENT:
            return Response(
                {"detail": "Only event posts can be cancelled"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        set_event_cancellation(post=post, actor=request.user, is_cancelled=False)
        post = get_object_or_404(get_post(post_id, viewer=request.user))
        return Response(PostDetailSerializer(post, context={"request": request}).data)


class PostCommentListCreateView(APIView):
    def get_permissions(self):
        if self.request.method == "POST":
            return [IsAuthenticated()]
        return [AllowAny()]

    def get(self, request, post_id: int):
        get_object_or_404(get_post(post_id, viewer=request.user))
        comments = list_comments(post_id)
        serializer = PostCommentSerializer(comments, many=True, context={"request": request})
        return Response(serializer.data)

    def post(self, request, post_id: int):
        post = get_object_or_404(get_post(post_id, viewer=request.user))
        serializer = CommentWriteSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        comment = add_comment(
            post=post,
            author=request.user,
            body=serializer.validated_data["body"],
        )
        return Response(
            PostCommentSerializer(comment, context={"request": request}).data,
            status=status.HTTP_201_CREATED,
        )


class PostCommentDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def patch(self, request, post_id: int, comment_id: int):
        comment = get_object_or_404(PostComment, id=comment_id, post_id=post_id)
        if not can_edit_comment(request.user, comment):
            return Response(status=status.HTTP_403_FORBIDDEN)

        serializer = CommentWriteSerializer(data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        if "body" in serializer.validated_data:
            comment.body = serializer.validated_data["body"]
            comment.save(update_fields=["body", "updated_at"])
        return Response(PostCommentSerializer(comment, context={"request": request}).data)

    def delete(self, request, post_id: int, comment_id: int):
        comment = get_object_or_404(PostComment, id=comment_id, post_id=post_id)
        if not can_edit_comment(request.user, comment):
            return Response(status=status.HTTP_403_FORBIDDEN)
        comment.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class PostReportView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, post_id: int):
        post = get_object_or_404(Post, id=post_id)
        serializer = ContentReportWriteSerializer(
            data={
                **request.data,
                "target_type": ContentReport.TargetType.POST,
                "target_id": post.id,
            }
        )
        serializer.is_valid(raise_exception=True)
        report = create_content_report(
            reporter=request.user,
            target_type=ContentReport.TargetType.POST,
            target=post,
            target_snapshot=post.title or f"Пост #{post.id}",
            reason=serializer.validated_data["reason"],
            details=serializer.validated_data.get("details", ""),
        )
        return Response(
            ContentReportSerializer(report, context={"request": request}).data,
            status=status.HTTP_201_CREATED,
        )


class PostCommentReportView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, post_id: int, comment_id: int):
        comment = get_object_or_404(PostComment, id=comment_id, post_id=post_id)
        serializer = ContentReportWriteSerializer(
            data={
                **request.data,
                "target_type": ContentReport.TargetType.COMMENT,
                "target_id": comment.id,
            }
        )
        serializer.is_valid(raise_exception=True)
        report = create_content_report(
            reporter=request.user,
            target_type=ContentReport.TargetType.COMMENT,
            target=comment,
            target_snapshot=comment.body[:80],
            reason=serializer.validated_data["reason"],
            details=serializer.validated_data.get("details", ""),
        )
        return Response(
            ContentReportSerializer(report, context={"request": request}).data,
            status=status.HTTP_201_CREATED,
        )
