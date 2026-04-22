from django.db import transaction
from rest_framework import serializers

from apps.map_points.api.serializers import (
    BaseMapPointSerializer,
    MapPointImageSerializer,
    UserMapMarkerMediaSerializer,
)
from apps.map_points.models import (
    MapPoint,
    MapPointCategory,
    MapPointImage,
    UserMapMarker,
)
from apps.users.api.serializers import UserSummarySerializer
from apps.users.api.serializers import build_versioned_media_url
from apps.users.models import User


class AdminOverviewSerializer(serializers.Serializer):
    posts_count = serializers.IntegerField()
    published_posts_count = serializers.IntegerField()
    draft_posts_count = serializers.IntegerField()
    map_points_count = serializers.IntegerField()
    active_map_points_count = serializers.IntegerField()
    hidden_map_points_count = serializers.IntegerField()
    user_markers_count = serializers.IntegerField()
    active_user_markers_count = serializers.IntegerField()
    hidden_user_markers_count = serializers.IntegerField()
    users_count = serializers.IntegerField()
    banned_users_count = serializers.IntegerField()
    admins_count = serializers.IntegerField()


class AdminUserSerializer(serializers.ModelSerializer):
    name = serializers.CharField(source="display_name")
    avatar_url = serializers.SerializerMethodField()
    is_banned = serializers.BooleanField(read_only=True)
    can_access_admin = serializers.BooleanField(source="is_admin_role", read_only=True)
    can_access_support = serializers.BooleanField(read_only=True)

    class Meta:
        model = User
        fields = (
            "id",
            "name",
            "username",
            "email",
            "phone",
            "avatar_url",
            "role",
            "status_text",
            "city",
            "warning_count",
            "is_banned",
            "is_active",
            "is_superuser",
            "date_joined",
            "last_login",
            "can_access_admin",
            "can_access_support",
        )

    def get_avatar_url(self, obj: User) -> str:
        return build_versioned_media_url(obj.avatar_url, obj.updated_at)


class AdminMapPointSerializer(BaseMapPointSerializer):
    images = MapPointImageSerializer(many=True, read_only=True)
    review_count = serializers.SerializerMethodField()

    class Meta:
        model = MapPoint
        fields = (
            "id",
            "slug",
            "title",
            "short_description",
            "description",
            "address",
            "working_hours",
            "latitude",
            "longitude",
            "is_active",
            "sort_order",
            "categories",
            "primary_category",
            "images",
            "review_count",
            "created_at",
            "updated_at",
        )

    def get_review_count(self, obj: MapPoint) -> int:
        return int(getattr(obj, "review_count", obj.reviews.count()))


class AdminMapPointWriteSerializer(serializers.ModelSerializer):
    latitude = serializers.FloatField()
    longitude = serializers.FloatField()
    category_ids = serializers.ListField(
        child=serializers.IntegerField(min_value=1),
        required=False,
        allow_empty=True,
    )
    image_urls = serializers.ListField(
        child=serializers.URLField(),
        required=False,
        allow_empty=True,
    )

    class Meta:
        model = MapPoint
        fields = (
            "slug",
            "title",
            "short_description",
            "description",
            "address",
            "working_hours",
            "latitude",
            "longitude",
            "is_active",
            "sort_order",
            "category_ids",
            "image_urls",
        )

    def validate_category_ids(self, value: list[int]) -> list[int]:
        unique_ids = list(dict.fromkeys(value))
        categories_count = MapPointCategory.objects.filter(id__in=unique_ids).count()
        if categories_count != len(unique_ids):
            raise serializers.ValidationError("Unknown category ids")
        return unique_ids

    def _set_categories(self, point: MapPoint, category_ids: list[int]) -> None:
        point.categories.set(MapPointCategory.objects.filter(id__in=category_ids))

    def _set_images(self, point: MapPoint, image_urls: list[str]) -> None:
        MapPointImage.objects.filter(point=point).delete()
        MapPointImage.objects.bulk_create(
            [
                MapPointImage(
                    point=point,
                    image_url=image_url,
                    position=index,
                )
                for index, image_url in enumerate(image_urls)
            ]
        )

    @transaction.atomic
    def create(self, validated_data: dict) -> MapPoint:
        category_ids = validated_data.pop("category_ids", [])
        image_urls = validated_data.pop("image_urls", [])

        point = MapPoint.objects.create(**validated_data)
        self._set_categories(point, category_ids)
        self._set_images(point, image_urls)
        return point

    @transaction.atomic
    def update(self, instance: MapPoint, validated_data: dict) -> MapPoint:
        category_ids = validated_data.pop("category_ids", None)
        image_urls = validated_data.pop("image_urls", None)

        for field, value in validated_data.items():
            setattr(instance, field, value)
        instance.save()

        if category_ids is not None:
            self._set_categories(instance, category_ids)
        if image_urls is not None:
            self._set_images(instance, image_urls)

        return instance


class AdminUserMapMarkerSerializer(serializers.ModelSerializer):
    latitude = serializers.FloatField()
    longitude = serializers.FloatField()
    author = UserSummarySerializer(read_only=True)
    media = UserMapMarkerMediaSerializer(many=True, read_only=True)
    comments_count = serializers.SerializerMethodField()
    reports_count = serializers.SerializerMethodField()

    class Meta:
        model = UserMapMarker
        fields = (
            "id",
            "title",
            "description",
            "latitude",
            "longitude",
            "author",
            "media",
            "is_public",
            "is_active",
            "moderation_note",
            "comments_count",
            "reports_count",
            "created_at",
            "updated_at",
        )

    def get_comments_count(self, obj: UserMapMarker) -> int:
        return int(getattr(obj, "comments_count", obj.comments.count()))

    def get_reports_count(self, obj: UserMapMarker) -> int:
        return int(getattr(obj, "reports_count", obj.reports.count()))


class AdminUserMapMarkerUpdateSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserMapMarker
        fields = ("is_public", "is_active", "moderation_note")
