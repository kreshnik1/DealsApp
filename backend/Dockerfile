FROM mcr.microsoft.com/playwright/python:v1.50.0-jammy

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt \
    && playwright install chromium

COPY alembic.ini .
COPY alembic ./alembic
COPY entrypoint.sh .
COPY app ./app

EXPOSE 8000

CMD ["sh", "/app/entrypoint.sh"]
