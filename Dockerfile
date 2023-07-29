FROM public.ecr.aws/lambda/python:3.10

# Set up working directories
RUN mkdir -p /opt/app
RUN mkdir -p /opt/app/build
RUN mkdir -p /opt/app/bin/
RUN mkdir -p /opt/app/tmp/

# Get lib list
# RUN ls /usr/lib64 > /opt/app/tmp/lib.txt

# Install packages
RUN yum update -y
RUN yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
RUN yum install -y yum-utils epel-release

# Install libraries we need to run in lambda
RUN yum install -y clamav clamav-lib clamav-update bzip2 zlib libxml2 libmspack check libcurl
RUN cp /usr/bin/clamscan /usr/bin/freshclam /opt/app/bin/
RUN yum remove -y yum-utils epel-release
RUN find /usr/lib64/* -type f -maxdepth 0 -exec cp {} /opt/app/bin/ \;
RUN find /usr/lib64/* -type l -maxdepth 0 -exec cp {} /opt/app/bin/ \;
RUN find /usr/lib/* -type f -maxdepth 0 -exec cp {} /opt/app/bin/ \;
RUN find /usr/lib/* -type l -maxdepth 0 -exec cp {} /opt/app/bin/ \;

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
COPY installed_lib_list.txt /opt/app/tmp/installed_lib_list.txt
RUN cat /opt/app/tmp/installed_lib_list.txt | xargs -I '{}' zip --delete /opt/app/build/lambda.zip bin/{} ; exit 0
WORKDIR /opt/app/site-packages
RUN zip -r9 /opt/app/build/lambda.zip *