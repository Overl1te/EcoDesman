from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit

from rest_framework import serializers

from ..models import Post, PostComment, PostImage
from ..services import can_edit_comment, can_edit_post

MAX_POST_BODY_LENGTH = 5000
MAX_POST_PREVIEW_LENGTH = 240


def build_versioned_media_url(url: str, updated_at) -> str:
    if not url or updated_at is None:
        return url

    parts = urlsplit(url)
    query = dict(parse_qsl(parts.query, keep_blank_values=True))
    query["v"] = str(int(updated_at.timestamp()))
    return urlunsplit(
        (parts.scheme, parts.netloc, parts.path, urlencode(query), parts.fragment)
    )


def build_post_preview_text(value: str, limit: int = MAX_POST_PREVIEW_LENGTH) -> str:
    normalized = " ".join((value or "").split())
    if len(normalized) <= limit:
        return normalized

    candidate = normalized[:limit].rstrip()
    if " " in candidate:
        candidate = candidate.rsplit(" ", 1)[0].rstrip()

    return f"{candidate.rstrip('.,;:!?-')}…"


class PostAuthorSerializer(serializers.Serializer):
    id = serializers.IntegerField()
    name = serializers.CharField(source="display_name")
    username = serializers.CharField()
    avatar_url = serializers.SerializerMethodField()
    role = serializers.CharField()
    status_text = serializers.CharField()

    def get_avatar_url(self, obj) -> str:
        return build_versioned_media_url(
            getattr(obj, "avatar_url", ""),
            getattr(obj, "updated_at", None),
        )


class PostImageSerializer(serializers.ModelSerializer):
    class Meta:
        model = PostImage
        fields = ("id", "image_url", "position")


class PostCommentSerializer(serializers.ModelSerializer):
    author = PostAuthorSerializer(read_only=True)
    is_owner = serializers.SerializerMethodField()
    can_edit = serializers.SerializerMethodField()

    class Meta:
        model = PostComment
        fields = (
            "id",
            "body",
            "author",
            "created_at",
            "updated_at",
            "is_owner",
            "can_edit",
        )

    def get_is_owner(self, obj: PostComment) -> bool:
        request = self.context.get("request")
        return bool(request and request.user.is_authenticated and request.user.id == obj.author_id)

    def get_can_edit(self, obj: PostComment) -> bool:
        request = self.context.get("request")
        return bool(request and can_edit_comment(request.user, obj))


class PostListSerializer(serializers.ModelSerializer):
    author = PostAuthorSerializer(read_only=True)
    preview_text = serializers.SerializerMethodField()
    preview_image_url = serializers.SerializerMethodField()
    likes_count = serializers.IntegerField(read_only=True)
    comments_count = serializers.IntegerField(read_only=True)
    favorites_count = serializers.IntegerField(read_only=True)
    is_liked = serializers.BooleanField(read_only=True)
    is_favorited = serializers.BooleanField(read_only=True)
    has_images = serializers.BooleanField(read_only=True)
    is_owner = serializers.SerializerMethodField()
    can_edit = serializers.SerializerMethodField()

    class Meta:
        model = Post
        fields = (
            "id",
            "slug",
            "title",
            "body",
            "preview_text",
            "kind",
            "created_at",
            "updated_at",
            "published_at",
            "is_published",
            "author",
            "preview_image_url",
            "likes_count",
            "comments_count",
            "favorites_count",
            "view_count",
            "is_liked",
            "is_favorited",
            "has_images",
            "is_owner",
            "can_edit",
            "event_date",
            "event_starts_at",
            "event_ends_at",
            "event_location",
            "is_event_cancelled",
            "event_cancelled_at",
        )

    def get_preview_text(self, obj: Post) -> str:
        return build_post_preview_text(obj.body)

    def get_preview_image_url(self, obj: Post) -> str | None:
        first_image = obj.images.first()
        return first_image.image_url if first_image else None

    def get_is_owner(self, obj: Post) -> bool:
        request = self.context.get("request")
        return bool(request and request.user.is_authenticated and request.user.id == obj.author_id)

    def get_can_edit(self, obj: Post) -> bool:
        request = self.context.get("request")
        return bool(request and can_edit_post(request.user, obj))


