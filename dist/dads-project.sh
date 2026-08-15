#!/bin/sh
printf '\033c\033]0;%s\a' dads-project
base_path="$(dirname "$(realpath "$0")")"
"$base_path/dads-project.x86_64" "$@"
