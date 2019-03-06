#!/usr/bin/env bash
# vim: set expandtab sw=4 ts=4:

## This little script accompanies a go mod uber repo, that is, a Git repo that aggregates modules pertaining
## to a single project linearly through git submodules.

set -euo pipefail
IFS=$'\n'

org="libp2p"

## Load all subdirectories siblings of this script.
mods=()
while IFS='' read -r line; do mods+=("$line"); done < \
    <(find "$(dirname "${0}")" -mindepth 1 -maxdepth 1 -type d -not -name '.*' -exec basename {} ';' | sort)

## Edits a module gomod. Args:
##  $1: module to edit
##  $2: array of flags to go mod edit
edit_mod() {
    local mod="${1}"
    shift
    local flags=("$@")
    go mod edit "${flags[@]}" "$mod/go.mod"
    echo $mod
}

do_local() {
    local flags=()
    for mod in "${mods[@]}"; do
        flags+=("-replace=github.com/$org/$mod=../$mod")
    done
    for i in "${!mods[@]}"; do
        local rep=("${flags[@]}")
        unset 'rep['"$i"']'
        rep=("${rep[@]}")

        edit_mod "${mods[$i]}" "${rep[@]}"
    done
}

do_remote() {
    local flags=()
    for mod in "${mods[@]}"; do
        flags+=("-dropreplace=github.com/$org/$mod")
    done
    for i in "${!mods[@]}"; do
        local rep=("${flags[@]}")
        unset 'rep['"$i"']'
        rep=("${rep[@]}")

        edit_mod "${mods[$i]}" "${rep[@]}"
    done
}

do_refresh() {
    cd "$(dirname "${0}")"
    echo "::: Stashing all changes :::"
    git submodule foreach git stash

    echo "::: Updating all submodules from origin :::"
    exec 3>&1
    if ! git submodule update --jobs 10 --remote 1>&3 2>&3; then
        echo "WARN: upgrade git for faster submodule updates from origin"
        git submodule update --remote
    fi

    echo "::: Checking out master on all submodules :::"
    git submodule foreach git checkout master
    echo "Done"
}

print_usage() {
    echo "Usage: $0 {local|remote|master}" >&2
    echo
    echo "  local       adds \`replace\` directives to all go.mod files to make $org dependencies point to the local workspace"
    echo "  remote      removes the \`replace\` directives introduced by \`local\`"
    echo "  refresh     refreshes all submodules from origin/master, stashing all local changes first, then checking out master"
    echo ""
}

if [[ -z ${1:-} ]]; then
    print_usage
    exit 1
fi

case "$1" in
    local) do_local ;;
    remote) do_remote ;;
    refresh) do_refresh ;;
    *) print_usage; exit 1; ;;
esac