FROM alpine:3.6
MAINTAINER Yahya Fadhlulloh Al Fatih <yahya.kimochi@gmail.com>

# Nginx Version (See: https://nginx.org/en/CHANGES)
ENV NGXVERSION 1.13.0
ENV NGXSIGKEY B0F4253373F8F6F510D42178520A9993A1C052F8

# PageSpeed Version (See: https://modpagespeed.com/doc/release_notes)
ENV PSPDVER latest-beta

# Build as root (we drop privileges later when actually running the container)
USER root
WORKDIR /root

# Add 'nginx' user
RUN adduser nginx -S -u 666  -h /usr/share/nginx -H

RUN adduser -D phpfpm

# Update & install deps
RUN apk --no-cache --update add \
      ca-certificates \
      cmake \
      g++ \
      gcc \
      geoip-dev \
      git \
      go \
      gnupg \
      icu \
      icu-libs \
      make \
      linux-headers \
      patch \
      pcre-dev \
      perl \
      tar \
      unzip \
      wget \
      zlib-dev \
      gzip \
      nano \
      htop \
      zsh \
      curl \
      apr-util \
      libuuid \
      libjpeg-turbo \
      openssl

RUN set -x && \
    apk --no-cache add -t .build-deps \
        apache2-dev \
        apr-dev \
        apr-util-dev \
        build-base \
        icu-dev \
        libjpeg-turbo-dev \
        linux-headers \
        gperf \
        pcre-dev \
        python 
#build psol
RUN wget http://ftp.gnu.org/gnu/binutils/binutils-2.25.tar.gz && \
    tar xvf binutils-2.25.tar.gz && \
    cd binutils-2.25 && \
    ./configure && \
    make && \
    make install

RUN mkdir -p ~/bin && \
    cd ~/bin && \
    git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git && \
    export PATH=$PATH:~/bin/depot_tools && \
    mkdir ~/mod_pagespeed && \
    cd ~/mod_pagespeed && \
    git clone https://github.com/pagespeed/mod_pagespeed.git src && \
    python ~/bin/depot_tools/gclient.py config https://github.com/pagespeed/mod_pagespeed.git --unmanaged --name=src && \
    cd src/ && \
    git checkout ${BRANCH} && \
    cd .. && \
    python ~/bin/depot_tools/gclient.py sync --force --jobs=1 # add --revision=xxxx for a specific git revision && \
    make AR.host="$PWD/build/wrappers/ar.sh" \
       AR.target="$PWD/build/wrappers/ar.sh" \
       BUILDTYPE=Release \
       mod_pagespeed_test pagespeed_automatic_test && \
    cd ~/mod_pagespeed/src/pagespeed/automatic && \
    make BUILDTYPE=Release \
       -C ../../pagespeed/automatic \
       AR.host="$PWD/../../build/wrappers/ar.sh" \
       AR.target="$PWD/../../build/wrappers/ar.sh" \
       all

