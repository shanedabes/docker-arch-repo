#!/usr/bin/env bash

usage() {
    echo "Usage: $0"
    echo "Required environment variables:"
    echo "  ARCH_REPO_REFRESH_TIMES: space separated list of times to run builds in HH:MM format"
    echo "  ARCH_REPO_GIT_URL:       git repo containing PKGBUILD files"
    echo "Optional environment variables:"
    echo "  ARCH_REPO_NAME:          name of repo, defaults to \"repo\""
}

check_env() {
    if [[ -z "${!1}" ]]; then
        echo "Error: ${1} must be set" >&2
        echo
        usage >&2
        exit 1
    fi
}

check_env ARCH_REPO_REFRESH_TIMES
check_env ARCH_REPO_GIT_URL

read -r -a REPO_REFRESH_TIMES <<< "${ARCH_REPO_REFRESH_TIMES}"

for t in ${ARCH_REPO_REFRESH_TIMES[*]}; do
    if ! date --date="${t}" >/dev/null 2>&1; then
        echo "Error: ${t} is not a valid time format"
        exit 1
    fi
done

if [ ! -f /repo/repo.db.tar.gz ]; then
    echo "==> Initialising repo"
    repo-add /repo/repo.db.tar.gz
fi

if [ -n "${ARCH_REPO_NAME}" ]; then
    ln -sf /repo/repo.db.tar.gz "/repo/${ARCH_REPO_NAME}.db.tar.gz"
fi

if [ ! -d /git/.git ]; then
    echo "==> Cloning git repo"
    git clone "${ARCH_REPO_GIT_URL}" /git
fi

cd /git || {
    echo "Error: couldn't cd to repo directory" >&2
    exit 1
}

build() {
    echo "==> Update pacman database files"
    sudo pacman -Sy

    echo "==> Updating git repo"
    git pull --no-rebase 

    # Generate SRCINFO files for updated packages and git packages
    find . -name PKGBUILD -execdir sh -c 'echo "==> Generating ${PWD##*/} SRCINFO file"; makepkg --printsrcinfo > .SRCINFO' \;

    echo "==> Generating dependency graph"
    aur graph /git/*/.SRCINFO | tsort | tac > queue

    echo "==> Starting build"
    aur build -a queue --root /repo -d repo -srn

    echo "==> Cleaning pkgbuild repo"
    git clean -d -f -- *[^git]
    git checkout .

    paccache -r -k 1
}

while sleep 60; do
    if [ -f /app/force ]; then
        echo "==> Build forced by /app/force file"
        build

        rm /app/force
        continue
    fi

    NOW="$(date +%H:%M)"
    for t in ${REPO_REFRESH_TIMES[*]}; do
        if [[ "${NOW}" == "${t}" ]]; then
            build
        fi
    done
done
