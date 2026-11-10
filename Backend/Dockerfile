FROM python:3.14.10-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1
WORKDIR /app
COPY requirements.txt requirements-lock.txt ./
RUN pip install -r requirements-lock.txt && useradd --create-home taskflow && mkdir -p /app/private_media && chown taskflow:taskflow /app/private_media
COPY --chown=taskflow:taskflow . .
USER taskflow
EXPOSE 8000
CMD ["sh", "scripts/start-server.sh"]
