#!/bin/bash

set -e
set -o pipefail

function encrypt_file() {
    set -x
    SOPS_GPG_EXEC={GPG_BINARY} {SOPS_BINARY_PATH} -e $1 --config {SOPS_CONFIG_FILE} > $2
}

# This is expanded to calls to the above function
{ENCRYPT_FILES}
