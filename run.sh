#!/bin/bash

MONGODB_HOST=${MONGODB_PORT_27017_TCP_ADDR:-${MONGODB_HOST}}
MONGODB_HOST=${MONGODB_PORT_1_27017_TCP_ADDR:-${MONGODB_HOST}}
MONGODB_PORT=${MONGODB_PORT_27017_TCP_PORT:-${MONGODB_PORT}}
MONGODB_PORT=${MONGODB_PORT_1_27017_TCP_PORT:-${MONGODB_PORT}}
MONGODB_USER=${MONGODB_USER:-${MONGODB_ENV_MONGODB_USER}}
MONGODB_PASS=${MONGODB_PASS:-${MONGODB_ENV_MONGODB_PASS}}

S3PATH="s3://$S3_BUCKET/$BACKUP_FOLDER"

[[ ( -z "${MONGODB_USER}" ) && ( -n "${MONGODB_PASS}" ) ]] && MONGODB_USER='admin'

[[ ( -n "${MONGODB_USER}" ) ]] && USER_STR=" --username ${MONGODB_USER}"
[[ ( -n "${MONGODB_PASS}" ) ]] && PASS_STR=" --password '${MONGODB_PASS}'"
[[ ( -n "${MONGODB_DB}" ) ]] && DB_STR=" --db ${MONGODB_DB}"

# Export S3 Credentials into env file for cron job
printenv | sed 's/^\([a-zA-Z0-9_]*\)=\(.*\)$/export \1="\2"/g' | grep -e "^export AWS" -e "^export S3_" > /root/project_env.sh

echo "=> Creating backup script"
rm -f /backup.sh
cat <<EOF >> /backup.sh
#!/bin/bash
TIMESTAMP=\`/bin/date +"%Y%m%dT%H%M%S"\`
BACKUP_FILE_NAME=\${TIMESTAMP}.dump.gz
S3_BACKUP_PATH=${S3PATH}\${BACKUP_FILE_NAME}
echo "=> Backup started"
if mongodump --host ${MONGODB_HOST} --port ${MONGODB_PORT} ${USER_STR}${PASS_STR}${DB_STR} --archive=\${BACKUP_FILE_NAME} --gzip ${EXTRA_OPTS} ;then
    echo "  > Dump size:" $(du -sh ${BACKUP_FILE_NAME})
    echo "  > Dump succeeded"
else
    echo "  > Dump failed"
fi
if aws s3 cp \${BACKUP_FILE_NAME} \${S3_BACKUP_PATH} --endpoint-url=\${S3_ENDPOINT} --cli-connect-timeout 0 ;then
    echo "  > Copy succeeded"
else
    echo "  > Copy failed"
fi
if rm \${BACKUP_FILE_NAME} ;then
    echo "  > Remove local file succeeded"
else
    echo "  > Remove local file failed"
fi
echo "=> Done"
EOF
chmod +x /backup.sh
echo "=> Backup script created"

echo "=> Creating restore script"
rm -f /restore.sh
cat <<EOF >> /restore.sh
#!/bin/bash
if [[( -n "\${1}" )]];then
    RESTORE_ME=\${1}.dump.gz
else
    RESTORE_ME=latest.dump.gz
fi
S3RESTORE=${S3PATH}\${RESTORE_ME}
echo "=> Restore database from \${RESTORE_ME}"
if aws s3 cp \${S3RESTORE} \${RESTORE_ME} --endpoint-url=\${S3_ENDPOINT} && mongorestore --host ${MONGODB_HOST} --port ${MONGODB_PORT} ${USER_STR}${PASS_STR}${DB_STR} --drop ${EXTRA_OPTS} --archive=\${RESTORE_ME} --gzip && rm \${RESTORE_ME}; then
    echo "  Restore succeeded"
else
    echo "  Restore failed"
fi
echo "=> Done"
EOF
chmod +x /restore.sh
echo "=> Restore script created"

echo "=> Creating list script"
rm -f /listbackups.sh
cat <<EOF >> /listbackups.sh
#!/bin/bash
aws s3 ls ${S3PATH} --endpoint-url=\${S3_ENDPOINT}
EOF
chmod +x /listbackups.sh
echo "=> List script created"

ln -s /restore.sh /usr/bin/restore
ln -s /backup.sh /usr/bin/backup
ln -s /listbackups.sh /usr/bin/listbackups

touch /mongo_backup.log

if [ -n "${INIT_BACKUP}" ]; then
    echo "=> Create a backup on the startup"
    /backup.sh
fi

if [ -n "${INIT_RESTORE}" ]; then
    echo "=> Restore store from lastest backup on startup"
    /restore.sh
fi

if [ -z "${DISABLE_CRON}" ]; then
    echo "${CRON_TIME} . /root/project_env.sh; /backup.sh >> /mongo_backup.log 2>&1" > /var/spool/cron/crontabs/root
    crontab /var/spool/cron/crontabs/root
    echo "=> Running cron job"
    crond && tail -f /mongo_backup.log
fi
