from django.urls import path
from . import views

urlpatterns = [
    path('create', views.create_publication, name='create_publication'),
    path('tout', views.get_all_publications, name='get_all_publications'),
    path('<int:id>', views.get_publication_by_id, name='get_publication_by_id'),
    path('update/<int:id>', views.update_publication, name='update_publication'),
    path('delete/<int:id>', views.delete_publication, name='delete_publication'),
    path('section/<str:section>', views.get_publications_by_section, name='get_publications_by_section'),
    path('utilisateur/<int:utilisateur_id>', views.get_publications_by_utilisateur, name='get_publications_by_utilisateur'),
    path('delete/all', views.delete_all_publications, name='delete_all_publications'),
    path('images/<str:filename>', views.serve_image, name='serve_image'),
    path('docs/<str:filename>', views.serve_pdf, name='serve_pdf'),
    path('references', views.get_reference_lists, name='get_reference_lists'),
    # Routes pour les favoris
    path('favoris/<int:utilisateur_id>', views.get_favoris, name='get_favoris'),
    path('favoris/add/<int:publication_id>', views.add_favori, name='add_favori'),
    path('favoris/remove/<int:publication_id>', views.remove_favori, name='remove_favori'),
    path('favoris/check/<int:publication_id>', views.check_favori, name='check_favori'),
]

