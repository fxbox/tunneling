#!/bin/bash

# Clean up
rm -rf ngrok
rm -rf client
rm -rf server

DOMAIN="${NGROK_DOMAIN:=example.com}"
git clone https://github.com/inconshreveable/ngrok.git
cd ngrok

#Apply patches
wget https://patch-diff.githubusercontent.com/raw/inconshreveable/ngrok/pull/308.diff
git apply 308.diff

openssl genrsa -out rootCA.key 2048
openssl req -x509 -new -nodes -key rootCA.key -subj "/CN=$DOMAIN" -days 5000 -out rootCA.pem
openssl genrsa -out device.key 2048
openssl req -new -key device.key -subj "/CN=$DOMAIN" -out device.csr
openssl x509 -req -in device.csr -CA rootCA.pem -CAkey rootCA.key -CAcreateserial -out device.crt -days 5000

cp rootCA.pem assets/client/tls/ngrokroot.crt
make clean

# The server is always built for a linux target
GOOS="linux" GOARCH="amd64" make release-server

# Check if we were asked to build an specific OS via $TUNNEL_TARGET
# otherwise detect from the current one
GOOS="darwin"
if [ -z "$TUNNEL_TARGET" ]; then
  GOOS=$TUNNEL_TARGET
else
  platform='unknown'
  unamestr=`uname`
  if [[ "$unamestr" == 'Linux' ]]; then
     GOOS="linux"
  fi
fi

# Build the client with arm64 architecture unless overwritten
# in $TUNNEL_ARCH
GOARCH="amd64"
if [ -z "$TUNNEL_ARCH"]; then
  GOARCH="$TUNNEL_ARCH"
fi

GOOS="$GOOS" GOARCH="$GOARCH" make release-client

# Provide server files and client files in separate folders
cd ..
mkdir client
cp ngrok/bin/ngrok client
cat > client/config.yml << EOF
server_addr: $DOMAIN:4443
trust_host_root_certs: false
EOF

mkdir server
cp ngrok/device.key server
cp ngrok/device.crt server
cp ngrok/bin/linux_amd64/ngrokd server
echo -e "./ngrokd -tlsKey=device.key -tlsCrt=device.crt -domain=\"$DOMAIN\"" > server/launch.sh
chmod +x server/launch.sh
