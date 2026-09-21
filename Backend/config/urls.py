from django.urls import include, path
from rest_framework.routers import DefaultRouter
from core import auth_views, views
from core.task_views import TaskViewSet

router = DefaultRouter()
router.register("tasks", TaskViewSet, basename="task")
urlpatterns = [
    path("", views.playground), path("reset-password/", views.reset_page),
    path("api/health/", views.health),
    path("api/auth/register/", auth_views.RegisterView.as_view()),
    path("api/auth/login/", auth_views.LoginView.as_view()),
    path("api/auth/refresh/", auth_views.RefreshView.as_view()),
    path("api/auth/logout/", auth_views.LogoutView.as_view()),
    path("api/auth/me/", auth_views.MeView.as_view()),
    path("api/auth/password-reset/", auth_views.ResetRequestView.as_view()),
    path("api/auth/password-reset/confirm/", auth_views.ResetConfirmView.as_view()),
    path("api/ai/draft/", views.DraftView.as_view()),
    path("api/ai/drafts/", views.DraftBatchView.as_view()),
    path("api/", include(router.urls)),
]
