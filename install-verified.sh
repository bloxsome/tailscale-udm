#!/bin/sh
set -e

# Tailscale-UDM Verified Installer
# This script downloads and installs Tailscale-UDM with cryptographic hash verification
# to protect against supply chain attacks and package tampering.

# Colors for output (if terminal supports it)
if [ -t 1 ]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  NC='\033[0m' # No Color
else
  RED=''
  GREEN=''
  YELLOW=''
  NC=''
fi

# Logging functions
log_info() {
  printf "${GREEN}[INFO]${NC} %s\n" "$1"
}

log_warn() {
  printf "${YELLOW}[WARN]${NC} %s\n" "$1"
}

log_error() {
  printf "${RED}[ERROR]${NC} %s\n" "$1" >&2
}

log_fatal() {
  log_error "$1"
  exit 1
}

# Configuration
GITHUB_REPO="${GITHUB_REPO:-bloxsome/tailscale-udm}"
VERSION="${1:-latest}"

log_info "Tailscale-UDM Verified Installer"
log_info "Repository: $GITHUB_REPO"
log_info "Version: $VERSION"
echo ""

# Validate GitHub repo format
if ! echo "$GITHUB_REPO" | grep -qE '^[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+$'; then
  log_fatal "Invalid GITHUB_REPO format. Expected: username/repo"
fi

# Setup temporary directory
WORKDIR="$(mktemp -d || exit 1)"
trap 'rm -rf ${WORKDIR}' EXIT

log_info "Created temporary directory: $WORKDIR"

# Determine package URL and manifest URL
if [ "${VERSION}" = "latest" ]; then
  MANIFEST_URL="https://github.com/${GITHUB_REPO}/releases/latest/download/latest.json"
  log_info "Fetching latest release manifest..."
else
  MANIFEST_URL="https://github.com/${GITHUB_REPO}/releases/download/${VERSION}/latest.json"
  log_info "Fetching release manifest for version: $VERSION"
fi

# Download manifest
if ! curl -sSLf --ipv4 -o "${WORKDIR}/latest.json" "$MANIFEST_URL"; then
  log_fatal "Failed to download release manifest from: $MANIFEST_URL"
fi

log_info "✓ Manifest downloaded successfully"

# Parse manifest using POSIX-compatible method
PACKAGE_URL=$(grep -o '"download_url": *"[^"]*"' "${WORKDIR}/latest.json" | sed 's/"download_url": *"\([^"]*\)"/\1/')
EXPECTED_SHA256=$(grep -o '"sha256": *"[^"]*"' "${WORKDIR}/latest.json" | sed 's/"sha256": *"\([^"]*\)"/\1/')
PACKAGE_VERSION=$(grep -o '"version": *"[^"]*"' "${WORKDIR}/latest.json" | sed 's/"version": *"\([^"]*\)"/\1/')
BUILD_NUMBER=$(grep -o '"build_number": *"[^"]*"' "${WORKDIR}/latest.json" | sed 's/"build_number": *"\([^"]*\)"/\1/')

if [ -z "$PACKAGE_URL" ] || [ -z "$EXPECTED_SHA256" ]; then
  log_fatal "Failed to parse manifest. Invalid JSON format."
fi

echo ""
log_info "Package details:"
log_info "  Version: $PACKAGE_VERSION (Build: $BUILD_NUMBER)"
log_info "  URL: $PACKAGE_URL"
log_info "  Expected SHA256: $EXPECTED_SHA256"
echo ""

# Download the package
log_info "Downloading package..."
if ! curl -sSLf --ipv4 -o "${WORKDIR}/tailscale-udm.tgz" "$PACKAGE_URL"; then
  log_fatal "Failed to download package from: $PACKAGE_URL"
fi

log_info "✓ Package downloaded successfully"

# Compute SHA256 hash of downloaded package
log_info "Computing SHA256 hash of downloaded package..."
COMPUTED_SHA256=$(sha256sum "${WORKDIR}/tailscale-udm.tgz" | awk '{print $1}')

log_info "  Computed: $COMPUTED_SHA256"
log_info "  Expected: $EXPECTED_SHA256"
echo ""

# Verify hash
if [ "$COMPUTED_SHA256" != "$EXPECTED_SHA256" ]; then
  log_error "═══════════════════════════════════════════════════════════"
  log_error "  HASH VERIFICATION FAILED - PACKAGE REJECTED"
  log_error "═══════════════════════════════════════════════════════════"
  log_error ""
  log_error "The downloaded package's SHA256 hash does NOT match the"
  log_error "expected hash from the release manifest. This could indicate:"
  log_error ""
  log_error "  • Package tampering or corruption"
  log_error "  • Man-in-the-middle attack"
  log_error "  • Incomplete download"
  log_error "  • Repository compromise"
  log_error ""
  log_error "Expected: $EXPECTED_SHA256"
  log_error "Computed: $COMPUTED_SHA256"
  log_error ""
  log_error "Installation has been ABORTED for your safety."
  log_error "═══════════════════════════════════════════════════════════"
  exit 1
