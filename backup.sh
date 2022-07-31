#! /usr/bin/env bash

set -euo pipefail

BASE=${BASE:-"/root/backup-script"}

source "${BASE}/.env"

SERVER=${SERVER:-"192.168.0.10"}
REMOTE_USER=${REMOTE_USER:-"david"}
SHARES=${SHARES:-"Data Data_2"}
MAILJET_URL="https://api.mailjet.com/v3.1/send"
EMAIL_NAME=${EMAIL_NAME:-"$(hostname -f)"}

function sendMailForShare() {
  local share="${1}"

  curl  -s \
        -XPOST \
        -u"${MAILJET_API_KEY}:${MAILJET_API_SECRET}" \
        -H'Content-Type: application/json' \
        -d"$(mailContentForShare "${share}")" \
        "${MAILJET_URL}"
}

function mailContentForShare() {
  local share="${1}"

  cat <<EOF
{
  "Messages": [
    {
      "From": {
        "Email": "${EMAIL_ADDRESS}",
        "Name": "${EMAIL_NAME}"
      },
      "To": [
        {
          "Email": "${EMAIL_ADDRESS}",
          "Name": "${EMAIL_NAME}"
        }
      ],
      "Subject": "Backup complete for ${share}",
      "TextPart": "$(sed -z -e 's/\n/\\n/g' -e 's/\r//g' "$(localPath "${share}")/.rsync.output")"
    }
  ]
}
EOF
}

function mountShare() {
  local share="${1}"

  mount -t fuse.sshfs \
        "${REMOTE_USER}@${SERVER}:/media/${REMOTE_USER}/${share}" \
        -o ro \
        -o uid=david \
        "$(mountPath "${share}")"
}

function unmountShare() {
  local share="${1}"

  umount "$(mountPath "${share}")"
}

function backupShare() {
  local share="${1}"

  rsync -avHP --delete --exclude-from "$(mountPath "${share}")/.rsyncignore" "$(mountPath "${share}")/" "$(localPath "${share}")" | tee "$(localPath "${share}")/.rsync.output"
}

function mountPath() { echo "/mnt/${SERVER}/${1}"; }
function localPath() { echo "/srv/${SERVER}/${1}"; }

function run() {
  for share in ${SHARES}; do
    mkdir -p "$(localPath "${share}")" "$(mountPath "${share}")"

    mountShare "${share}"
    backupShare "${share}"
    unmountShare "${share}"
    sendMailForShare "${share}"
  done
}

run
