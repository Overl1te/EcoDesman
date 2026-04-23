from django.urls import path

from .views import (
    EventCalendarView,
    PostCommentDetailView,
    PostCommentListCreateView,
    PostCommentReportView,
    PostDetailView,
    PostBySlugView,
    PostEventCancellationView,
    PostFavoriteView,
    PostLikeView,
    PostListCreateView,
    PostReportView,
)

urlpatterns = [
    path("posts", PostListCreateView.as_view(), name="post-list"),
    path("posts/calendar", EventCalendarView.as_view(), name="post-calendar"),
    path(
        "posts/by-slug/<str:username>/<slug:post_slug>",
        PostBySlugView.as_view(),
        name="post-detail-by-slug",
    ),
    path("posts/<int:post_id>", PostDetailView.as_view(), name="post-detail"),
    path("posts/<int:post_id>/report", PostReportView.as_view(), name="post-report"),
    path("posts/<int:post_id>/cancel", PostEventCancellationView.as_view(), name="post-cancel"),
    path("posts/<int:post_id>/like", PostLikeView.as_view(), name="post-like"),
    path("posts/<int:post_id>/favorite", PostFavoriteView.as_view(), name="post-favorite"),
    path("posts/<int:post_id>/comments", PostCommentListCreateView.as_view(), name="post-comments"),
    path(
        "posts/<int:post_id>/comments/<int:comment_id>",
        PostCommentDetailView.as_view(),
        name="post-comment-detail",
    ),
    path(
        "posts/<int:post_id>/comments/<int:comment_id>/report",
        PostCommentReportView.as_view(),
        name="post-comment-report",
    ),
]
