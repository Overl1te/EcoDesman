from django.contrib import admin

from .models import Post, PostComment, PostImage, PostLike


class PostImageInline(admin.TabularInline):
    model = PostImage
    extra = 0


class PostCommentInline(admin.TabularInline):
    model = PostComment
    extra = 0


@admin.register(Post)
class PostAdmin(admin.ModelAdmin):
    list_display = ("id", "title", "author", "kind", "published_at", "is_published", "view_count")
    list_filter = ("kind", "is_published")
    search_fields = ("title", "body", "author__display_name", "author__email")
    inlines = [PostImageInline, PostCommentInline]


@admin.register(PostImage)
class PostImageAdmin(admin.ModelAdmin):
    list_display = ("id", "post", "position")


@admin.register(PostLike)
class PostLikeAdmin(admin.ModelAdmin):
    list_display = ("id", "post", "user", "created_at")


@admin.register(PostComment)
class PostCommentAdmin(admin.ModelAdmin):
    list_display = ("id", "post", "author", "created_at")
    search_fields = ("body", "author__display_name", "author__email")
