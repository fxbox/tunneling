#!/bin/bash

# Checking for Go
echo "Checking dependencies ..."
if hash go 2>/dev/null; then
  echo "Found GO!"
else
  echo "Missing dependency GO compiler"
  exit 1
fi
if hash go-bindata 2>/dev/null; then
  echo "Found go-bindata"
else
  echo "Missing dependency go-bindata"
  exit 2
fi

# Clean up
echo "Cleaning up ..."
rm -rf ngrok
rm -rf client
rm -rf server

DOMAIN="${NGROK_DOMAIN:=example.com}"
echo "Building custom ngrok for domain $DOMAIN"

echo "Cloning ngrok repo"
git clone https://github.com/inconshreveable/ngrok.git > /dev/null 2>&1
cd ngrok

#Apply patches
echo "Patching ngrok"
# This first patch is to change the log4go path
wget --no-check-certificate https://patch-diff.githubusercontent.com/raw/inconshreveable/ngrok/pull/308.diff > /dev/null 2>&1
git apply 308.diff > /dev/null 2>&1

#Check if we have certificates from letsencrypt
#we will check path /etc/letsencrypt/live/<domainname>
#We will need special permissions to access this directory
echo "Checking for letsencrypt certificates"
PRIVKEY="/etc/letsencrypt/live/${DOMAIN}/privkey.pem"
TRUST_CERT="false"
if [ -e "$PRIVKEY" ]; then
  echo "LetsEncrypt certificates for ${DOMAIN} found!"
  cp "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" assets/client/tls/ngrokroot.crt > /dev/null 2>&1
  CERTIFICATE="/etc/letsencrypt/live/${DOMAIN}/cert.pem"
  TRUST_CERT="true"
else
  #Create certificates
  echo "Could not find letsencrypt cerfiticates, check /etc/letsencrypt/live/${DOMAIN} is accesible"
  echo "Creating custom certificates for $DOMAIN"
  openssl genrsa -out rootCA.key 2048 > /dev/null 2>&1
  openssl req -x509 -new -nodes -key rootCA.key -subj "/CN=$DOMAIN" -days 5000 -out rootCA.pem > /dev/null 2>&1
  openssl genrsa -out device.key 2048 > /dev/null 2>&1
  openssl req -new -key device.key -subj "/CN=$DOMAIN" -out device.csr > /dev/null 2>&1
  openssl x509 -req -in device.csr -CA rootCA.pem -CAkey rootCA.key -CAcreateserial -out device.crt -days 5000 > /dev/null 2>&1
  cp rootCA.pem assets/client/tls/ngrokroot.crt > /dev/null 2>&1
  PRIVKEY="ngrok/device.key"
  CERTIFICATE="ngrok/device.crt"
fi

make clean > /dev/null 2>&1

# The server is always built for a linux target
echo "Building server ..."
GOOS="linux" GOARCH="amd64" make release-server > /dev/null 2>&1

# Check if we were asked to build an specific OS via $TUNNEL_TARGET
# otherwise detect from the current one
GOOS="darwin"
if [ -z "$TUNNEL_TARGET" ]; then
  GOOS="$TUNNEL_TARGET"
else
  platform='unknown'
  unamestr=`uname`
  if [[ "$unamestr" == 'Linux' ]]; then
     GOOS="linux"
  fi
fi

# Build the client with amd64 architecture unless overwritten
# in $TUNNEL_ARCH (for rpi use TUNNEL_ARCH=arm)
GOARCH="amd64"
if [ -z "$TUNNEL_ARCH"]; then
  GOARCH="$TUNNEL_ARCH"
fi

echo "Building client ${GOOS} for ${GOARCH} ..."
GOOS="$GOOS" GOARCH="$GOARCH" make release-client > /dev/null 2>&1

# Provide server files and client files in separate folders
cd ..
mkdir client
cp ngrok/bin/ngrok client
cat > client/config.yml << EOF
server_addr: $DOMAIN:4443
trust_host_root_certs: $TRUST_CERT
EOF

mkdir server
cp $PRIVKEY server/device.key
cp $CERTIFICATE server/device.crt
cp ngrok/bin/ngrokd server
cp ngrok/bin/linux_amd64/ngrokd server
echo -e "./ngrokd -tlsKey=device.key -tlsCrt=device.crt -domain=\"$DOMAIN\"" > server/launch.sh
chmod +x server/launch.sh

echo "Job finished, look for your client and server folders!"
