import os
import uuid

from django import forms
from django.contrib.auth.password_validation import validate_password
from django.core.files.storage import default_storage

from apps.posts.models import Post
from apps.users.models import User
from apps.users.services import (
    create_user_account,
    normalize_email,
    normalize_username,
)
from apps.users.validation import (
    AVATAR_MAX_BYTES,
    IMAGE_UPLOAD_MAX_BYTES,
    PROFILE_BIO_MAX_LENGTH,
    clean_avatar_position,
    clean_avatar_scale,
    clean_plain_text,
    normalize_social_url,
    validate_upload_size,
)


def save_uploaded_image(
    upload,
    request,
    *,
    folder: str = "uploads",
    max_bytes: int = IMAGE_UPLOAD_MAX_BYTES,
) -> str:
    validate_upload_size(upload, max_bytes=max_bytes, label="Фото")
    extension = os.path.splitext(upload.name)[1].lower() or ".jpg"
    if extension not in {".jpg", ".jpeg", ".png", ".webp"}:
        raise forms.ValidationError("Поддерживаются только JPG, PNG и WEBP")

    relative_path = default_storage.save(
        os.path.join(folder, f"{uuid.uuid4().hex}{extension}"),
        upload,
    )
    public_url = default_storage.url(relative_path).replace("\\", "/")
    if not public_url.startswith(("http://", "https://")):
        public_url = request.build_absolute_uri(public_url)
    return public_url


class MultipleFileInput(forms.ClearableFileInput):
    allow_multiple_selected = True


class MultipleFileField(forms.FileField):
    widget = MultipleFileInput

    def clean(self, data, initial=None):
        single_clean = super().clean
        if not data:
            return []
        if isinstance(data, (list, tuple)):
            return [single_clean(item, initial) for item in data]
        return [single_clean(data, initial)]


class SignInForm(forms.Form):
    identifier = forms.CharField(label="Почта или логин")
    password = forms.CharField(label="Пароль", widget=forms.PasswordInput)


class RegisterForm(forms.Form):
    display_name = forms.CharField(label="Имя", max_length=120, required=False)
    username = forms.CharField(label="Логин", min_length=3, max_length=150)
    email = forms.EmailField(label="Email")
    password = forms.CharField(label="Пароль", widget=forms.PasswordInput, min_length=8)
    password_confirmation = forms.CharField(
        label="Повтор пароля",
        widget=forms.PasswordInput,
        min_length=8,
    )
    accept_terms = forms.BooleanField(label="Принимаю пользовательское соглашение")
    accept_privacy_policy = forms.BooleanField(
        label="Подтверждаю ознакомление с политикой обработки персональных данных"
    )
    accept_personal_data = forms.BooleanField(
        label="Даю согласие на обработку персональных данных"
    )
    accept_public_personal_data_distribution = forms.BooleanField(
        label="Разрешаю публичное размещение данных по согласию на распространение персональных данных",
        required=False,
    )

    def clean_username(self):
        username = normalize_username(self.cleaned_data["username"])
        if not username:
            raise forms.ValidationError("Введите логин")
        User.username_validator(username)
        if User.objects.filter(username__iexact=username).exists():
            raise forms.ValidationError("Этот логин уже занят")
        return username

    def clean_email(self):
        email = normalize_email(self.cleaned_data["email"])
        if User.objects.filter(email__iexact=email).exists():
            raise forms.ValidationError("Аккаунт с таким email уже существует")
        return email

    def clean_display_name(self):
        return clean_plain_text(
            self.cleaned_data.get("display_name"),
            max_length=120,
            field_label="Имя",
        )

    def clean(self):
        cleaned_data = super().clean()
        password = cleaned_data.get("password")
        password_confirmation = cleaned_data.get("password_confirmation")
        if password and password_confirmation and password != password_confirmation:
            self.add_error("password_confirmation", "Пароли не совпадают")

        if password:
            temp_user = User(
                username=cleaned_data.get("username", ""),
                email=cleaned_data.get("email", ""),
                display_name=cleaned_data.get("display_name", "").strip(),
            )
            try:
                validate_password(password, user=temp_user)
            except forms.ValidationError as error:
                self.add_error("password", error)
        return cleaned_data

    def save(self):
        return create_user_account(
            username=self.cleaned_data["username"],
            email=self.cleaned_data["email"],
            password=self.cleaned_data["password"],
            display_name=self.cleaned_data.get("display_name", ""),
            accept_terms=self.cleaned_data["accept_terms"],
            accept_privacy_policy=self.cleaned_data["accept_privacy_policy"],
            accept_personal_data=self.cleaned_data["accept_personal_data"],
            accept_public_personal_data_distribution=self.cleaned_data[
                "accept_public_personal_data_distribution"
            ],
        )


