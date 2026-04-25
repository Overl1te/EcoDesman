from django.contrib import messages
from django.contrib.auth import login, logout, update_session_auth_hash
from django.contrib.auth.decorators import login_required
from django.core.paginator import Paginator
from django.db.models import Prefetch
from django.http import Http404, HttpRequest, HttpResponse
from django.shortcuts import get_object_or_404, redirect, render
from django.urls import reverse
from django.utils import timezone
from django.views.decorators.http import require_GET, require_http_methods, require_POST

from apps.map_points.api.serializers import MapPointSummarySerializer
from apps.map_points.selectors import get_map_point, list_active_map_points, list_map_categories
from apps.notifications.models import Notification
from apps.notifications.selectors import list_notifications
from apps.posts.models import Post, PostComment, PostFavorite, PostImage, PostLike
from apps.posts.selectors import get_post, list_posts
from apps.posts.services import (
    add_comment,
    can_edit_post,
    create_post,
    favorite_post,
    increment_post_view,
    like_post,
    unfavorite_post,
    unlike_post,
    update_post,
)
from apps.users.models import User
from apps.users.selectors import get_profile_stats
from apps.users.services import authenticate_user
from apps.users.validation import AVATAR_MAX_BYTES

from .forms import (
    CommentForm,
    PostEditorForm,
    ProfilePasswordChangeForm,
    ProfileSettingsForm,
    RegisterForm,
    SignInForm,
    save_uploaded_image,
)

POSTS_PER_PAGE = 10


def _paginate(request: HttpRequest, queryset, *, per_page: int = POSTS_PER_PAGE):
    paginator = Paginator(queryset, per_page)
    page_number = request.GET.get("page") or 1
    return paginator.get_page(page_number)


def _render(
    request: HttpRequest,
    template_name: str,
    context: dict,
    *,
    active_nav: str,
    page_title: str,
) -> HttpResponse:
    context.setdefault("active_nav", active_nav)
    context.setdefault("page_title", page_title)
    context.setdefault("is_authenticated", request.user.is_authenticated)
    return render(request, template_name, context)


def _post_queryset_for_cards(request: HttpRequest, *, kind: str | None = None, favorites_only: bool = False):
    ordering = request.GET.get("ordering") or ("recommended" if request.user.is_authenticated else "recent")
    search = request.GET.get("search")
    has_images = request.GET.get("has_images") in {"1", "true", "on"}
    event_scope = request.GET.get("event_scope")
    return list_posts(
        viewer=request.user,
        search=search,
        kind=kind,
        ordering=ordering,
        has_images=has_images,
        favorites_only=favorites_only,
        event_scope=event_scope,
    ), ordering, search, has_images, event_scope


def _profile_context(user: User, *, viewer) -> dict:
    return {
        "profile_user": user,
        "profile_stats": get_profile_stats(user, viewer=viewer),
        "user_posts": list_posts(viewer=viewer, author_id=user.id, ordering="recent")[:20],
    }


def _selected_map_point(request: HttpRequest, points):
    selected_id = request.GET.get("point")
    if selected_id:
        try:
            selected_id_int = int(selected_id)
        except ValueError:
            selected_id_int = None
        else:
            for point in points:
                if point.id == selected_id_int:
                    return point
    return points[0] if points else None


def _map_points_payload(request: HttpRequest, points):
    current_category = request.GET.get("category", "")
    current_point = request.GET.get("point", "")
    payload = []
    for point in MapPointSummarySerializer(points, many=True).data:
        payload.append(
            {
                **point,
                "url": f"{reverse('web-map')}?category={current_category}&point={point['id']}"
                if current_category
                else f"{reverse('web-map')}?point={point['id']}",
                "selected": str(point["id"]) == current_point,
            }
        )
    return payload


def _event_datetime_initial(value):
    if not value:
        return ""
    return timezone.localtime(value).strftime("%Y-%m-%dT%H:%M")


