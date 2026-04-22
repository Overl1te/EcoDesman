from rest_framework import serializers

from apps.users.api.serializers import build_versioned_media_url
from apps.users.models import User

from ..models import ContentReport, SupportMessage, SupportThread


class SupportKnowledgeEntrySerializer(serializers.Serializer):
    id = serializers.CharField()
    category = serializers.CharField()
    title = serializers.CharField()
    answer = serializers.CharField()
    keywords = serializers.ListField(child=serializers.CharField())
    is_featured = serializers.BooleanField()


class SupportParticipantSerializer(serializers.ModelSerializer):
    name = serializers.CharField(source="display_name")
    avatar_url = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = ("id", "name", "username", "avatar_url", "role")

    def get_avatar_url(self, obj: User) -> str:
        return build_versioned_media_url(obj.avatar_url, obj.updated_at)


class SupportMessageSerializer(serializers.ModelSerializer):
    author = SupportParticipantSerializer(read_only=True)
    sender_name = serializers.SerializerMethodField()

    class Meta:
        model = SupportMessage
        fields = ("id", "sender_type", "sender_name", "body", "created_at", "author")

    def get_sender_name(self, obj: SupportMessage) -> str:
        if obj.author:
            return obj.author.display_name or obj.author.username
        if obj.sender_type == SupportMessage.SenderType.BOT:
            return "FAQ-бот"
        if obj.sender_type == SupportMessage.SenderType.SYSTEM:
            return "Система"
        return "Поддержка"


class SupportReportBadgeSerializer(serializers.ModelSerializer):
    class Meta:
        model = ContentReport
        fields = ("id", "target_type", "reason", "status", "created_at")


class SupportThreadSummarySerializer(serializers.ModelSerializer):
    created_by = SupportParticipantSerializer(read_only=True)
    assigned_to = SupportParticipantSerializer(read_only=True)
    unread_count = serializers.SerializerMethodField()
    report = serializers.SerializerMethodField()

    class Meta:
        model = SupportThread
        fields = (
            "id",
            "subject",
            "category",
            "status",
            "created_at",
            "updated_at",
            "last_message_at",
            "last_message_preview",
            "unread_count",
            "created_by",
            "assigned_to",
            "report",
        )

    def get_unread_count(self, obj: SupportThread) -> int:
        if self.context.get("team_view"):
            return obj.unread_for_support_count
        return obj.unread_for_user_count

    def get_report(self, obj: SupportThread):
        report = getattr(obj, "linked_report", None)
        if report is None:
            return None
        return SupportReportBadgeSerializer(report).data


class SupportThreadDetailSerializer(SupportThreadSummarySerializer):
    messages = SupportMessageSerializer(many=True, read_only=True)

    class Meta(SupportThreadSummarySerializer.Meta):
        fields = SupportThreadSummarySerializer.Meta.fields + ("messages",)


class SupportThreadWriteSerializer(serializers.Serializer):
    subject = serializers.CharField(min_length=3, max_length=160)
    body = serializers.CharField(min_length=3, max_length=4000)
    category = serializers.ChoiceField(
        choices=SupportThread.Category.choices,
        required=False,
        default=SupportThread.Category.GENERAL,
    )


class SupportThreadUpdateSerializer(serializers.Serializer):
    status = serializers.ChoiceField(choices=SupportThread.Status.choices, required=False)
    assigned_to_id = serializers.IntegerField(required=False, allow_null=True)

    def validate_assigned_to_id(self, value: int | None):
        if value is None:
            return value
        user = User.objects.filter(id=value).first()
        if user is None or not user.can_access_support:
            raise serializers.ValidationError("Unknown support assignee")
        return value


class SupportMessageWriteSerializer(serializers.Serializer):
    body = serializers.CharField(min_length=2, max_length=4000)


class ContentReportSerializer(serializers.ModelSerializer):
    reporter = SupportParticipantSerializer(read_only=True)
    reviewed_by = SupportParticipantSerializer(read_only=True)
    target_id = serializers.IntegerField(read_only=True)
    target_label = serializers.CharField(read_only=True)
    thread_id = serializers.IntegerField(source="support_thread_id", read_only=True)
    post_id = serializers.IntegerField(read_only=True)
    comment_id = serializers.IntegerField(read_only=True)
    review_id = serializers.IntegerField(read_only=True)
    user_marker_id = serializers.IntegerField(read_only=True)
    user_marker_comment_id = serializers.IntegerField(read_only=True)

    class Meta:
        model = ContentReport
        fields = (
            "id",
            "target_type",
            "target_id",
            "target_label",
            "reason",
            "details",
            "status",
            "resolution_note",
            "created_at",
            "updated_at",
            "reporter",
            "reviewed_by",
            "thread_id",
            "post_id",
            "comment_id",
            "review_id",
            "user_marker_id",
            "user_marker_comment_id",
        )


class ContentReportWriteSerializer(serializers.Serializer):
    target_type = serializers.ChoiceField(choices=ContentReport.TargetType.choices)
    target_id = serializers.IntegerField(min_value=1)
    reason = serializers.ChoiceField(choices=ContentReport.Reason.choices)
    details = serializers.CharField(required=False, allow_blank=True, max_length=2000)


class ContentReportUpdateSerializer(serializers.Serializer):
    status = serializers.ChoiceField(choices=ContentReport.Status.choices)
    resolution_note = serializers.CharField(required=False, allow_blank=True, max_length=2000)
    remove_target = serializers.BooleanField(required=False, default=False)


class SupportBotQuerySerializer(serializers.Serializer):
    query = serializers.CharField(min_length=2, max_length=300)
