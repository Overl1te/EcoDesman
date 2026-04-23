from django.db.models import Count, Q
from django.shortcuts import get_object_or_404
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.map_points.api.serializers import MapPointCategorySerializer
from apps.map_points.models import MapPoint, MapPointCategory, UserMapMarker
from apps.map_points.selectors import list_map_categories
from apps.posts.api.serializers import PostListSerializer
from apps.posts.models import Post
from apps.posts.selectors import list_posts
from apps.users.models import User

from .pagination import AdminPagination
from .permissions import IsAdminPanelUser
from .serializers import (
    AdminMapCategoryWriteSerializer,
    AdminMapPointSerializer,
    AdminMapPointWriteSerializer,
    AdminOverviewSerializer,
    AdminUserSerializer,
    AdminUserMapMarkerSerializer,
    AdminUserMapMarkerUpdateSerializer,
)


def _parse_optional_bool(value: str | None) -> bool | None:
    if value is None:
        return None

    normalized = str(value).strip().lower()
    if normalized in {"1", "true", "yes", "on"}:
        return True
    if normalized in {"0", "false", "no", "off"}:
        return False
    return None


def _parse_author_id(value: str | None) -> int | None:
    if not value:
        return None
    return int(value)


def _paginate(request, queryset, serializer_class, *, context: dict | None = None):
    paginator = AdminPagination()
    page = paginator.paginate_queryset(queryset, request)
    serializer = serializer_class(page, many=True, context=context or {})
    return paginator.get_paginated_response(serializer.data)


def _admin_map_points_queryset():
    return (
        MapPoint.objects.all()
        .prefetch_related("categories", "images")
        .annotate(review_count=Count("reviews", distinct=True))
        .order_by("-is_active", "sort_order", "title", "id")
    )


def _admin_user_markers_queryset():
    return (
        UserMapMarker.objects.all()
        .select_related("author")
        .prefetch_related("media")
        .annotate(
            comments_count=Count("comments", distinct=True),
            reports_count=Count("reports", distinct=True),
        )
        .order_by("-created_at", "-id")
    )


class AdminOverviewView(APIView):
    permission_classes = [IsAuthenticated, IsAdminPanelUser]

    def get(self, request):
        payload = {
            "posts_count": Post.objects.count(),
            "published_posts_count": Post.objects.filter(is_published=True).count(),
            "draft_posts_count": Post.objects.filter(is_published=False).count(),
            "map_points_count": MapPoint.objects.count(),
            "active_map_points_count": MapPoint.objects.filter(is_active=True).count(),
            "hidden_map_points_count": MapPoint.objects.filter(is_active=False).count(),
            "user_markers_count": UserMapMarker.objects.count(),
            "active_user_markers_count": UserMapMarker.objects.filter(
                is_active=True,
                is_public=True,
            ).count(),
            "hidden_user_markers_count": UserMapMarker.objects.filter(
                Q(is_active=False) | Q(is_public=False)
            ).count(),
            "users_count": User.objects.count(),
            "banned_users_count": User.objects.filter(is_active=False).count(),
            "admins_count": User.objects.filter(
                Q(role=User.Role.ADMIN) | Q(is_superuser=True)
            ).count(),
        }
        return Response(AdminOverviewSerializer(payload).data)