def _extract_uploaded_image_urls(request: HttpRequest, *, field_name: str = "image_files", folder: str = "uploads/posts"):
    image_urls = []
    for upload in request.FILES.getlist(field_name):
        image_urls.append(save_uploaded_image(upload, request, folder=folder))
    return image_urls


@require_GET
def feed_page(request: HttpRequest) -> HttpResponse:
    queryset, ordering, search, has_images, _ = _post_queryset_for_cards(request)
    page_obj = _paginate(request, queryset)
    return _render(
        request,
        "web/feed.html",
        {
            "page_obj": page_obj,
            "ordering": ordering,
            "search_query": search or "",
            "has_images": has_images,
            "show_new_post": request.user.is_authenticated,
        },
        active_nav="feed",
        page_title="Лента",
    )


@require_GET
def events_page(request: HttpRequest) -> HttpResponse:
    queryset, ordering, search, has_images, event_scope = _post_queryset_for_cards(request, kind=Post.Kind.EVENT)
    page_obj = _paginate(request, queryset)
    return _render(
        request,
        "web/feed.html",
        {
            "page_obj": page_obj,
            "ordering": ordering,
            "search_query": search or "",
            "has_images": has_images,
            "event_scope": event_scope or "all",
            "is_events_page": True,
            "show_new_post": request.user.is_authenticated,
        },
        active_nav="events",
        page_title="Мероприятия",
    )


@require_http_methods(["GET", "POST"])
def login_page(request: HttpRequest) -> HttpResponse:
    if request.user.is_authenticated:
        return redirect("web-feed")

    form = SignInForm(request.POST or None)
    if request.method == "POST" and form.is_valid():
        user = authenticate_user(
            identifier=form.cleaned_data["identifier"],
            password=form.cleaned_data["password"],
        )
        if user is None:
            form.add_error(None, "Неверный логин или пароль")
        else:
            login(request, user)
            return redirect(request.GET.get("next") or "web-feed")

    return _render(
        request,
        "web/auth.html",
        {"mode": "login", "form": form},
        active_nav="auth",
        page_title="Вход",
    )


@require_http_methods(["GET", "POST"])
def register_page(request: HttpRequest) -> HttpResponse:
    if request.user.is_authenticated:
        return redirect("web-feed")

    form = RegisterForm(request.POST or None)
    if request.method == "POST" and form.is_valid():
        user = form.save()
        login(request, user)
        messages.success(request, "Аккаунт создан")
        return redirect("web-feed")

    return _render(
        request,
        "web/auth.html",
        {"mode": "register", "form": form},
        active_nav="auth",
        page_title="Регистрация",
    )


@require_POST
def logout_page(request: HttpRequest) -> HttpResponse:
    logout(request)
    return redirect("web-feed")


@require_http_methods(["GET", "POST"])
def post_detail_page(request: HttpRequest, post_id: int) -> HttpResponse:
    post = get_object_or_404(get_post(post_id, viewer=request.user))
    if request.method == "GET":
        increment_post_view(post, viewer=request.user)
        post = get_object_or_404(get_post(post_id, viewer=request.user))
    comment_form = CommentForm()
    return _render(
        request,
        "web/post_detail.html",
        {
            "post": post,
            "comment_form": comment_form,
            "can_edit_post": can_edit_post(request.user, post),
        },
        active_nav="feed",
        page_title=post.title or "Публикация",
    )


@login_required
@require_POST
def toggle_post_like(request: HttpRequest, post_id: int) -> HttpResponse:
    post = get_object_or_404(Post, id=post_id, is_published=True)
    if PostLike.objects.filter(post=post, user=request.user).exists():
        unlike_post(post=post, user=request.user)
    else:
        like_post(post=post, user=request.user)
    return redirect(request.POST.get("next") or reverse("web-post-detail", args=[post_id]))


