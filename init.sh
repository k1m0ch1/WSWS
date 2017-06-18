#!/bin/sh
php-fpm7 -F &  
nginx -g "daemon off;" &