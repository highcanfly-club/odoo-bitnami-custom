#!/bin/bash
BACKUP_DIR=/bitnami/odoo/backups
FILESTOR_DIR=/bitnami/odoo/data/filestore

# test if variables ODOO_DATABASE_HOST, ODOO_DATABASE_NAME, ODOO_DATABASE_USER, ODOO_DATABASE_PASSWORD are set
if [ -z "${ODOO_DATABASE_HOST}" ] || [ -z "${ODOO_DATABASE_NAME}" ] || [ -z "${ODOO_DATABASE_USER}" ] || [ -z "${ODOO_DATABASE_PASSWORD}" ]; then
    echo "ODOO_DATABASE_HOST, ODOO_DATABASE_NAME, ODOO_DATABASE_USER, ODOO_DATABASE_PASSWORD are not set"
    exit 1
fi
# default database port is 5432
ODOO_DATABASE_PORT_NUMBER=${ODOO_DATABASE_PORT_NUMBER:-5432}

# Test if we can connect to database with psql
if ! PGPASSWORD=${ODOO_DATABASE_PASSWORD} psql -h ${ODOO_DATABASE_HOST} -p ${ODOO_DATABASE_PORT_NUMBER} -U ${ODOO_DATABASE_USER} -d ${ODOO_DATABASE_NAME} -c '\q'; then
    echo "Could not connect to the database"
    exit 1
fi

# test if variables S3_BUCKET, S3_ACCESS_KEY, S3_SECRET_KEY, S3_ENDPOINT, S3_REGION, S3_PATH are set
if [ -z "${S3_BUCKET}" ] || [ -z "${S3_ACCESS_KEY}" ] || [ -z "${S3_SECRET_KEY}" ] || [ -z "${S3_ENDPOINT}" ] || [ -z "${S3_PATH}" ]; then
    echo "S3_BUCKET, S3_ACCESS_KEY, S3_SECRET_KEY, S3_ENDPOINT, S3_REGION, S3_PATH are not set"
    exit 1
fi



# test if mc is installed
if [ -z "$(which mc)" ]; then
    echo "mc is not installed"
    exit 1
fi

#  Test if mc alias s3backup exists
if [ -z "$(mc alias list | grep s3backup)" ]; then
    echo "s3backup alias not found"
    echo "create s3backup alias"
    mc alias set s3backup ${S3_ENDPOINT} ${S3_ACCESS_KEY} ${S3_SECRET_KEY}
fi

# create a backup directory
mkdir -p ${BACKUP_DIR}

# Find latest backup file in s3
LATEST_BACKUP=$(mc ls s3backup/${S3_BUCKET}/${S3_PATH} | sort -r | head -n 1 | awk '{print $6}')
mc cp s3backup/${S3_BUCKET}/${S3_PATH}/${LATEST_BACKUP} ${BACKUP_DIR}/${LATEST_BACKUP}

# If the backup extension is .enc, decrypt it
if [ "${LATEST_BACKUP##*.}" == "enc" ]; then
    LATEST_BACKUP_BASE=$(echo $LATEST_BACKUP | sed 's/.enc//')
    DECRYPT=""
    if [ -n "$CRYPTOKEN" ]; then
        echo "Archive is encrypted, decrypting"
        DECRYPT="-pass pass:$CRYPTOKEN"
    else
        echo "CRYPTOKEN is not set but backup file is encrypted"
       exit 1
    fi
    openssl aes-256-cbc -a -d -md sha256 $DECRYPT -in ${BACKUP_DIR}/${LATEST_BACKUP} -out - > ${BACKUP_DIR}/${LATEST_BACKUP_BASE}
    rm -f ${BACKUP_DIR}/${LATEST_BACKUP}
    LATEST_BACKUP=${LATEST_BACKUP_BASE}
fi
# Unzip the backup file to /tmp
TMP_DIR=$(mktemp -d)
unzip -o ${BACKUP_DIR}/${LATEST_BACKUP} -d ${TMP_DIR}

# Connect to the PostgreSQL database server
export PGPASSWORD=${ODOO_DATABASE_PASSWORD}

# Drop the existing database
psql -v ON_ERROR_STOP=1 -h ${ODOO_DATABASE_HOST} -p ${ODOO_DATABASE_PORT_NUMBER} -U ${ODOO_DATABASE_USER} -d postgres -c "
SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE pg_stat_activity.datname = '${ODOO_DATABASE_NAME}' AND pid <> pg_backend_pid();"
psql -v ON_ERROR_STOP=1 -h ${ODOO_DATABASE_HOST} -p ${ODOO_DATABASE_PORT_NUMBER} -U ${ODOO_DATABASE_USER} -d postgres -c '\c' -c "DROP DATABASE IF EXISTS ${ODOO_DATABASE_NAME};"

# Create a new database
psql -v ON_ERROR_STOP=1 -h ${ODOO_DATABASE_HOST} -p ${ODOO_DATABASE_PORT_NUMBER} -U ${ODOO_DATABASE_USER} -d postgres -c "CREATE DATABASE ${ODOO_DATABASE_NAME};"

# Restore the database from the dump
psql -v ON_ERROR_STOP=1 -h ${ODOO_DATABASE_HOST} -p ${ODOO_DATABASE_PORT_NUMBER} -U ${ODOO_DATABASE_USER} -d ${ODOO_DATABASE_NAME} -f ${TMP_DIR}/dump.sql

# Remove the filestore directory
mkdir -p ${FILESTOR_DIR}/${ODOO_DATABASE_NAME}
cp -r ${TMP_DIR}/filestore/* ${FILESTOR_DIR}/${ODOO_DATABASE_NAME}
rm -rf ${TMP_DIR}
rm -f ${BACKUP_DIR}/${LATEST_BACKUP}