#!/bin/sh

###-------------------------------------------------------------------
### File    : init.sh
### Author  : Aleksey Morarash <aleksey.morarash@gmail.com>
### Created : 6 Jul 2012
### License : FreeBSD
### Description : initiates echessd persistent storage
###               Warning: all existing data will be lost!
###-------------------------------------------------------------------

exec su --login --command \
    'erl -sname "echessd" \
    -noshell -noinput \
    -mnesia dir \"/var/lib/echessd\" \
    -s echessd_db init \
    -s init stop' echessd
