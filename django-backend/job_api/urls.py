"""
URL configuration for job_api project.
"""
from django.conf import settings
from django.conf.urls.static import static
from django.contrib import admin
from django.http import JsonResponse
from django.urls import include, path, re_path
from django.views.static import serve


def health(_request):
    return JsonResponse({'status': 'ok', 'service': 'fasojob-api'})


urlpatterns = [
    path('health/', health),
    path('admin/', admin.site.urls),
    path('api/utilisateurs/', include('utilisateurs.urls')),
    path('api/publications/', include('publications.urls')),
]

# Fichiers média (dev + prod Render — disque éphémère sur l’offre gratuite)
if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
else:
    urlpatterns += [
        re_path(
            r'^media/(?P<path>.*)$',
            serve,
            {'document_root': settings.MEDIA_ROOT},
        ),
    ]
