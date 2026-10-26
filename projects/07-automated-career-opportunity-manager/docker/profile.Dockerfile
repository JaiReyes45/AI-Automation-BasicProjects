FROM python:3.13-slim
RUN pip install --no-cache-dir Pillow==12.0.0
WORKDIR /app
COPY profile_service/server.py /app/server.py
CMD ["python", "server.py"]
