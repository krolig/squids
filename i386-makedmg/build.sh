#!/bin/sh

# install_name_tool -change old new file

#   ⃝ Kroleg, 2019

me=`basename "$0"`

if [ -z "$1" ]; then
 echo "usage: ./$me [version] <save>"
# ./build.sh 4.8.15 ncurses save
 exit 1
fi

SQ_VERS=$1
APP="squid-$SQ_VERS-i386-install"
DEST_DIR="$HOME/DevPkg/squid/i386-makedmg/$APP"
SQ_DIR="/opt/kroleg/squid"
SRC="$DEST_DIR$SQ_DIR/sbin/squid"
LIB="$DEST_DIR$SQ_DIR/lib/"
EXEC=@executable_path/../lib/
# EXEC="$SQ_DIR/lib/"
RES="_resources"
isysRootSDK="/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.5.sdk"


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
fi

cd "squid-$SQ_VERS"

# export MACOSX_DEPLOYMENT_TARGET=10.5

./configure --prefix="$SQ_DIR" \
 --disable-auth \
 --with-krb5-config=no \
 --disable-external-acl-helpers \
 --disable-eui \
 --enable-ssl \
 --enable-ssl-crtd \
 --with-openssl=/opt/local \
 --with-default-user=nobody \
 CC="gcc -arch i386 -mmacosx-version-min=10.5" \
 CXX="g++ -arch i386 -mmacosx-version-min=10.5" \
 CPP="gcc -E" \
 CXXCPP="g++ -E"


# --host=i386-apple-darwin
# CC="gcc -arch i386 -mmacosx-version-min=10.5" \
# CXX="g++ -arch i386 -mmacosx-version-min=10.5" \

# CFLAGS="-g -O2 -mmacosx-version-min=10.5 -isysroot $isysRootSDK -arch i386" \
# CXXFLAGS="-g -O2 -mmacosx-version-min=10.5 -isysroot $isysRootSDK -arch i386" 


# --without-gnutls \
# CC="gcc -arch i386" \
# CXX="g++ -arch i386"


# --without-gnutls \
# CC="gcc -arch i386 -arch ppc" \
# CXX="g++ -arch i386 -arch ppc" \
# CPP="gcc -E" \
# CXXCPP="g++ -E"

# CC="gcc-4.9.4" \
# CFLAGS="-g -O2 -mmacosx-version-min=10.5 -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.5.sdk -arch i386" \
# CXXFLAGS="-g -O2 -mmacosx-version-min=10.5 -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.5.sdk -arch i386" \
# CXX="g++-4.9.4"

make all
# CFLAGS="-isysroot $isysRootSDK -arch i386" \
#     LDFLAGS="-isysroot $isysRootSDK -arch i386"

make install DESTDIR=$DEST_DIR
cd ..
#fi

cp $RES/squids $DEST_DIR$SQ_DIR/sbin/
cp $RES/squid.conf $DEST_DIR$SQ_DIR/etc/
cd $DEST_DIR$SQ_DIR/etc/

openssl req -new \
 -newkey rsa:2048 -days 20000 -nodes -x509 -keyout squidCA.pem \
 -subj '/C=US/ST=Massachusetts/L=Boston/O=Kroleg, Inc./OU=IT/emailAddress=krolega@yandex.ru/CN=Squid' \
 -out squidCA.pem

openssl x509 -in squidCA.pem -outform DER -out squidCA.der

cd ..
rm -rf ./var/lib/ssl_db
mkdir -p ./lib ./var/lib
./libexec/ssl_crtd -c -s ./var/lib/ssl_db

if [ ! -f "$SRC"  ]; then
 rm -Rf "squid-$SQ_VERS"
 echo "$WHITE$APP$RED build error $NORMAL"  
 exit 1
fi


#cd $DEST_DIR/opt/kroleg/squid

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

cd $HOME/DevPkg/squid/i386-makedmg
cp $RES/lib/* $DEST_DIR$SQ_DIR/lib/

fix_dylib $SRC 0
fix_dylib $DEST_DIR$SQ_DIR/libexec/ssl_crtd 0

# make dmg

#COMMENT

source _pkgdmg/makedmg

if [ "$2" != "save" ]; then
 rm -Rf "$APP" "squid-$SQ_VERS"
fi

echo "$BGBLUE$WHITE   $APP buid completed   $NORMAL" 
