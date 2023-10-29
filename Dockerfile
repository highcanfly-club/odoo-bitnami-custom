FROM alpine:latest as builder
RUN apk update \
    && apk add curl git \
    && mkdir -p /bitnami/odoo/addons \
    && cd /bitnami/odoo/addons/ \
    && curl -J -L https://github.com/herokukms/odoo-addons/raw/main/addons/OCA-16.0.0.0.tar.bz2 | tar -xvj \
    && curl -J -L 'https://github.com/herokukms/odoo-addons/raw/main/addons/mail_debrand-16.0.230212.212209.tar.bz2' | tar -xvj \
    && curl -J -L 'https://github.com/herokukms/odoo-addons/raw/main/addons/base_location-16.0.1.0.1.tar.bz2' | tar -xvj \
    && curl -J -L 'https://github.com/herokukms/odoo-addons/raw/main/addons/currency_rate_update-16.0.1.1.2.tar.bz2' | tar -xvj \
    && cd /tmp/ \
    && git clone -b 16.0 --single-branch https://github.com/eltorio/odooapps.git \
    && mv odooapps/* /bitnami/odoo/addons/ \
    && git clone https://github.com/eltorio/odoo-bank-account-on-invoice.git \
    && mv odoo-bank-account-on-invoice/iban_on_invoice_module /bitnami/odoo/addons/ \
    && git clone -b 16.0 --single-branch https://github.com/OCA/community-data-files.git \
    && mv community-data-files/base_* /bitnami/odoo/addons/ \
    && git clone -b 16.0 --single-branch https://github.com/OCA/bank-payment.git \
    && mv bank-payment/account* /bitnami/odoo/addons/ \
    && git clone -b 16.0 --single-branch https://github.com/OCA/pos.git \
    && mv pos/pos_* /bitnami/odoo/addons/ \
    && rm -f /bitnami/odoo/addons/README.mail_debrand

FROM debian:bullseye AS busyboxbuilder
RUN cd / \
    && apt-get update -y \
    && apt-get install -y build-essential curl libntirpc-dev
COPY busybox/busybox-1.36.1.tar.bz2 /busybox-1.36.1.tar.bz2
RUN cd / &&  tar -xjvf  busybox-1.36.1.tar.bz2
COPY busybox/busybox.config /busybox-1.36.1/.config
RUN cd /busybox-1.36.1/ && make install

FROM golang:1.21-bullseye as gobuilder
COPY getsecret /getsecret
RUN cd /getsecret && go mod tidy && go build -ldflags="-s -w"

FROM bitnami/odoo:16 as dcronbuilder
USER root
RUN cd / \
    && apt-get update -y \
    && apt-get install -y build-essential curl libntirpc-dev git
RUN mkdir -p /etc/cron.d && chown -R 1001 /etc/cron.d
RUN git clone https://github.com/eltorio/dcron.git \
    && cd dcron \
    && make CRONTAB_GROUP=odoo CRONTABS=/tmp/crontabs CRONSTAMPS=/tmp/cronstamps

FROM bitnami/odoo:16
RUN mkdir -p /addons
COPY --from=gobuilder /getsecret/getsecret /usr/local/bin/getsecret
COPY --from=builder /bitnami/odoo/addons/ /addons/
COPY --chmod=0755 deploy-addons.sh /deploy-addons.sh
COPY --chmod=0755 autobackup.sh /usr/local/bin/autobackup
RUN sh /deploy-addons.sh \
    && rm -rf /deploy-addons.sh
    # && apt-get update -y && apt install -y --no-install-recommends cron
# RUN if [ "$(dpkg --print-architecture)" = "arm64" ] ; then \
#     curl -sLO https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6-1/wkhtmltox_0.12.6-1.buster_$(dpkg --print-architecture).deb  \
#     && dpkg -i "wkhtmltox_0.12.6-1.buster_$(dpkg --print-architecture).deb" \
#     && rm wkhtmltox_0.12.6-1.buster_$(dpkg --print-architecture).deb  ;\
#     fi
COPY --from=busyboxbuilder /busybox-1.36.1/_install/bin/busybox /bin/busybox
RUN ln -svf /bin/busybox /usr/sbin/sendmail
COPY --from=dcronbuilder /dcron/crond /usr/sbin/crond
RUN mkdir -p /etc/cron.d && chown -R 1001 /etc/cron.d && chmod 0755 /usr/sbin/crond