fi

log_info "✓✓✓ HASH VERIFICATION PASSED ✓✓✓"
log_info "Package integrity confirmed. Proceeding with installation..."
echo ""

# Detect UniFi OS version
log_info "Detecting UniFi OS version..."

if [ -x "$(which ubnt-device-info)" ]; then
  OS_VERSION="${FW_VERSION:-$(ubnt-device-info firmware_detail | grep -oE '^[0-9]+')}"
elif [ -f "/usr/lib/version" ]; then
  # UCKP == Unifi CloudKey Gen2 Plus
  # UCKG2 == UniFi CloudKey Gen2
  # UNASPRO == Unas Pro
  # UNAS == Unas
  if [ "$(grep -c '^UCKP.*\.v[0-9]\.' /usr/lib/version)" = '1' ]; then
    OS_VERSION="$(sed -e 's/UCKP.*.v\(.\)\..*/\1/' /usr/lib/version)"
  elif [ "$(grep -c '^UCKG2.*\.v[0-9]\.' /usr/lib/version)" = '1' ]; then
    OS_VERSION="$(sed -e 's/UCKG2.*.v\(.\)\..*/\1/' /usr/lib/version)"
  elif [ "$(grep -c '^UNASPRO.*\.v[0-9]\.' /usr/lib/version)" = '1' ]; then
    OS_VERSION="$(sed -e 's/UNASPRO.*.v\(.\)\..*/\1/' /usr/lib/version)"
  elif [ "$(grep -c '^UNAS.*\.v[0-9]\.' /usr/lib/version)" = '1' ]; then
    OS_VERSION="$(sed -e 's/UNAS.*.v\(.\)\..*/\1/' /usr/lib/version)"
  else
    log_error "Could not detect OS Version. /usr/lib/version contains:"
    cat /usr/lib/version
    exit 1
  fi
else
  log_fatal "Could not detect OS Version. No ubnt-device-info, no version file."
fi

# Determine installation path based on OS version
if [ "$OS_VERSION" = '1' ]; then
  export PACKAGE_ROOT="/mnt/data/tailscale"
  log_info "Detected UniFi OS 1.x - Installing to: $PACKAGE_ROOT"
else
  export PACKAGE_ROOT="/data/tailscale"
  log_info "Detected UniFi OS ${OS_VERSION}.x - Installing to: $PACKAGE_ROOT"
fi

echo ""
log_info "Extracting verified package..."

# Extract the package
tar xzf "${WORKDIR}/tailscale-udm.tgz" -C "$(dirname -- "${PACKAGE_ROOT}")"

log_info "✓ Package extracted successfully"

# Update tailscale-env with modified values if specified
if [ -n "${TAILSCALED_FLAGS:-}" ]; then
  log_info "Applying custom TAILSCALED_FLAGS: $TAILSCALED_FLAGS"
  echo "TAILSCALED_FLAGS=\"${TAILSCALED_FLAGS}\"" >> "$PACKAGE_ROOT/tailscale-env"
fi

echo ""
log_info "Running Tailscale installation..."

# Run the setup script to ensure that Tailscale is installed
if ! "$PACKAGE_ROOT/manage.sh" install "${TAILSCALE_VERSION:-}"; then
  log_fatal "Installation failed. Check the logs above for errors."
fi

log_info "✓ Tailscale installed successfully"

echo ""
log_info "Starting Tailscale daemon..."

# Start the tailscaled daemon
if ! "$PACKAGE_ROOT/manage.sh" start; then
  log_fatal "Failed to start Tailscale daemon. Check the logs above for errors."
fi

log_info "✓ Tailscale daemon started successfully"

echo ""
log_info "═══════════════════════════════════════════════════════════"
log_info "  INSTALLATION COMPLETE"
log_info "═══════════════════════════════════════════════════════════"
log_info ""
log_info "Tailscale-UDM has been successfully installed and verified!"
log_info ""
log_info "Version: $PACKAGE_VERSION (Build: $BUILD_NUMBER)"
log_info "Location: $PACKAGE_ROOT"
log_info "Hash: $COMPUTED_SHA256"
log_info ""
log_info "Next steps:"
log_info "  1. Run: $PACKAGE_ROOT/manage.sh auth"
log_info "  2. Follow the authentication link to connect your device"
log_info ""
log_info "For help: $PACKAGE_ROOT/manage.sh help"
log_info "═══════════════════════════════════════════════════════════"
