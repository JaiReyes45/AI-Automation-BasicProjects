FROM python:3.13-slim
WORKDIR /app
COPY profile_service/server.py /app/server.py
CMD ["python", "server.py"]
