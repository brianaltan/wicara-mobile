FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .

ARG WICARA_API_BASE_URL=http://127.0.0.1:8000
ARG WICARA_GOOGLE_WEB_CLIENT_ID=

RUN flutter build web --release \
    --dart-define=WICARA_API_BASE_URL="${WICARA_API_BASE_URL}" \
    --dart-define=WICARA_GOOGLE_WEB_CLIENT_ID="${WICARA_GOOGLE_WEB_CLIENT_ID}"

FROM nginx:1.27-alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80
