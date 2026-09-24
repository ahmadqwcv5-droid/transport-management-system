FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY . .
RUN dotnet restore src/TransportManagement.Api/TransportManagement.Api.csproj
RUN dotnet publish src/TransportManagement.Api/TransportManagement.Api.csproj -c Release -o /app --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && mkdir -p /data/truck-photos \
    && chown "$APP_UID:$APP_UID" /data/truck-photos \
    && rm -rf /var/lib/apt/lists/*
COPY --from=build /app .
USER $APP_UID
EXPOSE 8080
ENTRYPOINT ["dotnet", "TransportManagement.Api.dll"]
