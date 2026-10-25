FROM python:3.13-slim
RUN pip install --no-cache-dir 'psycopg[binary]==3.2.13'
WORKDIR /app
COPY crm/ /app/crm/
COPY workflow/ /app/workflow/
COPY database/ /app/database/
CMD ["python", "-m", "crm.server"]
