#!/bin/bash

steptxt="----->"
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m'                              # No Color
CURL="curl -L"

info() {
  echo -e "${GREEN}       $*${NC}"
}

warn() {
  echo -e "${YELLOW} !!    $*${NC}"
}

err() {
  echo -e "${RED} !!    $*${NC}" >&2
  exit 1
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

function curl_with_auth() {
  local path="$1"
  local output="$2"
  local filename="$3"
  local curl_hurukai
  if [[ -f "${ENV_DIR}/HURUKAI_API_URL" ]]; then
  HURUKAI_API_URL=$(cat "${ENV_DIR}/HURUKAI_API_URL")
  else
    err "HURUKAI_API_URL unset or empty, unable to authenticate"
  fi
  if [[ -f "${ENV_DIR}/HURUKAI_API_TOKEN" ]]; then
    HURUKAI_API_TOKEN=$(cat "${ENV_DIR}/HURUKAI_API_TOKEN")
  else
    err "HURUKAI_API_TOKEN unset or empty, unable to authenticate"
  fi
  if [[ -f "${ENV_DIR}/HURUKAI_HLAB_TOKEN" ]]; then
    HURUKAI_HLAB_TOKEN=$(cat "${ENV_DIR}/HURUKAI_HLAB_TOKEN")
  else
    err "HURUKAI_HLAB_TOKEN unset or empty, unable to authenticate"
  fi
  if [[ -z "$filename" ]]; then
    curl_hurukai="$CURL -b \"hlab_token=$HURUKAI_HLAB_TOKEN\" -H \"Authorization: ${HURUKAI_API_TOKEN}\" -H \"accept: application/json\" -w '%{http_code}' -o $output $HURUKAI_API_URL/$path"
  else
    curl_hurukai="$CURL -b \"hlab_token=$HURUKAI_HLAB_TOKEN\" -H \"Authorization: ${HURUKAI_API_TOKEN}\" -o $output $HURUKAI_API_URL/$path?filename=$filename"
  fi
  eval "$curl_hurukai"
}

function fetch_latest_release() {
  local http_code
  local filename="agent_x64.deb"
  step "Fetches latest version"
  http_code=$(curl_with_auth "version" "${TMP_PATH}/latest_release.json")
  local latest_release_version
  if [[ $http_code == 200 ]]; then
    latest_release_version=$(< "${TMP_PATH}/latest_release.json" jq '.version')
    latest_release_version="${latest_release_version%\"}"
    latest_release_version="${latest_release_version#\"}"
    info "Latest version fetched is $latest_release_version"
  elif [[ $http_code == 401 ]]; then
   err "Error fetching latest version with http code: ${http_code}. You should renew hurukai tokens."
  else
   err "Error fetching latest version with http code: ${http_code}"
  fi
  echo "$latest_release_version"
}

function install_agent() {
  local dist_path="$1"
  local install_path="$2"
  step "Download Harfang Agent version $HARFANG_VERSION"
  local http_code
  http_code=$(curl_with_auth "installer" "$TMP_PATH/agent.json")
  if [[ $http_code == 200 ]]; then
    local fileDownloaded
    fileDownloaded=$(< "$TMP_PATH/agent.json" jq '.installers[] | select(.system == "deb64") | .fileDownloaded')
    fileDownloaded="${fileDownloaded%\"}"
    fileDownloaded="${fileDownloaded#\"}"
    local filename
    filename=$(< "$TMP_PATH/agent.json" jq '.installers[] | select(.system == "deb64") | .filename')
    filename="${filename%\"}"
    filename="${filename#\"}"
    info "filename=$filename"
    HURUKAI_ENROLLMENT_TOKEN=$(< "$TMP_PATH/agent.json" jq '.preferred_password')
    HURUKAI_ENROLLMENT_TOKEN="${HURUKAI_ENROLLMENT_TOKEN%\"}"
    HURUKAI_ENROLLMENT_TOKEN="${HURUKAI_ENROLLMENT_TOKEN#\"}"
    HURUKAI_KEY=$(< "$TMP_PATH/agent.json" jq '.key')
    HURUKAI_KEY="${HURUKAI_KEY%\"}"
    HURUKAI_KEY="${HURUKAI_KEY#\"}"
    HURUKAI_SRV_SIG_PUB=$(< "$TMP_PATH/agent.json" jq '.rust_key')
    HURUKAI_SRV_SIG_PUB="${HURUKAI_SRV_SIG_PUB%\"}"
    HURUKAI_SRV_SIG_PUB="${HURUKAI_SRV_SIG_PUB#\"}"
  elif [[ $http_code == 401 ]]; then
   err "Installer files query failed with HTTP STATUS CODE: $http_code. You should renew hurukai tokens."
  else
    err "Installer files query failed with HTTP STATUS CODE: $http_code"
  fi
  info "downloading $fileDownloaded"
  local dist_filename="${CACHE_DIR}/dist/$fileDownloaded"
  if [ -f "${dist_filename}" ]; then
    info "File ${dist_filename} already downloaded"
  else
    curl_with_auth "installer/download" "${dist_filename}" "${filename}"
  fi
  mv "${dist_filename}" "${dist_path}"
  if [[ -f "$ENV_DIR/HURUKAI_HOST" ]]; then
    HURUKAI_HOST=$(cat "$ENV_DIR/HURUKAI_HOST")
  else
    err "HURUKAI_HOST unset or empty"
  fi
  if [[ -f "$ENV_DIR/HURUKAI_PORT" ]]; then
    HURUKAI_PORT=$(cat "$ENV_DIR/HURUKAI_PORT")
  else
    err "HURUKAI_PORT unset or empty"
  fi
  if [[ -f "$ENV_DIR/HURUKAI_PROTOCOL" ]]; then
    HURUKAI_PROTOCOL=$(cat "$ENV_DIR/HURUKAI_PROTOCOL")
  else
    err "HURUKAI_PROTOCOL unset or empty"
  fi
  if [[ -z "$HURUKAI_SRV_SIG_PUB" ]]; then
    err "HURUKAI_SRV_SIG_PUB unset or empty"
  fi
  if [[ -z "$HURUKAI_KEY" ]]; then
    err "HURUKAI_KEY unset or empty"
  fi
  if [[ -z "$HURUKAI_ENROLLMENT_TOKEN" ]]; then
    err "HURUKAI_ENROLLMENT_TOKEN unset or empty"
  fi
  info "Extracting deb package ..."
  dpkg -x "${dist_path}/${fileDownloaded}" "${install_path}"
  info "Intialize agent.ini config"
  # Initialize agent.ini on first install.
  if [[ ! -z "${HURUKAI_HOST}" ]] && [[ ! -z "${HURUKAI_PORT}" ]] && [[ ! -z "${HURUKAI_SRV_SIG_PUB}" ]]; then
      hurukai_config_cmd=()

      [[ ! -z "${HURUKAI_HOST}" ]]                && hurukai_config_cmd+=("--host" "${HURUKAI_HOST}")
      [[ ! -z "${HURUKAI_PORT}" ]]                && hurukai_config_cmd+=("--port" "${HURUKAI_PORT}")
      [[ ! -z "${HURUKAI_PROTOCOL}" ]]            && hurukai_config_cmd+=("--protocol" "${HURUKAI_PROTOCOL}")
      [[ ! -z "${HURUKAI_SRV_SIG_PUB}" ]]         && hurukai_config_cmd+=("--server-signature-public" "${HURUKAI_SRV_SIG_PUB}")
      [[ ! -z "${HURUKAI_ENROLLMENT_TOKEN}" ]]    && hurukai_config_cmd+=("--enrollment-token" "${HURUKAI_ENROLLMENT_TOKEN}")
      [[ ! -z "${HURUKAI_VDI_MODE}" ]]            && hurukai_config_cmd+=("--vdi-mode" "${HURUKAI_VDI_MODE}")
      [[ ! -z "${HURUKAI_VDI_SALT}" ]]            && hurukai_config_cmd+=("--vdi-salt" "${HURUKAI_VDI_SALT}")

      [[ ! -z "${HURUKAI_PROXY_HOST}" ]]                               && hurukai_config_cmd+=("--proxy-host" "${HURUKAI_PROXY_HOST}")
      [[ ! -z "${HURUKAI_PROXY_PORT}" ]]                               && hurukai_config_cmd+=("--proxy-port" "${HURUKAI_PROXY_PORT}")
      [[ ! -z "${HURUKAI_PROXY_PROTO}" ]]                              && hurukai_config_cmd+=("--proxy-protocol" "${HURUKAI_PROXY_PROTO}")
      # Backward compat: if HURUKAI_PROXY_* are unset, fall back to PROXY_*
      [[ -z "${HURUKAI_PROXY_HOST}" ]]  && [[ ! -z "${PROXY_HOST}" ]]  && hurukai_config_cmd+=("--proxy-host" "${PROXY_HOST}")
      [[ -z "${HURUKAI_PROXY_PORT}" ]]  && [[ ! -z "${PROXY_PORT}" ]]  && hurukai_config_cmd+=("--proxy-port" "${PROXY_PORT}")
      [[ -z "${HURUKAI_PROXY_PROTO}" ]] && [[ ! -z "${PROXY_PROTO}" ]] && hurukai_config_cmd+=("--proxy-protocol" "${PROXY_PROTO}")
      # Backward compat: if HURUKAI_ENROLLMENT_TOKEN is unset, fall back to HURUKAI_PASSWORD
      [[ -z "${HURUKAI_ENROLLMENT_TOKEN}" ]] && [[ ! -z "${HURUKAI_PASSWORD}" ]] && hurukai_config_cmd+=("--enrollment-token" "${HURUKAI_PASSWORD}")

      hurukai_config_cmd+=("--additional-info" "${HURUKAI_ADDITIONAL_INFO1}")
      hurukai_config_cmd+=("--additional-info" "${HURUKAI_ADDITIONAL_INFO2}")
      hurukai_config_cmd+=("--additional-info" "${HURUKAI_ADDITIONAL_INFO3}")
      hurukai_config_cmd+=("--additional-info" "${HURUKAI_ADDITIONAL_INFO4}")

      "${install_path}/opt/hurukai-agent/bin/hurukai" --hierarchical-root-dir="${install_path}/opt/hurukai-agent" --create-config  --update-method=deb "${hurukai_config_cmd[@]}" &> /dev/null || (
          echo "    > Warning: failed to write the agent's configuration." > /dev/stderr
          echo "    > See the agent's log in \"\${install_path}/opt/hurukai-agent/logs/\" for more information." > /dev/stderr
          return
      )
  fi
  info "Harfang agent installed"
  finished
}