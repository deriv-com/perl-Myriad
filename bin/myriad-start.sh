#!/bin/bash

_term() {
    kill -TERM "$myriad" 2>/dev/null
    wait "$myriad"
}

_int() {
    kill -INT "$myriad" 2>/dev/null
    wait "$myriad"
}

_quit() {
    kill -QUIT "$myriad" 2>/dev/null
    wait "$myriad"
}

trap _term SIGTERM
trap _int SIGINT
trap _quit SIGQUIT

if [ ! -z $MYRIAD_DEV ]
then
        myriad-dev.pl $@ &
    else
        myriad.pl $@ &
fi

myriad=$!
wait "$myriad"
