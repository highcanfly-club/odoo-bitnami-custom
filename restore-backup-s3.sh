#!/bin/bash
# This script restores a backup from S3 to the Odoo database using the Odoo API
# It requires the mc command line tool to be installed and configured
BACKUP_FILE=$1
DATABSE_NAME=$2
BACKUP_DIR=/bitnami/odoo/backups
: ${S3_PATH:=odoobackups}

# Check if the backup file is provided
if [ -z "${BACKUP_FILE}" ]; then
    echo "Backup file not provided"
    echo "Usage: $0 <backup_file> <database_name>"
    exit 1
fi
# Check if the database name is provided
if [ -z "${DATABSE_NAME}" ]; then
    echo "Database name not provided"
    echo "Usage: $0 <backup_file> <database_name>"
    exit 1
fi

# Check if the mc command line tool is installed
if ! [ -x "$(command -v mc)" ]; then
    echo "Error: mc is not installed." >&2
    exit 1
fi

# test if variables S3_BUCKET, S3_ACCESS_KEY, S3_SECRET_KEY, S3_ENDPOINT, S3_REGION, S3_PATH are set
if [ -z "${S3_BUCKET}" ] || [ -z "${S3_ACCESS_KEY}" ] || [ -z "${S3_SECRET_KEY}" ] || [ -z "${S3_ENDPOINT}" ] || [ -z "${S3_PATH}" ]; then
    echo "S3_BUCKET, S3_ACCESS_KEY, S3_SECRET_KEY, S3_ENDPOINT, S3_REGION, S3_PATH are not set"
    exit 1
fi

#  Test if mc alias s3backup exists
if [ -z "$(mc alias list | grep s3backup)" ]; then
    echo "s3backup alias not found"
    echo "create s3backup alias"
    mc alias set s3backup ${S3_ENDPOINT} ${S3_ACCESS_KEY} ${S3_SECRET_KEY}
fi

# Download the backup from S3
mc cp s3backup/${S3_BUCKET}/${S3_PATH}/${BACKUP_FILE} ${BACKUP_DIR}/${BACKUP_FILE}

curl -X POST -F "master_pwd=${ODOO_PASSWORD}" \
             -F "backup_file=@${BACKUP_DIR}/${BACKUP_FILE}" \
             -F 'name=database_restore' \
             -F 'copy=true' http://localhost:8069/web/database/restore

echo "You can access the Odoo application using the following url:"
echo "https://${FQDN}/web?db=${DATABSE_NAME}"
echo "You can log in using the following credentials:"
echo "user: ${ODOO_EMAIL}"
echo "password: ${ODOO_PASSWORD}"
echo "If you need to define the default database, you should edit the /opt/binami/odoo/conf/odoo.conf file"
echo "and set the db_name parameter to the ${DATABSE_NAME}"
