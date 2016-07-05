#!/usr/bin/env sh
# Watch files in this directory, update the sums with their hashes
# The sums file is used to keep files in sync without redownloading everything
while [ true ]
do
  find -type f -exec md5sum "{}" + > sums
  inotifywait -e close_write *
done

