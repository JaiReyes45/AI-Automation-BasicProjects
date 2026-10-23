FROM python:3.13-slim
WORKDIR /app
COPY workflow/ /app/workflow/
RUN useradd --uid 10001 --create-home careerflow && mkdir /data && chown careerflow:careerflow /data
USER careerflow
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 CAREERFLOW_BIND=0.0.0.0 CAREERFLOW_DB=/data/workflow.sqlite3
EXPOSE 8765
CMD ["python", "-m", "workflow.service"]
