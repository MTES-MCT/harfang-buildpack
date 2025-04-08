#!/bin/bash

steptxt="----->"
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m'                              # No Color
CURL="curl -L --retry 15 --retry-delay 2" # retry for up to 30 seconds

info() {
  echo -e "${GREEN}       $*${NC}"
}

warn() {
  echo -e "${YELLOW} !!    $*${NC}"
}

err() {
  echo -e "${RED} !!    $*${NC}" >&2
}

step() {
  echo "$steptxt $*"
}

start() {
  echo -n "$steptxt $*... "
}

finished() {
  echo "done"
}

function indent() {
  c='s/^/       /'
  case $(uname) in
  Darwin) sed -l "$c" ;; # mac/bsd sed: -l buffers on line boundaries
  *) sed -u "$c" ;;      # unix/gnu sed: -u unbuffered (arbitrary) chunks of data
  esac
}

function install_jq() {
  if [[ -f "${ENV_DIR}/JQ_VERSION" ]]; then
    JQ_VERSION=$(cat "${ENV_DIR}/JQ_VERSION")
  else
    JQ_VERSION=1.7.1
  fi
  step "Fetching jq $JQ_VERSION"
  if [ -f "${CACHE_DIR}/dist/jq-$JQ_VERSION" ]; then
    info "File already downloaded"
  else
    ${CURL} -o "${CACHE_DIR}/dist/jq-$JQ_VERSION" "https://github.com/stedolan/jq/releases/download/jq-$JQ_VERSION/jq-linux64"
  fi
  cp "${CACHE_DIR}/dist/jq-$JQ_VERSION" "${BUILD_DIR}/bin/jq"
  chmod +x "${BUILD_DIR}/bin/jq"
  finished
}

function install_soc() {
  if [[ -f "${ENV_DIR}/SOC_VERSION" ]]; then
    SOC_VERSION=$(cat "${ENV_DIR}/SOC_VERSION")
  else
    SOC_VERSION=4.7.18
  fi
  step "Install SOC $SOC_VERSION"
  local soc_query_url="${SOC_URL}"
  local http_code
  http_code=$($CURL -G -o "$TMP_PATH/soc.json" -w '%{http_code}' -H "accept: application/json" "${soc_query_url}" -H "PRIVATE-TOKEN: $GITLAB_API_KEY" \
   --data-urlencode "package_version=$SOC_VERSION")
  
  if [[ $http_code == 200 ]]; then
    local soc_dist
    soc_dist=$(cat "$TMP_PATH/soc.json" | jq '.[] | .binaries | .[] | .id' )
    soc_dist="${soc_dist%\"}"
    soc_dist="${soc_dist#\"}"
    local checksum_url
    checksum_url=$(cat "$TMP_PATH/soc.json" | jq '.[] | .binaries | .[] | .package.checksum_link' | xargs)
    local soc_release_name
    soc_release_name=$(cat "$TMP_PATH/soc.json" | jq '.[] | .release_name')
    soc_release_name="${soc_release_name%\"}"
    soc_release_name="${soc_release_name#\"}"
    local soc_url
    soc_url=$(cat "$TMP_PATH/soc.json" | jq '.[] | .binaries | .[] | .package.link' | xargs)
  else
    warn "Adoptium API v3 HTTP STATUS CODE: $http_code"
    local soc_release_name="jdk-17.0.9%2B99"
    info "Using by default $soc_release_name"
    local soc_dist="OpenJDK17U-soc_x64_linux_hotspot_17.0.9_9.tar.gz"
    local soc_url="${SOC_URL}/package_files/${soc_release_name}/${soc_dist}"
    local checksum_url="${soc_url}.sha256.txt"
  fi
  info "Fetching $soc_dist"
  local dist_filename="${CACHE_DIR}/dist/$soc_dist"
  if [ -f "${dist_filename}" ]; then
    info "File already downloaded"
  else
    ${CURL} -o "${dist_filename}" "${soc_url}"
  fi
  if [ -f "${dist_filename}.sha256" ]; then
    info "SOC sha256 sum already checked"
  else
    ${CURL} -o "${dist_filename}.sha256" "${checksum_url}"
    cd "${CACHE_DIR}/dist" || return
    sha256sum -c --strict --status "${dist_filename}.sha256"
    info "SOC sha256 checksum valid"
  fi
  if [ -d "${BUILD_DIR}/java" ]; then
    warn "SOC already installed"
  else
    tar xzf "${dist_filename}" -C "${CACHE_DIR}/dist"
    mv "${CACHE_DIR}/dist/$soc_release_name-soc" "$BUILD_DIR/java"
    info "SOC archive unzipped to $BUILD_DIR/java"
  fi
  export PATH=$PATH:"${BUILD_DIR}/java/bin"
  if [ ! -d "${BUILD_DIR}/.profile.d" ]; then
    mkdir -p "${BUILD_DIR}/.profile.d"
  fi
  touch "${BUILD_DIR}/.profile.d/java.sh"
  echo "export PATH=$PATH:/app/java/bin" > "${BUILD_DIR}/.profile.d/java.sh"
  info "$(java -version)"
  finished
}