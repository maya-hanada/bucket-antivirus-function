FROM public.ecr.aws/lambda/python:3.11

RUN cat /etc/system-release

# Set up working directories
RUN mkdir -p /opt/app
RUN mkdir -p /opt/app/build
RUN mkdir -p /opt/app/bin/
RUN mkdir -p /opt/app/tmp/

# Install packages
RUN yum update -y
RUN yum install -y yum-utils cpio
RUN yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm

# Install libraries we need to run in lambda
WORKDIR /tmp
RUN yumdownloader -x \*i686 --archlist=x86_64,aarch64 \
    clamav clamav-lib clamav-update \
    bzip2-libs json-c libcurl\
    libidn2 libnghttp2 libprelude\
    libssh2 libtool-ltdl libxml2\
    openldap pcre2 \
    xz-libs gnutls nettle \
    libunistring cyrus-sasl-lib nss

RUN rpm2cpio clamav-0*.rpm | cpio -idmv
RUN rpm2cpio clamav-lib*.rpm | cpio -idmv
RUN rpm2cpio clamav-update*.rpm | cpio -idmv
RUN rpm2cpio bzip2-libs*.rpm | cpio -idmv
RUN rpm2cpio json-c*.rpm | cpio -idmv
RUN rpm2cpio libcurl*.rpm | cpio -idmv
RUN rpm2cpio libidn2*.rpm | cpio -idmv
RUN rpm2cpio libnghttp2*.rpm | cpio -idmv
RUN rpm2cpio libprelude*.rpm | cpio -idmv
RUN rpm2cpio libssh2*.rpm | cpio -idmv
RUN rpm2cpio libtool-ltdl*.rpm | cpio -idmv
RUN rpm2cpio libxml2*.rpm | cpio -idmv
RUN rpm2cpio openldap*.rpm | cpio -idmv
RUN rpm2cpio pcre2*.rpm | cpio -idmv

RUN rpm2cpio xz-libs*.rpm | cpio -idmv
RUN rpm2cpio gnutls*.rpm | cpio -idmv
RUN rpm2cpio nettle*.rpm | cpio -idmv
RUN rpm2cpio libunistring*.rpm | cpio -idmv
RUN rpm2cpio cyrus-sasl-lib*.rpm | cpio -idmv
RUN rpm2cpio nss*.rpm | cpio -idmv

# Copy over the binaries and libraries
WORKDIR /tmp
RUN cp -rf /tmp/usr/bin/clamscan /tmp/usr/bin/freshclam /tmp/usr/lib64/* /opt/app/bin/

# Fix the freshclam.conf settings
RUN echo "DatabaseMirror database.clamav.net" > /opt/app/bin/freshclam.conf
RUN echo "CompressLocalDatabase yes" >> /opt/app/bin/freshclam.conf

# Copy in the lambda source
WORKDIR /opt/app
COPY ./*.py /opt/app/
COPY requirements.txt /opt/app/requirements.txt
# This had --no-cache-dir, tracing through multiple tickets led to a problem in wheel
RUN pip3 install -r requirements.txt --target=./site-packages
RUN rm -rf /root/.cache/pip
# Create the zip file
RUN yum install -y zip
RUN zip -r9 /opt/app/build/lambda.zip *.py bin
WORKDIR /opt/app/site-packages
RUN zip -r9 /opt/app/build/lambda.zip *