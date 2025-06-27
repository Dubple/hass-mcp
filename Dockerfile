# Use the same base image as your original server, which already includes uv
FROM ghcr.io/astral-sh/uv:0.6.6-python3.13-bookworm

# Set working directory
WORKDIR /app

# Copy project files
COPY . .

# Set environment for MCP communication (kept from your original)
ENV PYTHONUNBUFFERED=1
ENV PYTHONPATH=/app

# Install your stdio MCP server (kept from your original)
RUN uv pip install --system -e .

# Install mcp-proxy using uv tool install
# This will install mcp-proxy into uv's managed tool directory,
# which is typically already in the PATH for this base image.
RUN uv tool install mcp-proxy

# Fix for not finding mcp-proxy
ENV PATH="/root/.local/bin:${PATH}"

# EXPOSE the port that mcp-proxy will listen on for SSE connections
# You can choose any available port, 8080 is common.
EXPOSE 8080

# Set the ENTRYPOINT to mcp-proxy
# The mcp-proxy will now be the main process running in the container.
ENTRYPOINT ["mcp-proxy"]

# Define the default command for mcp-proxy
# This tells mcp-proxy to run in "SSE to stdio" mode.
# --host 0.0.0.0 makes the SSE server accessible from outside the container.
# --port 8080 is the port mcp-proxy will listen on.
# The -- separator is CRUCIAL: it tells mcp-proxy that all subsequent arguments
# belong to the stdio server it needs to spawn.
# "python", "-m", "app" is the command to run your original stdio server.
CMD ["--host", "0.0.0.0", "--port", "8080", "--", "python", "-m", "app"]
