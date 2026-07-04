FROM php:8.2-fpm

RUN apt-get update && apt-get install -y \
    git curl nginx supervisor \
    libpng-dev libjpeg-dev libfreetype6-dev libonig-dev libxml2-dev \
    zip unzip \
    && rm -rf /var/lib/apt/lists/*

RUN docker-php-ext-configure gd --with-freetype --with-jpeg
RUN docker-php-ext-install -j$(nproc) gd pdo_mysql mbstring exif pcntl bcmath xml

COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

WORKDIR /app

COPY composer.json composer.lock* ./
RUN composer install --no-scripts --no-autoloader --no-dev --optimize-autoloader

COPY . .
RUN composer dump-autoload --optimize

COPY docker/nginx/nginx.conf /etc/nginx/sites-enabled/default
COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

RUN chown -R www-data:www-data /app

EXPOSE 8000
CMD ["docker-entrypoint.sh"]