class CommentForm(forms.Form):
    body = forms.CharField(
        label="Комментарий",
        widget=forms.Textarea(attrs={"rows": 4}),
        max_length=4000,
    )


class ProfileSettingsForm(forms.ModelForm):
    avatar_file = forms.ImageField(
        label="Аватар",
        required=False,
        help_text="JPG, PNG или WEBP до 2 МБ",
    )

    class Meta:
        model = User
        fields = (
            "display_name",
            "username",
            "email",
            "status_text",
            "bio",
            "city",
            "telegram_url",
            "vk_url",
            "instagram_url",
            "max_url",
            "avatar_position_x",
            "avatar_position_y",
            "avatar_scale",
        )
        widgets = {
            "bio": forms.Textarea(
                attrs={
                    "rows": 5,
                    "maxlength": PROFILE_BIO_MAX_LENGTH,
                    "data-profile-bio": "true",
                }
            ),
            "avatar_position_x": forms.NumberInput(
                attrs={"type": "range", "min": "0", "max": "100", "data-avatar-x": "true"}
            ),
            "avatar_position_y": forms.NumberInput(
                attrs={"type": "range", "min": "0", "max": "100", "data-avatar-y": "true"}
            ),
            "avatar_scale": forms.NumberInput(
                attrs={
                    "type": "range",
                    "min": "1",
                    "max": "3",
                    "step": "0.05",
                    "data-avatar-scale": "true",
                }
            ),
        }
        labels = {
            "display_name": "Имя",
            "username": "Логин",
            "status_text": "Статус",
            "bio": "Описание профиля",
            "city": "Город",
            "telegram_url": "Telegram",
            "vk_url": "VK",
            "instagram_url": "Instagram",
            "max_url": "MAX",
            "avatar_position_x": "Сдвиг по горизонтали",
            "avatar_position_y": "Сдвиг по вертикали",
            "avatar_scale": "Масштаб",
        }

    def clean_username(self):
        username = normalize_username(self.cleaned_data["username"])
        if not username:
            raise forms.ValidationError("Введите логин")
        User.username_validator(username)
        queryset = User.objects.exclude(pk=self.instance.pk).filter(username__iexact=username)
        if queryset.exists():
            raise forms.ValidationError("Этот логин уже занят")
        return username

    def clean_email(self):
        email = normalize_email(self.cleaned_data["email"])
        queryset = User.objects.exclude(pk=self.instance.pk).filter(email__iexact=email)
        if queryset.exists():
            raise forms.ValidationError("Аккаунт с таким email уже существует")
        return email

    def clean_display_name(self):
        return clean_plain_text(
            self.cleaned_data.get("display_name"),
            max_length=120,
            field_label="Имя",
        )

    def clean_status_text(self):
        return clean_plain_text(
            self.cleaned_data.get("status_text"),
            max_length=120,
            field_label="Статус",
        )

    def clean_bio(self):
        return clean_plain_text(
            self.cleaned_data.get("bio"),
            max_length=PROFILE_BIO_MAX_LENGTH,
            field_label="Описание",
            allow_newlines=True,
        )

    def clean_city(self):
        return clean_plain_text(
            self.cleaned_data.get("city"),
            max_length=120,
            field_label="Город",
        )

    def clean_telegram_url(self):
        return normalize_social_url(self.cleaned_data.get("telegram_url"), "telegram_url")

    def clean_vk_url(self):
        return normalize_social_url(self.cleaned_data.get("vk_url"), "vk_url")

    def clean_instagram_url(self):
        return normalize_social_url(self.cleaned_data.get("instagram_url"), "instagram_url")

    def clean_max_url(self):
        return normalize_social_url(self.cleaned_data.get("max_url"), "max_url")

    def clean_avatar_position_x(self):
        return clean_avatar_position(self.cleaned_data.get("avatar_position_x"))

    def clean_avatar_position_y(self):
        return clean_avatar_position(self.cleaned_data.get("avatar_position_y"))

    def clean_avatar_scale(self):
        return clean_avatar_scale(self.cleaned_data.get("avatar_scale"))

    def clean_avatar_file(self):
        upload = self.cleaned_data.get("avatar_file")
        if upload:
            validate_upload_size(upload, max_bytes=AVATAR_MAX_BYTES, label="Аватар")
        return upload


