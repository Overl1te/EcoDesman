from django.shortcuts import get_object_or_404
from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.support.api.serializers import ContentReportSerializer, ContentReportWriteSerializer
from apps.support.models import ContentReport
from apps.support.services import create_content_report
from apps.users.services import can_manage_posts

from ..models import (
    MapPointReview,
    MapPointReviewImage,
    UserMapMarker,
    UserMapMarkerComment,
)
from ..selectors import (
    get_map_point,
    get_visible_user_map_marker,
    list_active_map_points,
    list_map_categories,
    list_visible_user_map_markers,
)
from .serializers import (
    MapPointCategorySerializer,
    MapPointDetailSerializer,
    MapPointReviewSerializer,
    MapPointReviewWriteSerializer,
    MapPointSummarySerializer,
    UserMapMarkerCommentSerializer,
    UserMapMarkerCommentWriteSerializer,
    UserMapMarkerDetailSerializer,
    UserMapMarkerSummarySerializer,
    UserMapMarkerWriteSerializer,
)

MAP_BOUNDS = {
    "south": 56.230306,
    "west": 43.792757,
    "north": 56.399790,
    "east": 44.157004,
}


class MapOverviewView(APIView):
    permission_classes = [AllowAny]

    def get(self, request):
        points = list_active_map_points()
        categories = list_map_categories()
        user_markers = list_visible_user_map_markers(viewer=request.user)
        return Response(
            {
                "bounds": MAP_BOUNDS,
                "categories": MapPointCategorySerializer(categories, many=True).data,
                "points": MapPointSummarySerializer(points, many=True).data,
                "user_markers": UserMapMarkerSummarySerializer(
                    user_markers,
                    many=True,
                    context={"request": request},
                ).data,
            }
        )


class MapPointDetailView(APIView):
    permission_classes = [AllowAny]

    def get(self, request, point_id: int):
        point = get_object_or_404(get_map_point(point_id))
        return Response(MapPointDetailSerializer(point, context={"request": request}).data)


class MapPointReviewCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, point_id: int):
        point = get_object_or_404(get_map_point(point_id))
        serializer = MapPointReviewWriteSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        display_name = request.user.display_name or request.user.username
        review = MapPointReview.objects.create(
            point=point,
            author=request.user,
            author_name=display_name,
            rating=serializer.validated_data["rating"],
            body=serializer.validated_data["body"].strip(),
        )
        image_urls = serializer.validated_data.get("image_urls", [])
        if image_urls:
            MapPointReviewImage.objects.bulk_create(
                [
                    MapPointReviewImage(
                        review=review,
                        image_url=image_url,
                        position=index,
                    )
                    for index, image_url in enumerate(image_urls)
                ]
            )
            review = (
                MapPointReview.objects.select_related("author")
                .prefetch_related("images")
                .get(id=review.id)
            )

        return Response(
            MapPointReviewSerializer(review, context={"request": request}).data,
            status=status.HTTP_201_CREATED,
        )


class MapPointReviewDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def delete(self, request, point_id: int, review_id: int):
        review = get_object_or_404(MapPointReview, id=review_id, point_id=point_id)
        if request.user.id != review.author_id and not can_manage_posts(request.user):
            return Response(status=status.HTTP_403_FORBIDDEN)
        review.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class MapPointReviewReportView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, point_id: int, review_id: int):
        review = get_object_or_404(MapPointReview, id=review_id, point_id=point_id)
        serializer = ContentReportWriteSerializer(
            data={
                **request.data,
                "target_type": ContentReport.TargetType.MAP_REVIEW,
                "target_id": review.id,
            }
        )
        serializer.is_valid(raise_exception=True)
        report = create_content_report(
            reporter=request.user,
            target_type=ContentReport.TargetType.MAP_REVIEW,
            target=review,
            target_snapshot=review.body[:80] or f"Отзыв #{review.id}",
            reason=serializer.validated_data["reason"],
            details=serializer.validated_data.get("details", ""),
        )
        return Response(
            ContentReportSerializer(report, context={"request": request}).data,
            status=status.HTTP_201_CREATED,
        )


class UserMapMarkerListCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = UserMapMarkerWriteSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        marker = serializer.save(author=request.user)
        marker = get_object_or_404(
            list_visible_user_map_markers(viewer=request.user),
            id=marker.id,
        )
        return Response(
            UserMapMarkerDetailSerializer(marker, context={"request": request}).data,
            status=status.HTTP_201_CREATED,
        )


