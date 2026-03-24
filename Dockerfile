# Build stage
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# DevExpress License Configuration
# Hybrid approach: Use local file if available (dev), otherwise use build ARG (Dokploy)
ARG DevExpress_License

# Copy license directory (may only contain .dockerkeep in Dokploy, that's OK)
COPY .devexpress-license /tmp/local-license

# Copy and run configuration script
COPY docker/build/configure-license.sh /tmp/configure-license.sh
RUN chmod +x /tmp/configure-license.sh && \
    /tmp/configure-license.sh && \
    rm -rf /tmp/configure-license.sh /tmp/local-license

# Copy solution and project files
COPY ["XAFDocker.sln", "./"]
COPY ["XAFDocker.Blazor.Server/XAFDocker.Blazor.Server.csproj", "XAFDocker.Blazor.Server/"]
COPY ["XAFDocker.Module/XAFDocker.Module.csproj", "XAFDocker.Module/"]

# Restore dependencies
RUN dotnet restore "XAFDocker.sln"

# Copy all source files
COPY . .

# Build the application
WORKDIR "/src/XAFDocker.Blazor.Server"
RUN dotnet build "XAFDocker.Blazor.Server.csproj" -c Release -o /app/build

# Publish stage
FROM build AS publish
RUN dotnet publish "XAFDocker.Blazor.Server.csproj" -c Release -o /app/publish /p:UseAppHost=false

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS final
WORKDIR /app

# Install curl for health checks and SkiaSharp dependencies
RUN apt-get update && apt-get install -y \
    curl \
    libfontconfig1 \
    libfreetype6 \
    libx11-6 \
    libxcb1 \
    libxrender1 \
    libice6 \
    libsm6 \
    && rm -rf /var/lib/apt/lists/*

# Copy published application
COPY --from=publish /app/publish .

# Copy entrypoint script
COPY docker/app/entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Set environment variables
ENV ASPNETCORE_URLS=http://+:80
ENV ASPNETCORE_ENVIRONMENT=Development

# Expose port
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD curl -f http://localhost/health || exit 1

ENTRYPOINT ["/app/entrypoint.sh"]
