#!/bin/zsh
# Archives and packages unsigned Release IPAs for the Standard (SideStore) and
# Tunnel (paid-certificate) editions from the current checkout.
#
#   scripts/package-ipa.sh [standard|tunnel|all]
#
# The version and build come from Configuration/Version.xcconfig. Set
# OUTPUT_DIR to write somewhere other than Releases/.
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_ROOT="${SCRIPT_DIR:h}"
VERSION_FILE="${PROJECT_ROOT}/Configuration/Version.xcconfig"
OUTPUT_DIR="${OUTPUT_DIR:-${PROJECT_ROOT}/Releases}"
BUILD_DIR="${TMPDIR:-/tmp}/wrappin-package-build"
PLIST_BUDDY="/usr/libexec/PlistBuddy"

EDITION="${1:-all}"
case "${EDITION}" in
    standard|tunnel|all) ;;
    *)
        print -u2 "Usage: ${0:t} [standard|tunnel|all]"
        exit 1
        ;;
esac

setting() {
    sed -n "s/^$1[[:space:]]*=[[:space:]]*//p" "${VERSION_FILE}" | tail -n 1
}

VERSION="$(setting MARKETING_VERSION)"
BUILD="$(setting CURRENT_PROJECT_VERSION)"
if [[ -z "${VERSION}" || -z "${BUILD}" ]]; then
    print -u2 "Could not read the version and build from ${VERSION_FILE}."
    exit 1
fi

if [[ -z "${DEVELOPER_DIR:-}" ]]; then
    DEVELOPER_DIR="$(xcode-select -p)"
fi
export DEVELOPER_DIR

plist_value() {
    "${PLIST_BUDDY}" -c "Print :$2" "$1/Info.plist"
}

check_identity() {
    local bundle="$1"
    if [[ "$(plist_value "${bundle}" CFBundleShortVersionString)" != "${VERSION}" \
        || "$(plist_value "${bundle}" CFBundleVersion)" != "${BUILD}" ]]; then
        print -u2 "${bundle:t} is not ${VERSION} (Build ${BUILD})."
        exit 1
    fi
}

package() {
    local label="$1" scheme="$2" app_name="$3" has_extension="$4"
    local output="${OUTPUT_DIR}/WrapPin-${label}-${VERSION}-build${BUILD}-unsigned.ipa"
    local archive="${BUILD_DIR}/${label}.xcarchive"
    local stage="${BUILD_DIR}/${label}-stage"
    local app="${archive}/Products/Applications/${app_name}.app"
    local extension="${app}/PlugIns/WrapPinTunnel.appex"

    # A build number identifies one exact package; never replace a recorded one.
    if [[ -e "${output}" ]]; then
        print -u2 "${output} already exists. Increase CURRENT_PROJECT_VERSION in ${VERSION_FILE:t} first."
        exit 1
    fi

    rm -rf "${archive}" "${stage}"
    "${DEVELOPER_DIR}/usr/bin/xcodebuild" archive \
        -project "${PROJECT_ROOT}/WrapPin.xcodeproj" \
        -scheme "${scheme}" \
        -configuration Release \
        -destination "generic/platform=iOS" \
        -archivePath "${archive}" \
        -derivedDataPath "${BUILD_DIR}/DerivedData" \
        CODE_SIGNING_ALLOWED=NO \
        -quiet

    check_identity "${app}"
    if [[ "${has_extension}" == yes ]]; then
        check_identity "${extension}"
        local app_id="$(plist_value "${app}" CFBundleIdentifier)"
        if [[ "$(plist_value "${extension}" CFBundleIdentifier)" != "${app_id}.tunnel" ]]; then
            print -u2 "The Packet Tunnel extension ID must be ${app_id}.tunnel."
            exit 1
        fi
    elif [[ -e "${app}/PlugIns" ]]; then
        print -u2 "The Standard edition must not contain an app extension."
        exit 1
    fi

    # ditto produces the ZIP layout SideStore accepts; see Releases/README.md (1.0.8).
    mkdir -p "${stage}/Payload" "${OUTPUT_DIR}"
    ditto "${app}" "${stage}/Payload/${app_name}.app"
    ditto -c -k --norsrc --keepParent "${stage}/Payload" "${output}"
    unzip -tq "${output}" >/dev/null

    print "${output}"
    print "  $(plist_value "${app}" CFBundleIdentifier) ${VERSION} (Build ${BUILD})"
    print "  SHA-256 $(shasum -a 256 "${output}" | cut -d ' ' -f 1)"
}

mkdir -p "${BUILD_DIR}"

if [[ "${EDITION}" == standard || "${EDITION}" == all ]]; then
    package Standard "WrapPin Standard" WrapPin no
fi
if [[ "${EDITION}" == tunnel || "${EDITION}" == all ]]; then
    package Tunnel "WrapPin Tunnel" WrapPinTunnelEdition yes
fi
