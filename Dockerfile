FROM alpine:3.14 as builder
MAINTAINER Kevin Yuan <whyork@qq.com>
ARG MOZ_VERSION=4.0.3
ARG VIPS_VERSION=8.11.4
WORKDIR /src/
#speed up for chinese coder
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.ustc.edu.cn/g' /etc/apk/repositories \
	&& ln -sf /usr/local/lib/ /usr/local/lib64 && ln -sf /usr/include/ /usr/local/include \
	&& apk --update --no-cache add curl libarchive-tools libc6-compat g++ musl-dev autoconf automake cmake make libtool  nasm zlib zlib-dev file pkgconf libjpeg-turbo libjpeg-turbo-dev build-base \
	orc orc-dev lcms2 lcms2-dev zlib-dev libxml2-dev glib-dev gobject-introspection-dev libexif-dev expat-dev libimagequant libimagequant-dev graphicsmagick-dev \
	libexif-dev fftw-dev giflib-dev libpng-dev libwebp-dev tiff-dev poppler-dev librsvg-dev libgsf-dev openexr-dev \
	libheif-dev pango-dev py-gobject3-dev \
	&& curl -L https://github.com/libvips/libvips/releases/download/v${VIPS_VERSION}/vips-${VIPS_VERSION}.tar.gz |bsdtar -xvf- -C /src/ \
	&& curl -L https://github.com/mozilla/mozjpeg/archive/refs/tags/v${MOZ_VERSION}.zip | bsdtar -xvf- -C /src/ \
	&& curl -L https://github.com/danielgtaylor/jpeg-archive/archive/refs/heads/master.zip | bsdtar -xvf- -C /src/ \
#patch jpeg-archive for GCC10
	&& sed -i 's/CFLAGS += -std=c99 -Wall -O3/CFLAGS += -std=c99  -fcommon -Wall -O3/'  /src/jpeg-archive-master/Makefile \
	&& echo 'Preparation is done'
	# libimagequant-dev lcms2 lcms2-dev\

RUN	cd /src/vips-${VIPS_VERSION} \ && ./configure --prefix=/usr --disable-static --enable-shared --disable-dependency-tracking --disable-debug --enable-silent-rules  --disable-introspection --with-magickpackage=GraphicsMagick \
	&& make -j4 && make install
#    && make check

RUN  cd /src/mozjpeg-${MOZ_VERSION} \
	&& mkdir build && cd build && cmake -G"Unix Makefiles" -DPNG_SUPPORTED=NO -DCMAKE_INSTALL_LIBDIR=/usr/local/lib/ -DCMAKE_INSTALL_PREFIX=/usr/local/ .. && make -j4 && make install \
	&& cd /src/mozjpeg-${MOZ_VERSION} && cp -f jpeglib.h /usr/include/

RUN cd /src/jpeg-archive-master \
	&& apk add parallel \
	&& make MOZJPEG_PREFIX=/usr/local && make install

FROM alpine:3.14
COPY --from=builder /src/vips-8.11.4/libvips/.libs/libvips*  "/usr/lib/"
COPY --from=builder /src/vips-8.11.4/tools/.libs/* "/usr/bin/"
COPY --from=builder /src/jpeg-archive-master/jpeg-recompress "/usr/local/bin/"
COPY --from=builder /src/jpeg-archive-master/jpeg-hash "/usr/local/bin/"
COPY --from=builder /src/jpeg-archive-master/jpeg-compare "/usr/local/bin/"
COPY --from=builder /src/jpeg-archive-master/jpeg-archive "/usr/local/bin/"

RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.ustc.edu.cn/g' /etc/apk/repositories \
    && ln -sf /usr/local/lib/ /usr/local/lib64 && ln -sf /usr/include/ /usr/local/include \
    && apk --update --no-cache add curl libarchive-tools graphicsmagick parallel nasm zlib libjpeg-turbo orc lcms2 libexif libimagequant libexif libheif libwebp libpng libgsf pango fftw giflib tiff poppler librsvg openexr \
    && ln -sf /usr/lib/libvips.so /lib/ \
    && echo 'ls -la "$@"' > /usr/bin/ll && chmod 755 /usr/bin/ll


# vipsthumbnail --size '1920x1080 test.jpg -o test_new.jpg [Q=90] # shrink image with new size with quality=90%
# jpeg-recompress  ${@:--q high -m smallfry -s -n 40 -x 85} test.jpg test.jpeg #compress single file with min-quality=40% max-quality=85%
# jpeg-archive --quality medium --method smallfry #under the folder contains `.jpg` images

# https://github.com/libvips/libvips
# https://github.com/danielgtaylor/jpeg-archive
# https://github.com/mozilla/mozjpeg
