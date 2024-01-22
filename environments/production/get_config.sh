#!/bin/sh
# We dont actully need the environment
# environment=$1
set -ue
PATH=/usr/bin:/bin

script_dir=$(dirname "$(realpath "$0")")
repo_dir=$(realpath "${script_dir}/../../.git")
# %cN normalizes the committer using .mailmap
git --git-dir "${repo_dir}" log -1 --pretty='(%h) %cN - %s'
