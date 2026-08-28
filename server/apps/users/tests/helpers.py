from rest_framework_simplejwt.tokens import RefreshToken

from apps.users.services import get_user_by_identifier


def access_token_for(identifier: str) -> str:
    user = get_user_by_identifier(identifier)
    if user is None:
        raise AssertionError(f"Пользователь не найден: {identifier}")
    return str(RefreshToken.for_user(user).access_token)
