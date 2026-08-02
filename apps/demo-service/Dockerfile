# Stage 1: Build dependencies
FROM python:3.12-slim AS builder

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# Stage 2: Final minimal runtime image
FROM python:3.12-slim

# Create a non-root user - never run containers as root in production
RUN useradd -m -u 10001 appuser

WORKDIR /app

# Copy installed packages from the builder stage
COPY --from=builder /root/.local /home/appuser/.local
COPY app.py .

# Make sure the appuser owns everything, and can find pip-installed packages
ENV PATH=/home/appuser/.local/bin:$PATH
RUN chown -R appuser:appuser /app

USER appuser

EXPOSE 5050

CMD ["python3", "app.py"]
