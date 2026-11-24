FROM python:3.11-slim-bookworm
RUN useradd --create-home --uid 10001 mlflow
RUN pip install --no-cache-dir 'mlflow[genai]==3.18.0' psycopg2-binary boto3
COPY docker/ai-gateway/entrypoint.sh /entrypoint.sh
RUN chmod 0755 /entrypoint.sh
USER 10001
EXPOSE 5000
ENTRYPOINT ["/entrypoint.sh"]
