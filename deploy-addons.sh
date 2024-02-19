#!/bin/bash
mkdir -p /tmp/crontabs
VERSION=$(find /opt/bitnami/odoo/lib/ -name "*addons" | sed -ne 's/.*\/lib\/\(.*\)\.egg.*addons$/\1/p' | head -n1)
mv /addons/* "/opt/bitnami/odoo/lib/$VERSION.egg/odoo/addons/"
rm -rf /addons
