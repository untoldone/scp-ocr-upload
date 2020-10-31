FROM golang:1.15.3-buster as gobuilder

RUN go get github.com/prasmussen/gdrive
RUN go install github.com/prasmussen/gdrive

FROM jbarlow83/ocrmypdf:v11.3.0 as ocrmypdf

FROM ubuntu:20.04
MAINTAINER Michael M. Wasser [exactlylabs.com]

ENV LANG=C.UTF-8

### Copy from ocrmypdf
COPY --from=ocrmypdf /usr/local/lib/ /usr/local/lib/
COPY --from=ocrmypdf /usr/local/bin/ /usr/local/bin/
COPY --from=ocrmypdf /app/ /app/

### Copy from gdrive
COPY --from=gobuilder /go/bin/gdrive /usr/local/bin/

# Steps done in one RUN layer:
# - Install packages
# - OpenSSH needs /var/run/sshd to run
# - Remove generic host keys, entrypoint generates unique keys
RUN apt-get update && \
    apt-get -y --no-install-recommends install \
      ca-certificates \
      ghostscript \
      img2pdf \
      liblept5 \
      libsm6 libxext6 libxrender-dev \
      zlib1g \
      pngquant \
      python3 \
      qpdf \
      tesseract-ocr \
      tesseract-ocr-eng \
      unpaper \
      openssh-server \
      inotify-tools && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p /var/run/sshd && \
    rm -f /etc/ssh/ssh_host_*key*

RUN update-ca-certificates

RUN mkdir /input /output

COPY entrypoint /entrypoint
COPY kex.conf /etc/ssh/sshd_config.d/kex.conf

RUN addgroup inputoutput && \
    chgrp inputoutput /input /output && \
    chmod 775 /input /output

ENTRYPOINT /entrypoint

ENV SSH_USERNAME=ocr

EXPOSE 22