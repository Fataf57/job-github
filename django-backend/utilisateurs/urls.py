from django.urls import path
from . import views

urlpatterns = [
    path('create', views.create_utilisateur, name='create_utilisateur'),
    path('login', views.login, name='login'),
    path('verify-email', views.verify_email, name='verify_email'),
    path('resend-verification', views.resend_verification, name='resend_verification'),
    path('', views.get_all_utilisateurs, name='get_all_utilisateurs'),
    path('<int:id>', views.get_utilisateur_by_id, name='get_utilisateur_by_id'),
]