@login_required
@require_POST
def toggle_post_favorite(request: HttpRequest, post_id: int) -> HttpResponse:
    post = get_object_or_404(Post, id=post_id, is_published=True)
    if PostFavorite.objects.filter(post=post, user=request.user).exists():
        unfavorite_post(post=post, user=request.user)
    else:
        favorite_post(post=post, user=request.user)
    return redirect(request.POST.get("next") or reverse("web-post-detail", args=[post_id]))


@login_required
@require_POST
def create_post_comment(request: HttpRequest, post_id: int) -> HttpResponse:
    post = get_object_or_404(get_post(post_id, viewer=request.user))
    form = CommentForm(request.POST)
    if form.is_valid():
        add_comment(post=post, author=request.user, body=form.cleaned_data["body"])
        messages.success(request, "Комментарий добавлен")
    else:
        messages.error(request, "Не удалось добавить комментарий")
    return redirect("web-post-detail", post_id=post_id)


@login_required
@require_http_methods(["GET", "POST"])
def post_create_page(request: HttpRequest) -> HttpResponse:
    form = PostEditorForm(request.POST or None, request.FILES or None)
    if request.method == "POST" and form.is_valid():
        image_urls = _extract_uploaded_image_urls(request)
        post = create_post(
            author=request.user,
            validated_data={
                "title": form.cleaned_data["title"],
                "body": form.cleaned_data["body"],
                "kind": form.cleaned_data["kind"],
                "is_published": form.cleaned_data["is_published"],
                "event_starts_at": form.cleaned_data["event_starts_at"],
                "event_ends_at": form.cleaned_data["event_ends_at"],
                "event_location": form.cleaned_data["event_location"],
                "image_urls": image_urls,
            },
        )
        messages.success(request, "Публикация создана")
        return redirect("web-post-detail", post_id=post.id)

    return _render(
        request,
        "web/post_editor.html",
        {"form": form, "editor_title": "Новая публикация"},
        active_nav="feed",
        page_title="Новая публикация",
    )


@login_required
@require_http_methods(["GET", "POST"])
def post_edit_page(request: HttpRequest, post_id: int) -> HttpResponse:
    post = get_object_or_404(Post.objects.prefetch_related("images"), id=post_id)
    if not can_edit_post(request.user, post):
        raise Http404

    initial = {
        "title": post.title,
        "body": post.body,
        "kind": post.kind,
        "is_published": post.is_published,
        "event_starts_at": _event_datetime_initial(post.event_starts_at),
        "event_ends_at": _event_datetime_initial(post.event_ends_at),
        "event_location": post.event_location,
    }
    form = PostEditorForm(request.POST or None, request.FILES or None, initial=initial)
    if request.method == "POST" and form.is_valid():
        image_urls = None
        uploaded_image_urls = _extract_uploaded_image_urls(request)
        if uploaded_image_urls or form.cleaned_data["clear_images"]:
            image_urls = uploaded_image_urls
        update_post(
            post=post,
            validated_data={
                "title": form.cleaned_data["title"],
                "body": form.cleaned_data["body"],
                "kind": form.cleaned_data["kind"],
                "is_published": form.cleaned_data["is_published"],
                "event_starts_at": form.cleaned_data["event_starts_at"],
                "event_ends_at": form.cleaned_data["event_ends_at"],
                "event_location": form.cleaned_data["event_location"],
                **({"image_urls": image_urls} if image_urls is not None else {}),
            },
        )
        messages.success(request, "Публикация обновлена")
        return redirect("web-post-detail", post_id=post.id)

    return _render(
        request,
        "web/post_editor.html",
        {
            "form": form,
            "editor_title": "Редактирование публикации",
            "editing_post": post,
        },
        active_nav="feed",
        page_title="Редактирование публикации",
    )


@login_required
@require_POST
def post_delete(request: HttpRequest, post_id: int) -> HttpResponse:
    post = get_object_or_404(Post, id=post_id)
    if not can_edit_post(request.user, post):
        raise Http404
    post.delete()
    messages.success(request, "Публикация удалена")
    return redirect("web-profile")


