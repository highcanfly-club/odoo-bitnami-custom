ARG BASE_VERSION_SHORT=16
ARG BASE_VERSION=16.0


FROM alpine:latest as builder
ARG BASE_VERSION_SHORT
ARG BASE_VERSION
RUN apk update \
    && apk add curl git \
    && mkdir -p /bitnami/odoo/addons \
    && cd /tmp/ \
    && git clone -b $BASE_VERSION --single-branch https://github.com/OCA/server-brand.git \
    && mv server-brand/remove_odoo_enterprise /bitnami/odoo/addons/ \
    && git clone -b $BASE_VERSION --single-branch https://github.com/OCA/account-financial-tools.git \
    && mv account-financial-tools/account_asset_management /bitnami/odoo/addons/ \
    && mv account-financial-tools/account_cash_deposit /bitnami/odoo/addons/ \
    && git clone -b $BASE_VERSION --single-branch https://github.com/OCA/helpdesk.git \
    && mv helpdesk/helpdesk_mgmt /bitnami/odoo/addons/ \
    && mv helpdesk/helpdesk_mgmt_project /bitnami/odoo/addons/ \
    && mv helpdesk/helpdesk_mgmt_timesheet /bitnami/odoo/addons/ \
    && mv helpdesk/helpdesk_type /bitnami/odoo/addons/ \
    && git clone -b $BASE_VERSION --single-branch https://github.com/OCA/website.git \
    && mv website/website_odoo_debranding /bitnami/odoo/addons/ \
    && git clone -b $BASE_VERSION --single-branch https://github.com/OCA/social.git \
    && mv social/mail_debrand /bitnami/odoo/addons/ \
    && git clone -b $BASE_VERSION --single-branch https://github.com/OCA/currency.git \
    && mv currency/currency_rate_update /bitnami/odoo/addons/ \
    && git clone -b $BASE_VERSION --single-branch https://github.com/OCA/partner-contact.git \
    && mv partner-contact/base_location /bitnami/odoo/addons/ \
    && git clone -b $BASE_VERSION --single-branch https://github.com/eltorio/odooapps.git \
    && mv odooapps/* /bitnami/odoo/addons/ \
    && git clone https://github.com/eltorio/odoo-bank-account-on-invoice.git \
    && mv odoo-bank-account-on-invoice/iban_on_invoice_module /bitnami/odoo/addons/ \
    && git clone -b $BASE_VERSION --single-branch https://github.com/OCA/community-data-files.git \
    && mv community-data-files/base_* /bitnami/odoo/addons/ \
    && git clone -b $BASE_VERSION --single-branch https://github.com/OCA/bank-payment.git \
    && mv bank-payment/account* /bitnami/odoo/addons/ \
    && git clone -b $BASE_VERSION --single-branch https://github.com/OCA/pos.git \
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

ARG BASE_VERSION_SHORT
ARG BASE_VERSION
FROM bitnami/odoo:$BASE_VERSION_SHORT as dcronbuilder
USER root
RUN cd / \
    && apt-get update -y \
    && apt-get install -y build-essential curl libntirpc-dev git
RUN mkdir -p /etc/cron.d && chown -R 1001 /etc/cron.d
RUN git clone https://github.com/eltorio/dcron.git \
    && cd dcron \
    && make CRONTAB_GROUP=odoo CRONTABS=/tmp/crontabs CRONSTAMPS=/tmp/cronstamps

ARG BASE_VERSION_SHORT
ARG BASE_VERSION
FROM bitnami/odoo:$BASE_VERSION_SHORT
RUN mkdir -p /addons
COPY --from=gobuilder /getsecret/getsecret /usr/local/bin/getsecret
COPY --from=builder /bitnami/odoo/addons/ /addons/
COPY --chmod=0755 deploy-addons.sh /deploy-addons.sh
COPY --chmod=0755 autobackup.sh /usr/local/bin/autobackup
COPY --chmod=0755 autobackup-s3.sh /usr/local/bin/autobackup-s3
RUN apt-get update -y \
    && apt-get install -y xz-utils bzip2 vim
RUN sh /deploy-addons.sh \
    && rm -rf /deploy-addons.sh
    # && apt-get update -y && apt install -y --no-install-recommends cron
# RUN if [ "$(dpkg --print-architecture)" = "arm64" ] ; then \
#     curl -sLO https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6-1/wkhtmltox_0.12.6-1.buster_$(dpkg --print-architecture).deb  \
#     && dpkg -i "wkhtmltox_0.12.6-1.buster_$(dpkg --print-architecture).deb" \
#     && rm wkhtmltox_0.12.6-1.buster_$(dpkg --print-architecture).deb  ;\
#     fi
RUN curl -L https://dl.min.io/client/mc/release/linux-$(dpkg --print-architecture)/mc > /usr/local/bin/mc && chmod +x /usr/local/bin/mc
COPY --from=busyboxbuilder /busybox-1.36.1/_install/bin/busybox /bin/busybox
RUN ln -svf /bin/busybox /usr/sbin/sendmail
COPY --from=dcronbuilder /dcron/crond /usr/sbin/crond
RUN mkdir -p /etc/cron.d && chown -R 1001 /etc/cron.d && chmod 0755 /usr/sbin/crond