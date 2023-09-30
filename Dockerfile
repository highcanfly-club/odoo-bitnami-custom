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
    && git clone -b 16.0 --single-branch https://github.com/odoomates/odooapps.git \
    && mv odooapps/* /bitnami/odoo/addons/ \
    && rm -f /bitnami/odoo/addons/README.mail_debrand
FROM golang:1.21 as gobuilder
COPY getsecret /getsecret
RUN cd /getsecret && go mod tidy && go build

FROM docker.io/bitnami/odoo:16
RUN mkdir -p /addons
COPY --from=gobuilder /getsecret/getsecret /usr/local/bin/getsecret
COPY --from=builder /bitnami/odoo/addons/ /addons/
COPY --chmod=0755 deploy-addons.sh /deploy-addons.sh
RUN /deploy-addons.sh \
    && rm -rf /deploy-addons.sh \
    && apt-get update -y && apt install -y --no-install-recommends \
                wkhtmltopdf