RUN LIBPNG_VERSION=1.2.56 && \
    cd /tmp && \
    curl -L http://prdownloads.sourceforge.net/libpng/libpng-${LIBPNG_VERSION}.tar.gz | tar -zx && \
    cd /tmp/libpng-${LIBPNG_VERSION} && \
    ./configure --build=$CBUILD --host=$CHOST --prefix=/usr --enable-shared --with-libpng-compat && \
    make install V=0 && \
    # Build PageSpeed:
    # Check https://github.com/pagespeed/ngx_pagespeed/releases for the latest version
    PAGESPEED_VERSION=1.11.33.3 && \
    cd /tmp && \
    curl -L https://dl.google.com/dl/linux/mod-pagespeed/tar/beta/mod-pagespeed-beta-${PAGESPEED_VERSION}-r0.tar.bz2 | tar -jx && \
    curl -L https://github.com/pagespeed/ngx_pagespeed/archive/v${PAGESPEED_VERSION}-beta.tar.gz | tar -zx && \
    cd /tmp/modpagespeed-${PAGESPEED_VERSION} && \
    curl -L https://raw.githubusercontent.com/iler/alpine-nginx-pagespeed/master/patches/automatic_makefile.patch | patch -p1 && \
    curl -L https://raw.githubusercontent.com/iler/alpine-nginx-pagespeed/master/patches/libpng_cflags.patch | patch -p1 && \
    curl -L https://raw.githubusercontent.com/iler/alpine-nginx-pagespeed/master/patches/pthread_nonrecursive_np.patch | patch -p1 && \
    curl -L https://raw.githubusercontent.com/iler/alpine-nginx-pagespeed/master/patches/rename_c_symbols.patch | patch -p1 && \
    curl -L https://raw.githubusercontent.com/iler/alpine-nginx-pagespeed/master/patches/stack_trace_posix.patch | patch -p1 && \
    ./generate.sh -D use_system_libs=1 -D _GLIBCXX_USE_CXX11_ABI=0 -D use_system_icu=1 && \
    cd /tmp/modpagespeed-${PAGESPEED_VERSION}/src && \
    make BUILDTYPE=Release CXXFLAGS=" -I/usr/include/apr-1 -I/tmp/libpng-${LIBPNG_VERSION} -fPIC -D_GLIBCXX_USE_CXX11_ABI=0" CFLAGS=" -I/usr/include/apr-1 -I/tmp/libpng-${LIBPNG_VERSION} -fPIC -D_GLIBCXX_USE_CXX11_ABI=0" && \
    cd /tmp/modpagespeed-${PAGESPEED_VERSION}/src/pagespeed/automatic/ && \
    make psol BUILDTYPE=Release CXXFLAGS=" -I/usr/include/apr-1 -I/tmp/libpng-${LIBPNG_VERSION} -fPIC -D_GLIBCXX_USE_CXX11_ABI=0" CFLAGS=" -I/usr/include/apr-1 -I/tmp/libpng-${LIBPNG_VERSION} -fPIC -D_GLIBCXX_USE_CXX11_ABI=0" && \
    mkdir -p /tmp/ngx_pagespeed-${PAGESPEED_VERSION}-beta/psol && \
    mkdir -p /tmp/ngx_pagespeed-${PAGESPEED_VERSION}-beta/psol/lib/Release/linux/x64 && \
    mkdir -p /tmp/ngx_pagespeed-${PAGESPEED_VERSION}-beta/psol/include/out/Release && \
    cp -r /tmp/modpagespeed-${PAGESPEED_VERSION}/src/out/Release/obj /tmp/ngx_pagespeed-${PAGESPEED_VERSION}-beta/psol/include/out/Release/ && \
    cp -r /tmp/modpagespeed-${PAGESPEED_VERSION}/src/net /tmp/ngx_pagespeed-${PAGESPEED_VERSION}-beta/psol/include/ && \
    cp -r /tmp/modpagespeed-${PAGESPEED_VERSION}/src/testing /tmp/ngx_pagespeed-${PAGESPEED_VERSION}-beta/psol/include/ && \
    cp -r /tmp/modpagespeed-${PAGESPEED_VERSION}/src/pagespeed /tmp/ngx_pagespeed-${PAGESPEED_VERSION}-beta/psol/include/ && \
    cp -r /tmp/modpagespeed-${PAGESPEED_VERSION}/src/third_party /tmp/ngx_pagespeed-${PAGESPEED_VERSION}-beta/psol/include/ && \
    cp -r /tmp/modpagespeed-${PAGESPEED_VERSION}/src/tools /tmp/ngx_pagespeed-${PAGESPEED_VERSION}-beta/psol/include/ && \
    cp -r /tmp/modpagespeed-${PAGESPEED_VERSION}/src/pagespeed/automatic/pagespeed_automatic.a /tmp/ngx_pagespeed-${PAGESPEED_VERSION}-beta/psol/lib/Release/linux/x64 && \
    # Build Nginx with support for PageSpeed:
    # Check http://nginx.org/en/download.html for the latest version.
    NGINX_VERSION=1.11.13 && \
    cd /tmp && \
    curl -L http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz | tar -zx && \
    cd /tmp/nginx-${NGINX_VERSION} && \
    LD_LIBRARY_PATH=/tmp/modpagespeed-${PAGESPEED_VERSION}/usr/lib ./configure --with-ipv6 \
        --prefix=/var/lib/nginx \
        --sbin-path=/usr/sbin \
        --modules-path=/usr/lib/nginx \
        --with-http_ssl_module \
        --with-http_gzip_static_module \
        --with-file-aio \
        --with-http_v2_module \
        --without-http_autoindex_module \
        --without-http_browser_module \
        --without-http_geo_module \
        --without-http_map_module \
        --without-http_memcached_module \
        --without-http_userid_module \
        --without-mail_pop3_module \
        --without-mail_imap_module \
        --without-mail_smtp_module \
        --without-http_split_clients_module \
        --without-http_scgi_module \
        --without-http_referer_module \
        --without-http_upstream_ip_hash_module \
        --prefix=/etc/nginx \
        --conf-path=/etc/nginx/nginx.conf \
        --http-log-path=/var/log/nginx/access.log \
        --error-log-path=/var/log/nginx/error.log \
        --pid-path=/var/run/nginx.pid \
        --add-module=/tmp/ngx_pagespeed-${PAGESPEED_VERSION}-beta \
        --with-cc-opt="-fPIC -I /usr/include/apr-1" \
        --with-ld-opt="-luuid -lapr-1 -laprutil-1 -licudata -licuuc -L/tmp/modpagespeed-${PAGESPEED_VERSION}/usr/lib -lpng12 -lturbojpeg -ljpeg" && \
    make install --silent && \
    # Clean-up:
    cd && \
    apk del .build-deps && \
    rm -rf /tmp/* && \
    # forward request and error logs to docker log collector
    ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log && \
    # Make PageSpeed cache writabl:
    mkdir -p /var/cache/ngx_pagespeed && \
    chmod -R o+wr /var/cache/ngx_pagespeed
      
# Copy nginx source into container
COPY src/nginx-$NGXVERSION.tar.gz nginx-$NGXVERSION.tar.gz
COPY src/nginx.patch nginx.patch

# Import nginx team signing keys to verify the source code tarball (Cannot use HKPS yet with Alpine's version of gnupg)
RUN gpg --keyserver hkp://keyserver.ubuntu.com --recv-keys $NGXSIGKEY

# Verify this source has been signed with a valid nginx team key
RUN wget "https://nginx.org/download/nginx-$NGXVERSION.tar.gz.asc" && \
    out=$(gpg --status-fd 1 --verify "nginx-$NGXVERSION.tar.gz.asc" 2>/dev/null) && \
    if echo "$out" | grep -qs "\[GNUPG:\] GOODSIG" && echo "$out" | grep -qs "\[GNUPG:\] VALIDSIG"; then echo "Good signature on nginx source file."; else echo "GPG VERIFICATION OF SOURCE CODE FAILED!" && echo "EXITING!" && exit 100; fi

# Download PageSpeed & PageSpeed Optimization Library (PSOL)
##
## On Alpine we cannot just grab these prebuilt binaries as they expect us to be
## running a system with glibc, so I have temporarily disabled the PageSpeed module for now.
## To re-enable, make sure to re-add the following line:
##     --add-module="$HOME/ngx_pagespeed-$PSPDVER" \
## to the nginx configure arguments. Some patching will also be required.)
##
RUN echo "Downloading PageSpeed..." && wget -O - https://github.com/pagespeed/ngx_pagespeed/archive/$PSPDVER.tar.gz | tar -xz && \
    cd ngx_pagespeed-$PSPDVER/ && \
    echo "Downloading PSOL..." && \
    PSOLVER=$(basename $(cat PSOL_BINARY_URL) | cut -d"-" -f1) && \
    wget -O - https://dl.google.com/dl/page-speed/psol/$PSOLVER-x64.tar.gz | tar -xz


# Download additional modules
RUN git clone https://github.com/openresty/headers-more-nginx-module.git "$HOME/ngx_headers_more" && \
    git clone https://github.com/simpl/ngx_devel_kit.git "$HOME/ngx_devel_kit" && \
    git clone https://github.com/yaoweibin/ngx_http_substitutions_filter_module.git "$HOME/ngx_subs_filter" && \
    git clone https://github.com/vozlt/nginx-module-vts.git "$HOME/nginx-module-vts" && \
    git clone https://github.com/nbs-system/naxsi.git "$HOME/nginx-naxsi" && \
    git clone https://github.com/tmthrgd/nginx-ip-blocker.git "$HOME/nginx-ip-blocker" && \
    git clone https://github.com/masterzen/nginx-upload-progress-module.git "$HOME/nginx-upload"

# Prepare nginx source
RUN tar -xzvf nginx-$NGXVERSION.tar.gz && \
    rm -v nginx-$NGXVERSION.tar.gz

RUN rm /root/nginx-$NGXVERSION/src/http/ngx_http_header_filter_module.c

COPY src/ngx_http_header_filter_module.c /root/nginx-$NGXVERSION/src/http/

# Switch directory
WORKDIR "/root/nginx-$NGXVERSION/"

# Configure Nginx
##
## Config options mostly stolen from the Red Hat package of nginx for Fedora 25.
## cc-opt tweaked to use -fstack-protector-all, and -fPIE added to build position-independent.
## Removed any of the modules that the Fedora team was building with "=dynamic" as they stop us being able
## to build with -fPIE and require the less-hardened -fPIC option instead. (https://gcc.gnu.org/onlinedocs/gcc/Code-Gen-Options.html)
##
## Also removed the --with-debug flag (I don't need debug-level logging) and --with-ipv6 as the flag is now deprecated.
## Removed all the mail modules as I have no intention of using this as a mailserver proxy.
## The final tweaks are my --add-module lines at the bottom, and the --with-openssl
## argument, to point the build to the OpenSSL Beta we downloaded earlier.
##
## The Google PerfTools module has also been removed because the package is not available in Alpine:
##     --with-google_perftools_module \
## Re-add with the above line if the package becomes available, or you build it manually.
##


# Build Nginx
RUN patch -p1 < "$HOME/nginx.patch" && \
    make && \
    make install

# Make sure the permissions are set correctly on our webroot, logdir and pidfile so that we can run the webserver as non-root.
RUN chown -R nginx /usr/share/nginx && \
    chown -R nginx /var/log/nginx && \
    mkdir -p /var/lib/nginx/tmp && \
    chown -R nginx /var/lib/nginx && \
    touch /var/run/nginx.pid && \
    chown nginx /var/run/nginx.pid

# Configure nginx to listen on 8080 instead of 80 (we can't bind to <1024 as non-root)
RUN perl -pi -e 's,80;,8080;,' /etc/nginx/nginx.conf

# Remove some packages (Doesn't save space because of container's CoW design, but might add a bit of security)
RUN apk del \
      cmake \
      g++ \
      gcc \
      go \
      make

# Clean-up
RUN rm -rf /tmp/* && \
    # Forward request and error logs to docker log collector
    ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log && \
    # Make PageSpeed cache writable
    mkdir -p /var/cache/ngx_pagespeed /var/log/pagespeed && \
    chmod -R 777 /var/cache/ngx_pagespeed && chmod -R 777 /var/log/pagespeed \
    && rm -rf /etc/nginx/html/ \
    && mkdir -p /usr/share/nginx/html/ 

RUN apk --no-cache add php7 php7-fpm php7-mysqli \
    php7-json php7-openssl php7-curl \
    php7-zlib php7-xml php7-phar \
    php7-intl php7-dom php7-xmlreader \
    php7-ctype php7-mbstring php7-gd \
    php7-mcrypt php7-soap php7-gmp\
    php7-pdo_odbc php7-dom php7-pdo \
    php7-zip php7-mysqli \
    php7-sqlite3 php7-apcu php7-odbc \
    php7-imagick php7-pdo_pgsql php7-pgsql \
    php7-bcmath php7-ldap \
    php7-pdo_mysql php7-pdo_sqlite php7-gettext \
    php7-xmlrpc php7-bz2 \
    php7-iconv \
    php7-pdo_dblib php7-dev php7-ctype \
    php7-common php7-pear php7-wddx \
    php7-xsl php7-ftp php7-phar \
    php7-posix php7-shmop php7-sockets \
    php7-exif php7-phpdbg \
    php7-opcache \
    --repository http://dl-cdn.alpinelinux.org/alpine/edge/main/ \
    --repository http://dl-cdn.alpinelinux.org/alpine/edge/testing/

RUN apk add --no-cache bash build-base wget curl m4 autoconf libtool imagemagick imagemagick-dev zlib zlib-dev libcurl curl-dev libevent libevent-dev libidn libmemcached libmemcached-dev libidn-dev && curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

COPY config/nginx/conf.d /etc/nginx/conf.d
COPY config/nginx/nginx.conf /etc/nginx/nginx.conf
COPY html /usr/share/nginx/html
VOLUME ["/var/cache/ngx_pagespeed","/app"]

COPY config/php7/php-fpm.conf /etc/php7/php-fpm.conf
COPY config/php.ini /etc/php7/php.ini
RUN chmod -R 777 /var/log/

# Print built version
RUN nginx -V

# Launch Nginx in container as non-root
USER nginx
WORKDIR /usr/share/nginx

# Launch command
CMD ["nginx", "-g", "daemon off;"]