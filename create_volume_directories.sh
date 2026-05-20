#!/bin/bash
set -euo pipefail

source .env

mkdir --mode=700 --parents cache        && chmod 700 cache
mkdir --mode=700 --parents db-app       && chmod 700 db-app       && setfacl --modify="user:70:rwx" db-app
mkdir --mode=700 --parents derivatives  && chmod 700 derivatives
mkdir --mode=700 --parents downloads    && chmod 700 downloads
mkdir --mode=700 --parents file_uploads && chmod 700 file_uploads
mkdir --mode=700 --parents redis        && chmod 700 redis        && setfacl --modify="user:999:rwx" redis    && setfacl --modify="group:999:rwx" redis
mkdir --mode=700 --parents solr         && chmod 700 solr         && setfacl --modify="user:8983:rwx" solr
