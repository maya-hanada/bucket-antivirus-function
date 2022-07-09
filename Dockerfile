FROM amazonlinux:2

# Set up working directories
RUN mkdir -p /opt/app
RUN mkdir -p /opt/app/build
RUN mkdir -p /opt/app/bin/
RUN mkdir -p /opt/app/tmp/

# Copy in the lambda source
WORKDIR /opt/app
COPY ./*.py /opt/app/
COPY requirements.txt /opt/app/requirements.txt
COPY installed_lib_list.txt /opt/app/tmp/installed_lib_list.txt

# Install packages
RUN yum update -y
RUN yum install -y cpio yum-utils zip unzip less wget
RUN yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
RUN amazon-linux-extras install -y python3.8

# This had --no-cache-dir, tracing through multiple tickets led to a problem in wheel
RUN pip3.8 install -r requirements.txt
RUN rm -rf /root/.cache/pip

# Download libraries we need to run in lambda
WORKDIR /tmp
RUN yumdownloader --resolve -x \*i686 --archlist=x86_64 clamav clamav-lib clamav-update \
    json-c pcre2 libprelude gnutls nettle libtool-ltdl
RUN rpm2cpio clamav-0*.rpm | cpio -idmv
RUN rpm2cpio clamav-lib*.rpm | cpio -idmv
RUN rpm2cpio clamav-update*.rpm | cpio -idmv
RUN rpm2cpio json-c*.rpm | cpio -idmv
RUN rpm2cpio pcre*.rpm | cpio -idmv
RUN rpm2cpio libprelude* | cpio -idmv
RUN rpm2cpio gnutls* | cpio -idmv
RUN rpm2cpio nettle* | cpio -idmv
RUN rpm2cpio libtool-ltdl* | cpio -idmv

# Copy over the binaries and libraries
RUN cp /tmp/usr/bin/clamscan /tmp/usr/bin/freshclam /tmp/usr/lib64/* /opt/app/bin/
RUN find /usr/lib64/* -type f -maxdepth 0 -exec cp {} /opt/app/bin/ \;
RUN find /usr/lib64/* -type l -maxdepth 0 -exec cp {} /opt/app/bin/ \;
RUN cat /opt/app/tmp/installed_lib_list.txt | xargs rm -v -f

# Fix the freshclam.conf settings
RUN echo "DatabaseMirror database.clamav.net" > /opt/app/bin/freshclam.conf
RUN echo "CompressLocalDatabase yes" >> /opt/app/bin/freshclam.conf

# Create the zip file
WORKDIR /opt/app
RUN zip -r9 --exclude="*test*" /opt/app/build/lambda.zip *.py bin

WORKDIR /usr/local/lib/python3.8/site-packages
RUN zip -r9 /opt/app/build/lambda.zip *

WORKDIR /opt/app
