# Use an official Python base image
FROM python:3.11-slim

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

ARG PREFERRED_PORT=8000
ENV PREFERRED_PORT=${PREFERRED_PORT}

RUN apt-get update && apt-get install -y --no-install-recommends jq \
 && apt-get clean && rm -rf /var/lib/apt/lists/*

# Set working directory in container
WORKDIR /app

# Copy project files into the container
COPY pyproject.toml .
COPY requirements.txt .
COPY src/ ./

# Install Python dependencies
# RUN uv venv && uv sync 
RUN pip install -r requirements.txt

ENV PATH="/app/.venv/bin:$PATH"

# Expose port (adjust if needed, e.g., 8000 for FastAPI)
EXPOSE ${PREFERRED_PORT}

# Default command (change for Flask or general script)
# CMD [ "fastapi", "dev","main.py", "--host", "0.0.0.0", "--port", "8000"]
CMD fastapi dev main.py --host 0.0.0.0 --port ${PREFERRED_PORT} 