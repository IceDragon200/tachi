#!/usr/bin/env bash
set -euo pipefail

exec ruby -Itest -e 'Dir["test/**/*_test.rb"].sort.each { |file| require File.expand_path(file) }' "$@"
