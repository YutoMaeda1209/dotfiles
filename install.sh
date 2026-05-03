#!/bin/sh
set -e

if ! command -v node > /dev/null 2>&1; then
  curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
  sudo apt-get install -y nodejs
fi

if ! command -v claude > /dev/null 2>&1; then
  npm install -g @anthropic-ai/claude-code
fi
