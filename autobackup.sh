#!/bin/bash
NOW=$(date +%F)
BACKUP_DIR=/bitnami/odoo/backups
FILENAME="${ODOO_DATABASE_NAME}.${NOW}.zip"

# create a backup directory
mkdir -p ${BACKUP_DIR}

# create a backup
curl -X POST \
    -F "master_pwd=${ODOO_PASSWORD}" \
    -F "name=${ODOO_DATABASE_NAME}" \
    -F "backup_format=zip" \
    -o ${BACKUP_DIR}/${FILENAME} \
    http://localhost:8069/web/database/backup


# delete old backups
find ${BACKUP_DIR} -type f -mtime +${BACKUP_KEEP_DAYS} -name "${ODOO_DATABASE_NAME}.*.zip" -delete

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
URL: https://$FQDN/
Odoo+ team

---
Content-Type: application/octet-stream; name="$FILENAME"
Content-Transfer-Encoding: base64
Content-Disposition: inline; filename="$FILENAME"

EOF
)    | (cat - && /usr/bin/openssl base64 < ${BACKUP_DIR}/$FILENAME && echo "" && echo "---")\
     | /usr/sbin/sendmail -f $BACKUP_FROM -S $SMTPD_SERVICE_HOST -t --
