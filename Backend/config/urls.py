from django.urls import include, path
from rest_framework.routers import DefaultRouter
from core import auth_views, views
from core.google_auth import GoogleLoginView, GoogleLinkView
from core.task_views import TaskViewSet
from core.list_views import TaskListViewSet, InvitationViewSet
from core.attachment_views import AttachmentViewSet
from core.group_views import TaskGroupViewSet, GroupInvitationViewSet, NotificationViewSet
from core.billing import BillingAccessView

router = DefaultRouter()
router.register("tasks", TaskViewSet, basename="task")
router.register("lists", TaskListViewSet, basename="task-list")
router.register("invitations", InvitationViewSet, basename="invitation")
router.register("attachments", AttachmentViewSet, basename="attachment")
router.register("groups", TaskGroupViewSet, basename="group")
router.register("group-invitations", GroupInvitationViewSet, basename="group-invitation")
router.register("notifications", NotificationViewSet, basename="notification")
urlpatterns = [
    path("", views.playground), path("reset-password/", views.reset_page),
    path("invite/", views.invitation_page),
    path("download/", views.invitation_page, {"download": True}),
    path("api/health/", views.health),
    path("api/live/", views.live),
    path("api/billing/access/", BillingAccessView.as_view()),
    path("api/auth/register/", auth_views.RegisterView.as_view()),
    path("api/auth/login/", auth_views.LoginView.as_view()),
    path("api/auth/google/", GoogleLoginView.as_view()),
    path("api/auth/google/link/", GoogleLinkView.as_view()),
    path("api/auth/refresh/", auth_views.RefreshView.as_view()),
    path("api/auth/logout/", auth_views.LogoutView.as_view()),
    path("api/auth/me/", auth_views.MeView.as_view()),
    path("api/auth/password-reset/", auth_views.ResetRequestView.as_view()),
    path("api/auth/password-reset/confirm/", auth_views.ResetConfirmView.as_view()),
    path("api/ai/draft/", views.DraftView.as_view()),
    path("api/ai/drafts/", views.DraftBatchView.as_view()),
    path("api/", include(router.urls)),
]
