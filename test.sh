#!/bin/bash

set -x

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd $SCRIPT_DIR

SSH_PORT=${1:-2222}

automotive-image-runner --ssh-port $SSH_PORT --nographics *.img > /dev/null &
pid_runner=$!
jobs -p
echo "VM running at pid: $pid_runner"

echo "Waiting for the VM to start"
set +x
while true;do for s in / - \\ \|; do printf "\r$s";sleep 1;done;done &
sleep 10
kill $!; trap 'kill $!' SIGTERM
echo done
set -x

sshpass -ppassword ssh -o " UserKnownHostsFile=/dev/null" \
    -o "StrictHostKeyChecking no" \
    -o "PubkeyAuthentication=no" \
    -p $SSH_PORT \
    root@localhost \
    'rpm -q vim-enhanced'
success=$?

kill -9 $pid_runner
ps aux | grep "hostfwd=tcp::$SSH_PORT-:22" |head -n -1 | awk '{ print $2 }' |xargs kill -9

exit $success
