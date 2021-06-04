#!/bin/sh

# install_name_tool -change old new file

#   ⃝ Kroleg, 2019

me=`basename "$0"`

if [ -z "$1" ]; then
 echo "usage: ./$me [version] <save>"
# ./build.sh 4.10  save
 exit 1
fi

SQ_VERS=$1
APP="squid-$SQ_VERS-x86_64-install"
DEST_DIR="$HOME/DevPkg/squid/x86_64/$APP"
SQ_DIR="/opt/kroleg/squid"
SRC="$DEST_DIR$SQ_DIR/sbin/squid"
LIB="$DEST_DIR$SQ_DIR/lib/"
EXEC=@executable_path/../lib/
RES="_resources"

get_dylibs() {
 echo `otool -L $1 | grep -E "/opt.*dylib[^:]" | awk -F' ' '{ print $1 }'`
}

# Colors
BGRED='\033[41m'
BGBLUE='\033[44m'
RED='\033[1;31m'
WHITE='\033[1;37m'
NORMAL='\033[0m'

mkdir -p $HOME/DevPkg/{squid,dmg}

set -e

#: <<'COMMENT'

if [ ! -f "squid-$SQ_VERS".tar.xz ]; then
 wget http://www.squid-cache.org/Versions/v3/3.5/"squid-$SQ_VERS".tar.xz
fi

if [ ! -d "squid-$SQ_VERS" ]; then
 tar -xvf "squid-$SQ_VERS".tar.xz

cd "squid-$SQ_VERS"

./configure \
 --prefix="$SQ_DIR" \
 --disable-auth \
 --with-krb5-config=no \
 --disable-external-acl-helpers \
 --disable-eui --enable-ssl \
 --enable-ssl-crtd \
 --with-openssl=/opt/local/lib

make all
make install DESTDIR=$DEST_DIR
cd ..
fi

#COMMENT

cp $RES/squids $DEST_DIR$SQ_DIR/sbin/
cp $RES/squid.conf $DEST_DIR$SQ_DIR/etc/
cd $DEST_DIR$SQ_DIR/etc/

openssl req -new \
 -newkey rsa:2048 -days 20000 -nodes -x509 -keyout squidCA.pem \
 -subj '/C=US/ST=Massachusetts/L=Boston/O=Kroleg, Inc./OU=IT/emailAddress=krolega@yandex.ru/CN=Squid' \
 -out squidCA.pem

openssl x509 -in squidCA.pem -outform DER -out squidCA.der

cd ..
rm -rf ./var/cache/squid/ssl_db
mkdir -p ./lib ./var/cache/squid
# http://www.squid-cache.org/Doc/config/sslcrtd_program/
./libexec/security_file_certgen -c -s ./var/cache/squid/ssl_db -M 4 MB

if [ ! -f "$SRC"  ]; then
 rm -Rf "squid-$SQ_VERS"
 echo "$WHITE$APP$RED build error $NORMAL"  
 exit 1
fi


# change dylib path in bynary and copy dylibd

fix_dylib() {
 DYLIBS=$(get_dylibs $1)

 for dylib in $DYLIBS; do
  if [ "$2" == "1" ]; then cp $dylib $LIB; fi;
  install_name_tool -change $dylib $EXEC`basename $dylib` $1;
  chmod 755 $LIB`basename $dylib`
  DYLIBS2=$(get_dylibs $dylib)

  for dylib2 in $DYLIBS2; do
   if [ "$2" == "1" ]; then cp $dylib2 $LIB; fi;
   install_name_tool -change $dylib2 $EXEC`basename $dylib2` $LIB`basename $dylib`;
   chmod 755 $LIB`basename $dylib2`

   DYLIBS3=$(get_dylibs $LIB`basename $dylib2`)
   for dylib3 in $DYLIBS3; do
    if [ "$2" == "1" ]; then cp $dylib3 $LIB; fi;
    install_name_tool -change $dylib3 $EXEC`basename $dylib3` $LIB`basename $dylib2`
    chmod 755 $LIB`basename $dylib3`
   done;
  done;
 done;
}

fix_dylib $SRC 1
fix_dylib $DEST_DIR$SQ_DIR/libexec/security_file_certgen 0

# make dmg

cd $HOME/DevPkg/squid/x86_64
source _pkgdmg/makedmg

if [ "$2" != "save" ]; then
 rm -Rf "$APP" "squid-$SQ_VERS"
fi

echo "$BGBLUE$WHITE   $APP buid completed   $NORMAL" 
