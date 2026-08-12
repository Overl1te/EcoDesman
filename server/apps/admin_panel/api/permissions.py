from rest_framework.permissions import BasePermission

from apps.users.services import can_administrate


class IsAdminPanelUser(BasePermission):
    message = "Доступ к админке закрыт"

    def has_permission(self, request, view) -> bool:
        return can_administrate(request.user)