@login_required
@require_GET
def profile_page(request: HttpRequest) -> HttpResponse:
    context = _profile_context(request.user, viewer=request.user)
    return _render(
        request,
        "web/profile.html",
        context,
        active_nav="profile",
        page_title="Профиль",
    )


@require_GET
def public_profile_page(request: HttpRequest, user_id: int) -> HttpResponse:
    user = get_object_or_404(User, id=user_id)
    context = _profile_context(user, viewer=request.user)
    context["is_own_profile"] = request.user.is_authenticated and request.user.id == user.id
    return _render(
        request,
        "web/profile.html",
        context,
        active_nav="profile" if context["is_own_profile"] else "feed",
        page_title=user.display_name or user.username,
    )


@login_required
@require_http_methods(["GET", "POST"])
def profile_settings_page(request: HttpRequest) -> HttpResponse:
    is_password_form = request.POST.get("_form") == "password"
    settings_data = request.POST if request.method == "POST" and not is_password_form else None
    settings_files = request.FILES if request.method == "POST" and not is_password_form else None
    password_data = request.POST if request.method == "POST" and is_password_form else None
    form = ProfileSettingsForm(
        settings_data,
        settings_files,
        instance=request.user,
    )
    password_form = ProfilePasswordChangeForm(
        password_data,
        user=request.user,
    )

    if request.method == "POST" and not is_password_form and form.is_valid():
        user = form.save(commit=False)
        avatar_file = form.cleaned_data.get("avatar_file")
        if avatar_file:
            user.avatar_url = save_uploaded_image(
                avatar_file,
                request,
                folder="uploads/avatars",
                max_bytes=AVATAR_MAX_BYTES,
            )
        if not user.display_name:
            user.display_name = user.username
        user.save()
        messages.success(request, "Профиль обновлен")
        return redirect("web-profile")

    if request.method == "POST" and is_password_form and password_form.is_valid():
        request.user.set_password(password_form.cleaned_data["new_password"])
        request.user.save(update_fields=["password"])
        update_session_auth_hash(request, request.user)
        messages.success(request, "Пароль обновлен")
        return redirect("web-profile-settings")

    return _render(
        request,
        "web/profile_settings.html",
        {"form": form, "password_form": password_form},
        active_nav="profile",
        page_title="Настройки профиля",
    )


@login_required
@require_GET
def favorites_page(request: HttpRequest) -> HttpResponse:
    queryset, ordering, search, has_images, _ = _post_queryset_for_cards(request, favorites_only=True)
    page_obj = _paginate(request, queryset)
    return _render(
        request,
        "web/feed.html",
        {
            "page_obj": page_obj,
            "ordering": ordering,
            "search_query": search or "",
            "has_images": has_images,
            "is_favorites_page": True,
        },
        active_nav="favorites",
        page_title="Избранное",
    )


@login_required
@require_GET
def notifications_page(request: HttpRequest) -> HttpResponse:
    notifications = list_notifications(request.user)
    Notification.objects.filter(recipient=request.user, is_read=False).update(is_read=True)
    return _render(
        request,
        "web/notifications.html",
        {"notifications": notifications},
        active_nav="profile",
        page_title="Уведомления",
    )


@login_required
@require_POST
def read_all_notifications(request: HttpRequest) -> HttpResponse:
    Notification.objects.filter(recipient=request.user, is_read=False).update(is_read=True)
    return redirect("web-notifications")


@require_GET
def map_page(request: HttpRequest) -> HttpResponse:
    category_slug = request.GET.get("category", "").strip()
    categories = list(list_map_categories())
    points_queryset = list_active_map_points()
    if category_slug:
        points_queryset = points_queryset.filter(categories__slug=category_slug).distinct()

    points = list(points_queryset)
    selected_point = _selected_map_point(request, points)

    return _render(
        request,
        "web/map.html",
        {
            "categories": categories,
            "current_category": category_slug,
            "points": points,
            "selected_point": selected_point,
            "map_points_json": _map_points_payload(request, points),
        },
        active_nav="map",
        page_title="Карта",
    )
