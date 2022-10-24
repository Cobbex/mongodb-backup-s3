# mongodb-backup-s3

This image runs mongodump to backup data using cronjob to an s3 bucket

## Usage:

```
docker run -d \
  --env S3_ACCESS_KEY_ID=s3accesskeyid \
  --env S3_SECRET_ACCESS_KEY=s3secretaccesskey \
  --env S3_BUCKET=my-s3-bucket \
  --env S3_ENDPOINT=s3.endpoint.example.com \
  --env MONGODB_HOST=mongodb.host \
  --env MONGODB_PORT=27017 \
  --env MONGODB_USER=admin \
  --env MONGODB_PASS=password \
  halvves/mongodb-backup-s3
```

Or use `INIT_RESTORE` with `DISABLE_CRON` for seeding/restoring/starting a db (great for a fresh instance or a dev machine)

```
mongodbbackup:
  image: 'halvves/mongodb-backup-s3:latest'
  links:
    - mongodb
  environment:
    - S3_ACCESS_KEY_ID=myaccesskeyid
    - S3_SECRET_ACCESS_KEY=mysecretaccesskey
    - S3_BUCKET=my-s3-bucket
    - S3_ENDPOINT=s3.endpoint.example.com
    - BACKUP_FOLDER=prod/db/
    - INIT_RESTORE=true
    - DISABLE_CRON=true
```

## Parameters

`AWS_ACCESS_KEY_ID` - your aws access key id (for your s3 bucket)

`AWS_SECRET_ACCESS_KEY`: - your aws secret access key (for your s3 bucket)

`S3_BUCKET`: - your s3 bucket

`S3_ENDPOINT`: - your s3 endpoint

`BACKUP_FOLDER`: - name of folder or path to put backups (eg `myapp/db_backups/`). defaults to root of bucket.

`MONGODB_HOST` - the host/ip of your mongodb database

`MONGODB_PORT` - the port number of your mongodb database

`MONGODB_USER` - the username of your mongodb database. If MONGODB_USER is empty while MONGODB_PASS is not, the image will use admin as the default username

`MONGODB_PASS` - the password of your mongodb database

`MONGODB_DB` - the database name to dump. If not specified, it will dump all the databases

`EXTRA_OPTS` - any extra options to pass to mongodump command

`CRON_TIME` - the interval of cron job to run mongodump. `0 3 * * *` by default, which is every day at 03:00hrs.

`TZ` - timezone. default: `US/Eastern`

`CRON_TZ` - cron timezone. default: `US/Eastern`

`INIT_BACKUP` - if set, create a backup when the container launched

`INIT_RESTORE` - if set, restore from latest when container is launched

`DISABLE_CRON` - if set, it will skip setting up automated backups. good for when you want to use this container to seed a dev environment.

## Restore from a backup

To see the list of backups, you can run:
```
docker exec mongodb-backup-s3 /listbackups.sh
```

To restore database from a certain backup, simply run (pass in just the timestamp part of the filename):

```
docker exec mongodb-backup-s3 /restore.sh 20170406T155812
```

To restore latest just:
```
docker exec mongodb-backup-s3 /restore.sh
```

## Acknowledgements

  * forked from [halvves](https://github.com/halvves) forked from [futurist](https://github.com/futurist)'s fork of [tutumcloud/mongodb-backup](https://github.com/tutumcloud/mongodb-backup)