class UserMapMarkerDetailView(APIView):
    permission_classes = [AllowAny]

    def get(self, request, marker_id: int):
        marker = get_object_or_404(
            get_visible_user_map_marker(marker_id, viewer=request.user),
        )
        return Response(
            UserMapMarkerDetailSerializer(marker, context={"request": request}).data
        )

    def patch(self, request, marker_id: int):
        if not request.user.is_authenticated:
            return Response(status=status.HTTP_401_UNAUTHORIZED)

        marker = get_object_or_404(
            get_visible_user_map_marker(marker_id, viewer=request.user),
        )
        if request.user.id != marker.author_id and not can_manage_posts(request.user):
            return Response(status=status.HTTP_403_FORBIDDEN)

        serializer = UserMapMarkerWriteSerializer(marker, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        marker = get_object_or_404(
            list_visible_user_map_markers(viewer=request.user),
            id=marker.id,
        )
        return Response(
            UserMapMarkerDetailSerializer(marker, context={"request": request}).data
        )

    def delete(self, request, marker_id: int):
        if not request.user.is_authenticated:
            return Response(status=status.HTTP_401_UNAUTHORIZED)

        marker = get_object_or_404(
            UserMapMarker.objects.filter(id=marker_id).select_related("author"),
        )
        if request.user.id != marker.author_id and not can_manage_posts(request.user):
            return Response(status=status.HTTP_403_FORBIDDEN)

        marker.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class UserMapMarkerCommentCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, marker_id: int):
        marker = get_object_or_404(
            get_visible_user_map_marker(marker_id, viewer=request.user),
        )
        serializer = UserMapMarkerCommentWriteSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        display_name = request.user.display_name or request.user.username
        comment = UserMapMarkerComment.objects.create(
            marker=marker,
            author=request.user,
            author_name=display_name,
            body=serializer.validated_data["body"].strip(),
        )
        return Response(
            UserMapMarkerCommentSerializer(comment, context={"request": request}).data,
            status=status.HTTP_201_CREATED,
        )


class UserMapMarkerCommentDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def delete(self, request, marker_id: int, comment_id: int):
        marker = get_object_or_404(
            get_visible_user_map_marker(marker_id, viewer=request.user),
        )
        comment = get_object_or_404(
            UserMapMarkerComment,
            id=comment_id,
            marker=marker,
        )
        if (
            request.user.id != comment.author_id
            and request.user.id != marker.author_id
            and not can_manage_posts(request.user)
        ):
            return Response(status=status.HTTP_403_FORBIDDEN)

        comment.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class UserMapMarkerReportView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, marker_id: int):
        marker = get_object_or_404(
            get_visible_user_map_marker(marker_id, viewer=request.user),
        )
        serializer = ContentReportWriteSerializer(
            data={
                **request.data,
                "target_type": ContentReport.TargetType.USER_MARKER,
                "target_id": marker.id,
            }
        )
        serializer.is_valid(raise_exception=True)
        report = create_content_report(
            reporter=request.user,
            target_type=ContentReport.TargetType.USER_MARKER,
            target=marker,
            target_snapshot=marker.title[:80] or f"Метка #{marker.id}",
            reason=serializer.validated_data["reason"],
            details=serializer.validated_data.get("details", ""),
        )
        return Response(
            ContentReportSerializer(report, context={"request": request}).data,
            status=status.HTTP_201_CREATED,
        )


class UserMapMarkerCommentReportView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, marker_id: int, comment_id: int):
        marker = get_object_or_404(
            get_visible_user_map_marker(marker_id, viewer=request.user),
        )
        comment = get_object_or_404(
            UserMapMarkerComment,
            id=comment_id,
            marker=marker,
        )
        serializer = ContentReportWriteSerializer(
            data={
                **request.data,
                "target_type": ContentReport.TargetType.USER_MARKER_COMMENT,
                "target_id": comment.id,
            }
        )
        serializer.is_valid(raise_exception=True)
        report = create_content_report(
            reporter=request.user,
            target_type=ContentReport.TargetType.USER_MARKER_COMMENT,
            target=comment,
            target_snapshot=comment.body[:80] or f"Комментарий #{comment.id}",
            reason=serializer.validated_data["reason"],
            details=serializer.validated_data.get("details", ""),
        )
        return Response(
            ContentReportSerializer(report, context={"request": request}).data,
            status=status.HTTP_201_CREATED,
        )