class ProfilePasswordChangeForm(forms.Form):
    current_password = forms.CharField(
        label="Текущий пароль",
        widget=forms.PasswordInput,
    )
    new_password = forms.CharField(
        label="Новый пароль",
        widget=forms.PasswordInput,
        min_length=8,
    )
    new_password_confirmation = forms.CharField(
        label="Повтор нового пароля",
        widget=forms.PasswordInput,
        min_length=8,
    )

    def __init__(self, *args, user: User, **kwargs):
        super().__init__(*args, **kwargs)
        self.user = user

    def clean(self):
        cleaned_data = super().clean()
        current_password = cleaned_data.get("current_password")
        new_password = cleaned_data.get("new_password")
        confirmation = cleaned_data.get("new_password_confirmation")

        if current_password and not self.user.check_password(current_password):
            self.add_error("current_password", "Неверный текущий пароль")
        if new_password and confirmation and new_password != confirmation:
            self.add_error("new_password_confirmation", "Пароли не совпадают")
        if current_password and new_password and current_password == new_password:
            self.add_error("new_password", "Новый пароль должен отличаться от текущего")
        if new_password:
            try:
                validate_password(new_password, user=self.user)
            except forms.ValidationError as error:
                self.add_error("new_password", error)
        return cleaned_data


class PostEditorForm(forms.Form):
    title = forms.CharField(label="Заголовок", max_length=160, required=False)
    body = forms.CharField(
        label="Текст",
        widget=forms.Textarea(attrs={"rows": 8}),
        max_length=10000,
    )
    kind = forms.ChoiceField(label="Тип", choices=Post.Kind.choices)
    is_published = forms.BooleanField(label="Опубликовать сразу", required=False, initial=True)
    event_starts_at = forms.DateTimeField(
        label="Начало события",
        required=False,
        input_formats=["%Y-%m-%dT%H:%M"],
        widget=forms.DateTimeInput(attrs={"type": "datetime-local"}),
    )
    event_ends_at = forms.DateTimeField(
        label="Окончание события",
        required=False,
        input_formats=["%Y-%m-%dT%H:%M"],
        widget=forms.DateTimeInput(attrs={"type": "datetime-local"}),
    )
    event_location = forms.CharField(label="Место события", max_length=200, required=False)
    image_files = MultipleFileField(label="Фотографии", required=False)
    clear_images = forms.BooleanField(label="Удалить текущие фотографии", required=False)

    def clean(self):
        cleaned_data = super().clean()
        kind = cleaned_data.get("kind")
        starts_at = cleaned_data.get("event_starts_at")
        ends_at = cleaned_data.get("event_ends_at")

        if kind == Post.Kind.EVENT and not starts_at:
            self.add_error("event_starts_at", "Укажите дату и время события")

        if starts_at and ends_at and ends_at < starts_at:
            self.add_error("event_ends_at", "Окончание не может быть раньше начала")
        return cleaned_data
