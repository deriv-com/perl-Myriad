#!/bin/bash

if [ -r aptfile ]; then
    echo "installing apt deps"
    apt-get -y -q update
    apt-get -y -q --no-install-recommends install $(cat aptfile);
else echo "No aptfile found";
 fi

dzil authordeps --missing | cpanm
cpanm -n --installdeps .
rm -rf ~/.cpanm

if [ -d /opt/app/vendors ]; then
    for dir in /opt/app/vendors/*; do
        cd $dir
        dzil authordeps --missing | cpanm
        cpanm -n --installdeps .
        rm -rf ~/.cpanm
        dzil install
        dzil clean
    done
fi
