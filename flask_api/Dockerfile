# Use an official Python base image
FROM python:3.11-slim

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

RUN apt-get update && apt-get install -y --no-install-recommends jq \
 && apt-get clean && rm -rf /var/lib/apt/lists/*

# Set working directory in container
WORKDIR /app

# Copy project files into the container
COPY pyproject.toml .
COPY main.py .

# Install Python dependencies
RUN uv venv && uv sync 

ENV PATH="/app/.venv/bin:$PATH"

# Expose port (adjust if needed, e.g., 8000 for FastAPI)
EXPOSE 5000

# Default command (change for Flask or general script)
CMD [ "python","main.py", "--host", "0.0.0.0", "--port", "5000"]
