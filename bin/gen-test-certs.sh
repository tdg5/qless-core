#!/bin/bash

# Script adapted from https://github.com/redis/redis/blob/cc0091f0f9fe321948c544911b3ea71837cf86e3/utils/gen-test-certs.sh

# Generate some test certificates which are used by the regression test suite:
#
#   test/tls/ca.{crt,key}          Self signed CA certificate.
#   test/tls/redis.{crt,key}       A certificate with no key usage/policy restrictions.
#   test/tls/client.{crt,key}      A certificate restricted for SSL client usage.
#   test/tls/server.{crt,key}      A certificate restricted for SSL server usage.
#   test/tls/redis.dh              DH Params file.

get_repo_dir () {
  SOURCE="${BASH_SOURCE[0]}"
  # While $SOURCE is a symlink, resolve it
  while [ -h "$SOURCE" ]; do
       DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
       SOURCE="$( readlink "$SOURCE" )"
       # If $SOURCE was a relative symlink (so no "/" as prefix, need to resolve
       # it relative to the symlink base directory
       [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
  done
  DIR="$( cd -P "$( dirname "$SOURCE" )/.." && pwd )"
  echo "$DIR"
}

REPO_DIR=$(get_repo_dir)

generate_cert() {
    local name=$1
    local cn="$2"
    local opts="$3"

    local keyfile="${REPO_DIR}/test/tls/${name}.key"
    local certfile="${REPO_DIR}/test/tls/${name}.crt"

    [ -f $keyfile ] || openssl genrsa -out $keyfile 2048
    openssl req \
        -new -sha256 \
        -subj "/O=Redis Test/CN=$cn" \
        -key $keyfile | \
        openssl x509 \
            -req -sha256 \
            -CA "${REPO_DIR}/test/tls/ca.crt" \
            -CAkey "${REPO_DIR}/test/tls/ca.key" \
            -CAserial "${REPO_DIR}/test/tls/ca.txt" \
            -CAcreateserial \
            -days 365 \
            $opts \
            -out $certfile
}

mkdir -p "${REPO_DIR}/test/tls"
[ -f "${REPO_DIR}/test/tls/ca.key" ] || openssl genrsa -out "${REPO_DIR}/test/tls/ca.key" 4096
openssl req \
    -x509 -new -nodes -sha256 \
    -key "${REPO_DIR}/test/tls/ca.key" \
    -days 3650 \
    -subj '/O=Redis Test/CN=Certificate Authority' \
    -out "${REPO_DIR}/test/tls/ca.crt"

cat > "${REPO_DIR}/test/tls/openssl.cnf" <<_END_
[ server_cert ]
keyUsage = digitalSignature, keyEncipherment
nsCertType = server

[ client_cert ]
keyUsage = digitalSignature, keyEncipherment
nsCertType = client
_END_

generate_cert server "Server-only" "-extfile ${REPO_DIR}/test/tls/openssl.cnf -extensions server_cert"
generate_cert client "Client-only" "-extfile ${REPO_DIR}/test/tls/openssl.cnf -extensions client_cert"
generate_cert redis "Generic-cert"

[ -f "${REPO_DIR}/test/tls/redis.dh" ] || openssl dhparam -out "${REPO_DIR}/test/tls/redis.dh" 2048
