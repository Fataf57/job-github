FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app/django-backend

RUN apt-get update \
    && apt-get install -y --no-install-recommends libpq-dev gcc \
    && rm -rf /var/lib/apt/lists/*

COPY django-backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY django-backend/ .

RUN python manage.py collectstatic --no-input

EXPOSE 8080

CMD ["bash", "start.sh"]