class AdminPostListView(APIView):
    permission_classes = [IsAuthenticated, IsAdminPanelUser]

    def get(self, request):
        try:
            queryset = list_posts(
                viewer=request.user,
                author_id=_parse_author_id(request.query_params.get("author_id")),
                search=request.query_params.get("search"),
                kind=request.query_params.get("kind"),
                ordering=request.query_params.get("ordering") or "recent",
                has_images=False,
                favorites_only=False,
                event_scope=request.query_params.get("event_scope"),
            )
        except ValueError:
            return Response(
                {"detail": "author_id must be an integer"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        published_filter = _parse_optional_bool(request.query_params.get("is_published"))
        if published_filter is not None:
            queryset = queryset.filter(is_published=published_filter)

        return _paginate(
            request,
            queryset,
            PostListSerializer,
            context={"request": request},
        )


class AdminUserListView(APIView):
    permission_classes = [IsAuthenticated, IsAdminPanelUser]

    def get(self, request):
        queryset = User.objects.all().order_by("-date_joined", "-id")

        search = (request.query_params.get("search") or "").strip()
        if search:
            for token in search.split():
                queryset = queryset.filter(
                    Q(username__icontains=token)
                    | Q(display_name__icontains=token)
                    | Q(email__icontains=token)
                    | Q(phone__icontains=token)
                    | Q(city__icontains=token)
                )

        role = (request.query_params.get("role") or "").strip().lower()
        valid_roles = {choice for choice, _label in User.Role.choices}
        if role in valid_roles:
            queryset = queryset.filter(role=role)

        status_filter = (request.query_params.get("status") or "").strip().lower()
        if status_filter == "active":
            queryset = queryset.filter(is_active=True)
        elif status_filter == "banned":
            queryset = queryset.filter(is_active=False)
        elif status_filter == "admin":
            queryset = queryset.filter(Q(role=User.Role.ADMIN) | Q(is_superuser=True))

        return _paginate(request, queryset, AdminUserSerializer)


class AdminMapCategoryListView(APIView):
    permission_classes = [IsAuthenticated, IsAdminPanelUser]

    def get(self, request):
        return Response(MapPointCategorySerializer(list_map_categories(), many=True).data)

    def post(self, request):
        serializer = AdminMapCategoryWriteSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        category = serializer.save()
        return Response(
            MapPointCategorySerializer(category).data,
            status=status.HTTP_201_CREATED,
        )


class AdminMapCategoryDetailView(APIView):
    permission_classes = [IsAuthenticated, IsAdminPanelUser]

    def get_object(self, category_id: int) -> MapPointCategory:
        return get_object_or_404(MapPointCategory, id=category_id)

    def patch(self, request, category_id: int):
        category = self.get_object(category_id)
        serializer = AdminMapCategoryWriteSerializer(
            category,
            data=request.data,
            partial=True,
        )
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(MapPointCategorySerializer(self.get_object(category_id)).data)

    def delete(self, request, category_id: int):
        category = self.get_object(category_id)
        category.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class AdminMapPointListCreateView(APIView):
    permission_classes = [IsAuthenticated, IsAdminPanelUser]

    def get(self, request):
        queryset = _admin_map_points_queryset()

        search = (request.query_params.get("search") or "").strip()
        if search:
            for token in search.split():
                queryset = queryset.filter(
                    Q(slug__icontains=token)
                    | Q(title__icontains=token)
                    | Q(short_description__icontains=token)
                    | Q(description__icontains=token)
                    | Q(address__icontains=token)
                )

        active_filter = _parse_optional_bool(request.query_params.get("is_active"))
        if active_filter is not None:
            queryset = queryset.filter(is_active=active_filter)

        category_id = request.query_params.get("category_id")
        if category_id:
            try:
                queryset = queryset.filter(categories__id=int(category_id))
            except ValueError:
                return Response(
                    {"detail": "category_id must be an integer"},
                    status=status.HTTP_400_BAD_REQUEST,
                )

        return _paginate(request, queryset.distinct(), AdminMapPointSerializer)

    def post(self, request):
        serializer = AdminMapPointWriteSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        point = serializer.save()
        point = get_object_or_404(_admin_map_points_queryset(), id=point.id)
        return Response(
            AdminMapPointSerializer(point).data,
            status=status.HTTP_201_CREATED,
        )


class AdminMapPointDetailView(APIView):
    permission_classes = [IsAuthenticated, IsAdminPanelUser]

    def get_object(self, point_id: int) -> MapPoint:
        return get_object_or_404(_admin_map_points_queryset(), id=point_id)

    def get(self, request, point_id: int):
        return Response(AdminMapPointSerializer(self.get_object(point_id)).data)

    def patch(self, request, point_id: int):
        point = self.get_object(point_id)
        serializer = AdminMapPointWriteSerializer(point, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(AdminMapPointSerializer(self.get_object(point_id)).data)

    def delete(self, request, point_id: int):
        point = get_object_or_404(MapPoint, id=point_id)
        point.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class AdminUserMapMarkerListView(APIView):
    permission_classes = [IsAuthenticated, IsAdminPanelUser]

    def get(self, request):
        queryset = _admin_user_markers_queryset()

        search = (request.query_params.get("search") or "").strip()
        if search:
            for token in search.split():
                queryset = queryset.filter(
                    Q(title__icontains=token)
                    | Q(description__icontains=token)
                    | Q(author__username__icontains=token)
                    | Q(author__email__icontains=token)
                    | Q(author__display_name__icontains=token)
                )

        active_filter = _parse_optional_bool(request.query_params.get("is_active"))
        if active_filter is not None:
            queryset = queryset.filter(is_active=active_filter)

        public_filter = _parse_optional_bool(request.query_params.get("is_public"))
        if public_filter is not None:
            queryset = queryset.filter(is_public=public_filter)

        return _paginate(request, queryset.distinct(), AdminUserMapMarkerSerializer)


class AdminUserMapMarkerDetailView(APIView):
    permission_classes = [IsAuthenticated, IsAdminPanelUser]

    def get_object(self, marker_id: int) -> UserMapMarker:
        return get_object_or_404(_admin_user_markers_queryset(), id=marker_id)

    def patch(self, request, marker_id: int):
        marker = self.get_object(marker_id)
        serializer = AdminUserMapMarkerUpdateSerializer(
            marker,
            data=request.data,
            partial=True,
        )
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(AdminUserMapMarkerSerializer(self.get_object(marker_id)).data)

    def delete(self, request, marker_id: int):
        marker = get_object_or_404(UserMapMarker, id=marker_id)
        marker.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)
