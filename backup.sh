#! /usr/bin/env bash

set -euo pipefail

BASE=${BASE:-"/root/backup-script"}

source "${BASE}/.env"

CIFS_SERVER=${CIFS_SERVER:-"192.168.1.200"}
CIFS_SHARES=${CIFS_SHARES:-"${CIFS_SERVER}/D ${CIFS_SERVER}/E"}
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
      "TextPart": "$(sed -z 's/\n/\\n/g' "$(localPath "${share}")/.rsync.output")"
    }
  ]
}
EOF
}

function mountShare() {
  local share="${1}"

  mount -t cifs \
        //${share} \
        -o username=${CIFS_USERNAME} \
        -o password=${CIFS_PASSWORD} \
        -o ro \
        -o uid=david \
        -o file_mode=0644 \
        -o dir_mode=0755 \
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

function mountPath() { echo "/mnt/${1}"; }
function localPath() { echo "/srv/${1}"; }

function run() {
  for share in ${CIFS_SHARES}; do
    mkdir -p "$(localPath "${share}")" "$(mountPath "${share}")"

    mountShare "${share}"
    backupShare "${share}"
    unmountShare "${share}"
    sendMailForShare "${share}"
  done
}

run
