#!/bin/sh

set -ex

# shellcheck disable=SC2068
version() { IFS="."; printf "%03d%03d%03d\\n" $@; unset IFS;}

minimum_go_version=1.10
current_go_version=$(go version | cut -d " " -f 3)

if [ "$(version "${current_go_version#go}")" -lt "$(version "$minimum_go_version")" ]; then
     echo "Go version should be greater or equal to $minimum_go_version"
     exit 1
fi

LAUNCH_PATH="${PWD}"
cd "$(dirname "$0")/.."

PACKAGE_PATH="$(go list -e -f '{{.Dir}}' github.com/openshift/installer)"
if test -z "${PACKAGE_PATH}"
then
	echo "build from your \${GOPATH} (${LAUNCH_PATH} is not in $(go env GOPATH))" 2>&1
	exit 1
fi

LOCAL_PATH="${PWD}"
if test "${PACKAGE_PATH}" != "${LOCAL_PATH}"
then
	echo "build from your \${GOPATH} (${PACKAGE_PATH}, not ${LAUNCH_PATH})" 2>&1
	exit 1
fi

MODE="${MODE:-release}"
GIT_COMMIT="${SOURCE_GIT_COMMIT:-$(git rev-parse --verify 'HEAD^{commit}')}"
LDFLAGS="${LDFLAGS} -X github.com/openshift/installer/pkg/version.Raw=$(git describe --always --abbrev=40 --dirty) -X github.com/openshift/installer/pkg/version.Commit=${GIT_COMMIT}"
TAGS="${TAGS:-}"
OUTPUT="${OUTPUT:-bin/openshift-install}"
export CGO_ENABLED=0

case "${MODE}" in
release)
	LDFLAGS="${LDFLAGS} -s -w"
	TAGS="${TAGS} release"
	if test "${SKIP_GENERATION}" != y
	then
		go generate ./data
	fi
	;;
dev)
	;;
*)
	echo "unrecognized mode: ${MODE}" >&2
	exit 1
esac

if (echo "${TAGS}" | grep -q 'libvirt')
then
	export CGO_ENABLED=1
fi

go build -ldflags "${LDFLAGS}" -tags "${TAGS}" -o "${OUTPUT}" ./cmd/openshift-install
