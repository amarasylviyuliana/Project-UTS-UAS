FROM php:8.2-fpm

RUN apt-get update && apt-get install -y \
    zip unzip git curl \
    libpng-dev \
    libonig-dev \
    libxml2-dev

RUN docker-php-ext-install pdo pdo_mysql

COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

WORKDIR /var/www

COPY . .

RUN composer install

CMD ["php-fpm"]