class PostDetailSerializer(serializers.ModelSerializer):
    author = PostAuthorSerializer(read_only=True)
    images = PostImageSerializer(many=True, read_only=True)
    comments = PostCommentSerializer(many=True, read_only=True)
    likes_count = serializers.IntegerField(read_only=True)
    comments_count = serializers.IntegerField(read_only=True)
    favorites_count = serializers.IntegerField(read_only=True)
    is_liked = serializers.BooleanField(read_only=True)
    is_favorited = serializers.BooleanField(read_only=True)
    has_images = serializers.BooleanField(read_only=True)
    is_owner = serializers.SerializerMethodField()
    can_edit = serializers.SerializerMethodField()

    class Meta:
        model = Post
        fields = (
            "id",
            "slug",
            "title",
            "body",
            "kind",
            "created_at",
            "updated_at",
            "published_at",
            "author",
            "images",
            "comments",
            "likes_count",
            "comments_count",
            "favorites_count",
            "view_count",
            "is_liked",
            "is_favorited",
            "has_images",
            "is_owner",
            "can_edit",
            "is_published",
            "event_date",
            "event_starts_at",
            "event_ends_at",
            "event_location",
            "is_event_cancelled",
            "event_cancelled_at",
        )

    def get_is_owner(self, obj: Post) -> bool:
        request = self.context.get("request")
        return bool(request and request.user.is_authenticated and request.user.id == obj.author_id)

    def get_can_edit(self, obj: Post) -> bool:
        request = self.context.get("request")
        return bool(request and can_edit_post(request.user, obj))


class PostWriteSerializer(serializers.Serializer):
    title = serializers.CharField(required=False, allow_blank=True, max_length=160)
    body = serializers.CharField(required=False, max_length=MAX_POST_BODY_LENGTH)
    kind = serializers.ChoiceField(choices=Post.Kind.choices, required=False)
    is_published = serializers.BooleanField(required=False)
    image_urls = serializers.ListField(
        child=serializers.URLField(),
        required=False,
        allow_empty=True,
    )
    event_date = serializers.DateField(required=False, allow_null=True)
    event_starts_at = serializers.DateTimeField(required=False, allow_null=True)
    event_ends_at = serializers.DateTimeField(required=False, allow_null=True)
    event_location = serializers.CharField(required=False, allow_blank=True, max_length=200)
    is_event_cancelled = serializers.BooleanField(required=False)

    def validate(self, attrs: dict) -> dict:
        instance = self.context.get("post")
        kind = attrs.get("kind") or getattr(instance, "kind", None)
        if kind == Post.Kind.EVENT:
            event_date = attrs.get("event_date")
            start = attrs.get("event_starts_at")
            end = attrs.get("event_ends_at")
            if event_date is None and start is not None:
                event_date = start.date()
                attrs["event_date"] = event_date
            if event_date is None:
                event_date = getattr(instance, "event_date", None)
            if event_date is None:
                raise serializers.ValidationError(
                    {"event_date": "event_date is required for events"}
                )
            if start is not None and end is not None and end < start:
                raise serializers.ValidationError(
                    {"event_ends_at": "event_ends_at must be after event_starts_at"}
                )
        else:
            attrs["event_date"] = None
            attrs["is_event_cancelled"] = False
        return attrs


class EventCalendarEntrySerializer(serializers.ModelSerializer):
    author = PostAuthorSerializer(read_only=True)
    can_edit = serializers.SerializerMethodField()

    class Meta:
        model = Post
        fields = (
            "id",
            "slug",
            "title",
            "body",
            "kind",
            "author",
            "created_at",
            "updated_at",
            "event_date",
            "event_starts_at",
            "event_ends_at",
            "event_location",
            "is_event_cancelled",
            "event_cancelled_at",
            "can_edit",
        )

    def get_can_edit(self, obj: Post) -> bool:
        request = self.context.get("request")
        return bool(request and can_edit_post(request.user, obj))


class CommentWriteSerializer(serializers.Serializer):
    body = serializers.CharField()


class LikeStateSerializer(serializers.Serializer):
    likes_count = serializers.IntegerField()
    is_liked = serializers.BooleanField()


class FavoriteStateSerializer(serializers.Serializer):
    favorites_count = serializers.IntegerField()
    is_favorited = serializers.BooleanField()
