#!/bin/bash
RELESASE_NAME=$(echo "$ODOO_DATABASE_HOST" | sed -ne "s/^\(.*\)-postgresql$/\1/p")
PGPASSWORD=$(getsecret -secret "$RELESASE_NAME-postgresql" -key postgres-password)
NOW=$(date -I)
DBFILENAME="/bitnami/odoo/data/$ODOO_DATABASE_NAME-$NOW.dump"
export PGPASSWORD
pg_dump -U postgres -h "$ODOO_DATABASE_HOST" -Fc -O "$ODOO_DATABASE_NAME" > "$DBFILENAME"
tar -cvJf /tmp/backup.tar.xz "$DBFILENAME" /bitnami/odoo/data/filestore /bitnami/odoo/data/addons
rm -rf "${DBFILENAME}"
(
cat << EOF 
From: "SAUVEGARDE @Odoo" <$BACKUP_FROM>
To: "Backup@Odoo" <$BACKUP_TO>
MIME-Version: 1.0
Subject: Sauvegarde Odoo $FQDN du $NOW 
Content-Type: multipart/mixed; boundary="-"

This is a MIME encoded message.  Decode it with "munpack"
or any other MIME reading software.  Mpack/munpack is available
via anonymous FTP in ftp.andrew.cmu.edu:pub/mpack/
---
Content-Type: text/plain

Voici la sauvegarde du $NOW
accès https://$FQDN/
Odoo+ team

---
Content-Type: application/octet-stream; name="backup-$NOW.tar.xz"
Content-Transfer-Encoding: base64
Content-Disposition: inline; filename="backup-$NOW.tar.xz"

EOF
)    | (cat - && /usr/bin/openssl base64 < /tmp/backup.tar.xz && echo "" && echo "---")\
     | /usr/sbin/sendmail -f $BACKUP_FROM -S $SMTPD_SERVICE_HOST -t --
rm -rf /tmp/backup.tar.xz