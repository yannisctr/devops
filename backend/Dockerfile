FROM php:8.4-apache
RUN docker-php-ext-install pdo_mysql
COPY --chmod=0644 api/index.php /var/www/html/api/index.php
RUN chmod 0755 /var/www/html/api
COPY --chmod=0644 router.conf /etc/apache2/conf-enabled/todo.conf
