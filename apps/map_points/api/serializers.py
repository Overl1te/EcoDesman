from django.db import transaction
from rest_framework import serializers

from apps.users.api.serializers import UserSummarySerializer
from apps.users.services import can_manage_posts

from ..category_style import sort_categories
from ..models import (
    MapPoint,
    MapPointCategory,
    MapPointImage,
    MapPointReview,
    MapPointReviewImage,
    UserMapMarker,
    UserMapMarkerComment,
    UserMapMarkerMedia,
)


class MapPointCategorySerializer(serializers.ModelSerializer):
    sort_order = serializers.IntegerField(source="priority", read_only=True)
    color = serializers.CharField(source="marker_color", read_only=True)

    class Meta:
        model = MapPointCategory
        fields = ("id", "slug", "title", "sort_order", "color")


class MapPointImageSerializer(serializers.ModelSerializer):
    class Meta:
        model = MapPointImage
        fields = ("id", "image_url", "caption", "position")


class MapPointReviewImageSerializer(serializers.ModelSerializer):
    class Meta:
        model = MapPointReviewImage
        fields = ("id", "image_url", "caption", "position")


class MapPointReviewSerializer(serializers.ModelSerializer):
    author_name = serializers.SerializerMethodField()
    created_at = serializers.DateTimeField()
    images = serializers.SerializerMethodField()
    is_owner = serializers.SerializerMethodField()
    can_edit = serializers.SerializerMethodField()

    class Meta:
        model = MapPointReview
        fields = (
            "id",
            "author_name",
            "rating",
            "body",
            "created_at",
            "images",
            "is_owner",
            "can_edit",
        )

    def get_author_name(self, obj: MapPointReview) -> str:
        if obj.author_name:
            return obj.author_name

        if obj.author:
            return obj.author.display_name or obj.author.username

        return "Пользователь"


    def get_images(self, obj: MapPointReview):
        return MapPointReviewImageSerializer(obj.images.all(), many=True).data

    def get_is_owner(self, obj: MapPointReview) -> bool:
        request = self.context.get("request")
        return bool(request and request.user.is_authenticated and request.user.id == obj.author_id)

    def get_can_edit(self, obj: MapPointReview) -> bool:
        request = self.context.get("request")
        return bool(
            request
            and request.user.is_authenticated
            and (request.user.id == obj.author_id or can_manage_posts(request.user))
        )


class MapPointReviewWriteSerializer(serializers.Serializer):
    rating = serializers.IntegerField(min_value=1, max_value=5)
    body = serializers.CharField(min_length=3, max_length=2000)
    image_urls = serializers.ListField(
        child=serializers.URLField(),
        required=False,
        allow_empty=True,
    )


class BaseMapPointSerializer(serializers.ModelSerializer):
    latitude = serializers.FloatField()
    longitude = serializers.FloatField()
    categories = serializers.SerializerMethodField()
    primary_category = serializers.SerializerMethodField()

    def _sorted_categories(self, obj: MapPoint) -> list[MapPointCategory]:
        return sort_categories(obj.categories.all())

    def get_categories(self, obj: MapPoint):
        return MapPointCategorySerializer(self._sorted_categories(obj), many=True).data

    def get_primary_category(self, obj: MapPoint):
        categories = self._sorted_categories(obj)
        if not categories:
            return None
        return MapPointCategorySerializer(categories[0]).data


class MapPointSummarySerializer(BaseMapPointSerializer):
    cover_image_url = serializers.SerializerMethodField()

    class Meta:
        model = MapPoint
        fields = (
            "id",
            "slug",
            "title",
            "short_description",
            "latitude",
            "longitude",
            "categories",
            "primary_category",
            "cover_image_url",
        )

    def get_cover_image_url(self, obj: MapPoint) -> str:
        first_image = next(iter(obj.images.all()), None)
        return first_image.image_url if first_image else ""


class MapPointDetailSerializer(BaseMapPointSerializer):
    images = MapPointImageSerializer(many=True)
    reviews = MapPointReviewSerializer(many=True)

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
            "categories",
            "primary_category",
            "images",
            "reviews",
        )


class UserMapMarkerMediaSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserMapMarkerMedia
        fields = ("id", "media_url", "media_type", "caption", "position")


