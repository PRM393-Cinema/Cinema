# Build context: thư mục Cinema_BE (xem docker-compose.yml)
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Restore riêng để Docker cache package, chỉ sửa code thì không phải tải lại
COPY ApiGateway/ApiGateway/ApiGateway.csproj ApiGateway/ApiGateway/
RUN dotnet restore ApiGateway/ApiGateway/ApiGateway.csproj

COPY ApiGateway/ApiGateway/ ApiGateway/ApiGateway/
RUN dotnet publish ApiGateway/ApiGateway/ApiGateway.csproj -c Release -o /app/publish --no-restore /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS final
WORKDIR /app
COPY --from=build /app/publish .
USER $APP_UID
EXPOSE 8080
ENTRYPOINT ["dotnet", "ApiGateway.dll"]
