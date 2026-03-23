#!/bin/bash
set -euo pipefail

./build.sh >/tmp/autodev_feature_build.log 2>&1

./kdx examples/while_return.kdx -S -o /tmp/autodev_while_return.s
test -f /tmp/autodev_while_return.s

./kdx examples/if_chain.kdx -S -o /tmp/autodev_if_chain.s
test -f /tmp/autodev_if_chain.s

./test.sh >/tmp/autodev_feature_test.log 2>&1
