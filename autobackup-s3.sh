#!/bin/bash
NOW=$(date +%F)
BACKUP_DIR=/bitnami/odoo/backups
FILENAME="${ODOO_DATABASE_NAME}.${NOW}.zip"

# sets default values
: ${BACKUP_KEEP_DAYS:=90}
: ${S3_PATH:=odoobackups}

# create a backup directory
mkdir -p ${BACKUP_DIR}

# create a backup
curl -X POST \
    -F "master_pwd=${ODOO_PASSWORD}" \
    -F "name=${ODOO_DATABASE_NAME}" \
    -F "backup_format=zip" \
    -o ${BACKUP_DIR}/${FILENAME} \
    http://localhost:8069/web/database/backup

# test if variables S3_BUCKET, S3_ACCESS_KEY, S3_SECRET_KEY, S3_ENDPOINT, S3_REGION, S3_PATH are set
if [ -z "${S3_BUCKET}" ] || [ -z "${S3_ACCESS_KEY}" ] || [ -z "${S3_SECRET_KEY}" ] || [ -z "${S3_ENDPOINT}" ] || [ -z "${S3_PATH}" ]; then
    echo "S3_BUCKET, S3_ACCESS_KEY, S3_SECRET_KEY, S3_ENDPOINT, S3_REGION, S3_PATH are not set"
    exit 1
fi
# delete old backups
find ${BACKUP_DIR} -type f -mtime +${BACKUP_KEEP_DAYS} -name "${ODOO_DATABASE_NAME}.*.zip" -delete

#  Test if mc alias s3backup exists
if [ -z "$(mc alias list | grep s3backup)" ]; then
    echo "s3backup alias not found"
    echo "create s3backup alias"
    mc alias set s3backup ${S3_ENDPOINT} ${S3_ACCESS_KEY} ${S3_SECRET_KEY}
fi

# Copy the backup to the S3 bucket
mc cp ${BACKUP_DIR}/${FILENAME} s3backup/${S3_BUCKET}/${S3_PATH}/${FILENAME}

# Auto delete old backups on S3
mc rm --recursive --force --older-than ${BACKUP_KEEP_DAYS}d s3backup/${S3_BUCKET}/${S3_PATH}

# delete the local backup
rm -f ${BACKUP_DIR}/${FILENAME}
 