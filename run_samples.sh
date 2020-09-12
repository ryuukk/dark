#!/bin/bash

BUILD_TARGET=release # debug, release, profile, profile_gc
ARCH=x86_64 # x86, x86_64
COMPILER=dmd # ldc2, dmd
# FLAGS= "dflags-dmd": ["-vgc"],

echo "Wich sample to run:"

select d
in samples/*;
do test -n ">> $d" && break; echo ">>> Invalid Selection";
done

result=$(basename $d)
result=${result:3} 

echo "Running $d -> $result"


cd samples
dub run --config=$result --arch=$ARCH --build=$BUILD_TARGET --compiler=$COMPILER
