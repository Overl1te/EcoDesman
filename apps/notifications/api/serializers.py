from rest_framework import serializers

from ..models import Notification


class NotificationActorSerializer(serializers.Serializer):
    id = serializers.IntegerField()
    name = serializers.CharField(source="display_name")
    avatar_url = serializers.CharField()
    role = serializers.CharField()


class NotificationSerializer(serializers.ModelSerializer):
    actor = NotificationActorSerializer(read_only=True)
    post_id = serializers.IntegerField(source="post.id", read_only=True)
    post_slug = serializers.SerializerMethodField()
    post_author_username = serializers.SerializerMethodField()
    comment_id = serializers.IntegerField(source="comment.id", read_only=True)
    support_thread_id = serializers.IntegerField(source="support_thread.id", read_only=True)
    report_id = serializers.IntegerField(source="report.id", read_only=True)

    def get_post_slug(self, obj: Notification) -> str | None:
        return getattr(obj.post, "slug", None)

    def get_post_author_username(self, obj: Notification) -> str | None:
        post_author = getattr(obj.post, "author", None)
        return getattr(post_author, "username", None)

    class Meta:
        model = Notification
        fields = (
            "id",
            "kind",
            "title",
            "body",
            "is_read",
            "created_at",
            "actor",
            "post_id",
            "post_slug",
            "post_author_username",
            "comment_id",
            "support_thread_id",
            "report_id",
        )
