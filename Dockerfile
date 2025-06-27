# Stage 1: Base image with Node.js (for mcp-proxy)
# We start with a Node.js image as it will be the primary process (the proxy)
FROM node:20-bookworm

# Set working directory for the overall application
WORKDIR /app

# --- Install Python and its dependencies ---
# Install Python3, pip, and other necessary build tools if your Python app needs them
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    # Add any other Python runtime dependencies if your server needs them, e.g., build-essential, git
    && rm -rf /var/lib/apt/lists/*

# Install uv, as your original Dockerfile used it
RUN wget -qO- https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:${PATH}"

# --- Install Python with uv ---
# Specify the desired Python version (e.g., 3.13)
ARG PYTHON_VERSION=3.13
RUN uv python install ${PYTHON_VERSION}

# Ensure the uv-managed Python is used by setting the PATH
# uv installs Python to ~/.cache/uv/python/cpython-<version>-<platform>/bin
ENV PATH="/root/.cache/uv/python/cpython-${PYTHON_VERSION}-linux-x86_64/bin:${PATH}"

# --- Copy and set up your Python MCP server ---
# Create a specific subdirectory for your Python server code
WORKDIR /app/python_server
COPY . .

# Set environment for MCP communication for the Python server
# PYTHONUNBUFFERED is CRUCIAL for stdio communication to work correctly
ENV PYTHONUNBUFFERED=1
ENV PYTHONPATH=/app/python_server

# Annoying pip prompt, this is a docker container stupid
RUN mv "/usr/lib/python${PYTHON_VERSION}/EXTERNALLY-MANAGED" "/usr/lib/python${PYTHON_VERSION}/EXTERNALLY-MANAGED.old"

# Install your Python package with UV
RUN uv pip install --system -e .

# --- Install mcp-proxy ---
# Change back to the main app directory for mcp-proxy installation
WORKDIR /app

# Install mcp-proxy globally using npm
RUN npm install -g mcp-proxy

# --- Configure and Run the Proxy ---
# Expose the port mcp-proxy will listen on (default is 8080)
EXPOSE 8080

# Command to run mcp-proxy, which then spawns your Python MCP server
# npx mcp-proxy: Executes the proxy.
# --port 8080: Sets the port the proxy listens on.
# --shell "python3 -m app": This is the key part. It tells mcp-proxy to execute
#                            "python3 -m app" (your Python MCP server's entrypoint)
#                            and communicate with it over standard I/O (stdio).
ENTRYPOINT ["npx", "mcp-proxy", "--port", "8080", "--shell", "python3 -m app"]

# You can add --debug to the ENTRYPOINT for more verbose logging during development:
# ENTRYPOINT ["npx", "mcp-proxy", "--port", "8080", "--debug", "--shell", "python3 -m app"]
