# Build stage for Flutter web
FROM debian:latest AS builder

# Install dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Install Flutter
RUN git clone --depth 1 -b stable https://github.com/flutter/flutter.git /flutter
ENV PATH="/flutter/bin:${PATH}"

# Accept licenses
RUN flutter config --no-analytics && flutter precache

# Copy project files
WORKDIR /app
COPY . .

# Get dependencies
RUN flutter pub get

# Build web
ARG API_URL 
RUN flutter build web --release --dart-define=API_URL=${API_URL}

# Nginx stage for serving
FROM nginx:latest

# Copy built files to nginx
COPY --from=builder /app/build/web /usr/share/nginx/html

# Copy nginx config - setup untuk akses dari mobile/HP
RUN cat > /etc/nginx/conf.d/default.conf <<'EOF'
server {
    listen 3000;
    listen [::]:3000;
    server_name _;
    
    root /usr/share/nginx/html;
    index index.html;

    # CORS headers untuk mobile access
    add_header Access-Control-Allow-Origin "*" always;
    add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS" always;
    add_header Access-Control-Allow-Headers "Origin, Content-Type, Accept, Authorization" always;

    # Caching policy
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Flutter web app routing
    location / {
        try_files $uri $uri/ /index.html;
        add_header Cache-Control "no-cache, no-store, must-revalidate";
    }

    # Handle OPTIONS requests
    if ($request_method = OPTIONS) {
        return 204;
    }
}
EOF

EXPOSE 3000

CMD ["nginx", "-g", "daemon off;"]