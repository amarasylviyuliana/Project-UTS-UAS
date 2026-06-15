# Build stage for Flutter web
FROM debian:latest AS builder

# Install dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Install Flutter
RUN git clone https://github.com/flutter/flutter.git /flutter
ENV PATH="/flutter/bin:${PATH}"

# Accept licenses
RUN flutter config --no-analytics && flutter precache

# Copy project files
WORKDIR /app
COPY . .

# Get dependencies
RUN flutter pub get

# Build web
RUN flutter build web --release

# Nginx stage for serving
FROM nginx:latest

# Copy built files to nginx
COPY --from=builder /app/build/web /usr/share/nginx/html

# Copy nginx config
RUN echo 'server { listen 3000; root /usr/share/nginx/html; index index.html; location / { try_files $uri $uri/ /index.html; } }' > /etc/nginx/conf.d/default.conf

EXPOSE 3000

CMD ["nginx", "-g", "daemon off;"]
