#!/bin/bash

################################################################################
# Simplistic dump manager for MySQL.
################################################################################
# Usage example:
#
#     ./db-dumper.sh mydb dbuser secret ~/backups/mydb 30
#
# This will dump database "mydb" to "~/backups/mydb" and also manage old dumps
# automatically - old dumps will be archived and old archives will be removed
# so that max number of simultaneously stored archives is 30 (last argument).
# dbuser:secret is the username and password to access the database.
#
# IMPORTANT:
# - It is strongly suggested to put backups for each database in a separate
#   directory with no other files in it.
# - Don't forget to escape special symbols when invoking dumper.
# - `mysqldump` must be available.
# - Database user must have permissions on database to make a backup.
################################################################################

db_name=$1
db_username=$2
db_password=$3
backup_dir=$4
save_last_n_archives=$5

# To prevent the "Warning: Using a password on the command line interface can be insecure." message
export MYSQL_PWD=$db_password

# Escaped version of database name to use in paths.
db_name_escaped=`echo $db_name | sed 's/[^a-zA-Z0-9_-]/_/g'`

# Current date and time is used in filenames, so later script can determine
# which dumps are old.
current_time=`date +%F_%H-%M-%S` # Format: 2000-12-31_23-59-59

# Make sure destination directory exists
mkdir -p $backup_dir

# Archive old dumps
for sql_file in `ls $backup_dir | grep "^${db_name_escaped}_.*\.sql\$"`; do
  tar --create --gzip --file $backup_dir/$sql_file.gz $backup_dir/$sql_file
  rm -f $backup_dir/$sql_file
done

# Make a new dump
new_dump=${db_name_escaped}_${current_time}.sql
mysqldump --user=$db_username --databases $db_name &> $backup_dir/$new_dump

# Get filenames for all dump archives.
all_archives=(`ls $backup_dir | grep "^${db_name_escaped}_.*\.sql\.gz\$"`)

# Last `$save_last_n_archives` archives which we want to leave.
whitelist=(`ls $backup_dir | grep "^${db_name_escaped}_.*\.sql\.gz\$" | sort -r | head -n$save_last_n_archives`)

# @param string Needle
# @param string[] Haystack
# @return 0 if a haystack contains a needle, 1 otherwise
contains () {
  local e
  for e in "${@:2}"; do [[ "$e" == "$1" ]] && return 0; done
  return 1
}

for archive in ${all_archives[@]}; do
  contains $archive ${whitelist[@]} || rm -f $backup_dir/$archive
done