class UserMapMarkerCommentSerializer(serializers.ModelSerializer):
    author_name = serializers.SerializerMethodField()
    author = UserSummarySerializer(read_only=True)
    is_owner = serializers.SerializerMethodField()
    can_edit = serializers.SerializerMethodField()

    class Meta:
        model = UserMapMarkerComment
        fields = (
            "id",
            "author_name",
            "author",
            "body",
            "created_at",
            "updated_at",
            "is_owner",
            "can_edit",
        )

    def get_author_name(self, obj: UserMapMarkerComment) -> str:
        if obj.author_name:
            return obj.author_name
        if obj.author:
            return obj.author.display_name or obj.author.username
        return "Пользователь"

    def get_is_owner(self, obj: UserMapMarkerComment) -> bool:
        request = self.context.get("request")
        return bool(request and request.user.is_authenticated and request.user.id == obj.author_id)

    def get_can_edit(self, obj: UserMapMarkerComment) -> bool:
        request = self.context.get("request")
        return bool(
            request
            and request.user.is_authenticated
            and (request.user.id == obj.author_id or can_manage_posts(request.user))
        )


class UserMapMarkerSummarySerializer(serializers.ModelSerializer):
    latitude = serializers.FloatField()
    longitude = serializers.FloatField()
    author = UserSummarySerializer(read_only=True)
    cover_media_url = serializers.SerializerMethodField()
    cover_media_type = serializers.SerializerMethodField()
    comments_count = serializers.SerializerMethodField()
    is_owner = serializers.SerializerMethodField()

    class Meta:
        model = UserMapMarker
        fields = (
            "id",
            "title",
            "description",
            "latitude",
            "longitude",
            "author",
            "is_public",
            "is_active",
            "cover_media_url",
            "cover_media_type",
            "comments_count",
            "is_owner",
            "created_at",
            "updated_at",
        )

    def _first_media(self, obj: UserMapMarker) -> UserMapMarkerMedia | None:
        return next(iter(obj.media.all()), None)

    def get_cover_media_url(self, obj: UserMapMarker) -> str:
        first_media = self._first_media(obj)
        return first_media.media_url if first_media else ""

    def get_cover_media_type(self, obj: UserMapMarker) -> str:
        first_media = self._first_media(obj)
        return first_media.media_type if first_media else ""

    def get_comments_count(self, obj: UserMapMarker) -> int:
        return int(getattr(obj, "comments_count", obj.comments.count()))

    def get_is_owner(self, obj: UserMapMarker) -> bool:
        request = self.context.get("request")
        return bool(request and request.user.is_authenticated and request.user.id == obj.author_id)


class UserMapMarkerDetailSerializer(UserMapMarkerSummarySerializer):
    media = UserMapMarkerMediaSerializer(many=True, read_only=True)
    comments = UserMapMarkerCommentSerializer(many=True, read_only=True)

    class Meta(UserMapMarkerSummarySerializer.Meta):
        fields = UserMapMarkerSummarySerializer.Meta.fields + ("media", "comments")


class UserMapMarkerMediaWriteSerializer(serializers.Serializer):
    media_url = serializers.URLField()
    media_type = serializers.ChoiceField(
        choices=UserMapMarkerMedia.MediaType.choices,
        default=UserMapMarkerMedia.MediaType.IMAGE,
    )
    caption = serializers.CharField(required=False, allow_blank=True, max_length=140)


class UserMapMarkerWriteSerializer(serializers.ModelSerializer):
    latitude = serializers.FloatField()
    longitude = serializers.FloatField()
    media = UserMapMarkerMediaWriteSerializer(
        many=True,
        required=False,
        allow_empty=True,
    )

    class Meta:
        model = UserMapMarker
        fields = (
            "title",
            "description",
            "latitude",
            "longitude",
            "is_public",
            "media",
        )

    def validate_media(self, value: list[dict]) -> list[dict]:
        if len(value) > 12:
            raise serializers.ValidationError("Можно приложить не больше 12 медиафайлов")
        return value

    def _set_media(self, marker: UserMapMarker, media_items: list[dict]) -> None:
        UserMapMarkerMedia.objects.filter(marker=marker).delete()
        UserMapMarkerMedia.objects.bulk_create(
            [
                UserMapMarkerMedia(
                    marker=marker,
                    media_url=item["media_url"],
                    media_type=item.get("media_type") or UserMapMarkerMedia.MediaType.IMAGE,
                    caption=(item.get("caption") or "").strip(),
                    position=index,
                )
                for index, item in enumerate(media_items)
            ]
        )

    @transaction.atomic
    def create(self, validated_data: dict) -> UserMapMarker:
        media_items = validated_data.pop("media", [])
        marker = UserMapMarker.objects.create(**validated_data)
        self._set_media(marker, media_items)
        return marker

    @transaction.atomic
    def update(self, instance: UserMapMarker, validated_data: dict) -> UserMapMarker:
        media_items = validated_data.pop("media", None)

        for field, value in validated_data.items():
            setattr(instance, field, value)
        instance.save()

        if media_items is not None:
            self._set_media(instance, media_items)

        return instance


class UserMapMarkerCommentWriteSerializer(serializers.Serializer):
    body = serializers.CharField(min_length=2, max_length=2000)
