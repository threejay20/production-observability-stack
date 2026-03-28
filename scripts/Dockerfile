FROM python:3.12-slim

WORKDIR /app

# Install dependencies at build time, not at runtime
RUN pip install --no-cache-dir flask prometheus-client requests

COPY demo_app.py .

EXPOSE 8080

CMD ["python", "demo_app.py"]
