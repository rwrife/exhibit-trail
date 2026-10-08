#!/usr/bin/env bash
# Zero-network gate (issue #1, binding project contract).
#
# Exhibit Trail is zero-network BY CONSTRUCTION: the app and the domain
# package must never use network APIs. The allowlist is intentionally
# EMPTY — any match in scanned sources fails the build.
#
# The scan covers both explicit network stacks (URLSession / Network /
# CFNetwork / raw sockets) and the loader shortcuts that reach the network
# without naming one: URL(string:) construction, URLComponents, AsyncImage,
# WKWebView, and remote-capable frameworks (WebKit, CloudKit, MapKit,
# NetworkExtension, CoreLocation, CoreBluetooth). Local-only file access
# must use explicit file URLs with bounded FileHandle reads (see PLAN.md),
# never URL(string:).
#
# Scanned roots: ExhibitTrail/ (app sources) and Packages/*/Sources/.
set -euo pipefail

cd "$(dirname "$0")/.."

ROOTS=("ExhibitTrail" "Packages")
ALLOWLIST=()   # empty by design; extend only with explicit user sign-off

PATTERNS=(
  '\bURLSession\b'
  '\bURLSessionConfiguration\b'
  '\bURLRequest\b'
  '\bURLResponse\b'
  '\bURLProtocol\b'
  '\bNSURLConnection\b'
  '\bNSURLSession\b'
  '\bNWConnection\b'
  '\bNWListener\b'
  '\bNWConnectionGroup\b'
  '\bNWBrowser\b'
  '\bNetService\b'
  '\bCFNetwork\b'
  '\bCFHTTPMessage\b'
  '\bCFStreamCreatePairWithSocketToHost\b'
  '\bCFReadStreamCreateForHTTPRequest\b'
  '\bimport[[:space:]]+Network\b'
  '\bCFStream\b'
  '\bCFSocket\b'
  '\bCocoaHTTPServer\b'
  '\bWebSocket\b'
  '\bgetaddrinfo\b'
  '\bgethostbyname\b'
  '\bgethostbyaddr\b'
  '\bsocket[[:space:]]*\('
  '\bconnect[[:space:]]*\('
  '\blisten[[:space:]]*\('
  '\bbind[[:space:]]*\('
  '\baccept[[:space:]]*\('
  '\bStream[[:space:]]*\.[[:space:]]*(getStreamsToHost|socketPair)\b'
		# Remote-capable loaders are prohibited at the source boundary so the
		# zero-network contract cannot be bypassed by a URL-string shortcut.
		# ponytail: ceiling — local owned-file loading must use bounded
		# FileHandle.read(upToCount:) (PLAN.md). Upgrade path: a file-URL-only
		# exemption, added only with explicit user sign-off.
		'\bcontentsOf[[:space:]]*:'
  '\bURL[[:space:]]*\([[:space:]]*(string|dataRepresentation)[[:space:]]*:'
  '\bNSURL[[:space:]]*\('
  '\bhttps?://'
  '\bimport[[:space:]]+(Darwin|Glibc)\b'
  '\bURLComponents\b'
  '\bAsyncImage\b'
  '\bWKWebView\b'
  '\bWKWebsiteDataStore\b'
  '\bAVPlayer(Link)?\b'
  '\bAVQueuePlayer\b'
  '\bAVPlayerItem\b'
  '\bAVURLAsset\b'
  '\bAVAsset\b'
  '\bAVAssetResourceLoader\b'
  # The skeleton needs no media framework; AVFoundation's URL-based assets are
  # remote-capable, so the framework is rejected outright. Re-admitting it
  # requires explicit user sign-off plus a file-only URL boundary (PLAN.md).
  '\bimport[[:space:]]+AVFoundation\b'
  '\bimport[[:space:]]+(WebKit|CloudKit|MapKit|NetworkExtension|CoreLocation|CoreBluetooth)\b'
)

matches=""
for root in "${ROOTS[@]}"; do
  [ -d "$root" ] || continue
  for pat in "${PATTERNS[@]}"; do
    hits=$(grep -RnE --exclude-dir=.build --include='*.swift' --include='*.h' --include='*.m' --include='*.c' \
      "$pat" "$root" 2>/dev/null || true)
    [ -n "$hits" ] && matches+="${hits}"$'\n'
  done
done

# Filter allowlisted lines (exact substring match against allowlist entries)
if [ -n "$matches" ]; then
  filtered=""
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    skip=0
    for a in ${ALLOWLIST[@]+"${ALLOWLIST[@]}"}; do
      [[ "$line" == *"$a"* ]] && { skip=1; break; }
    done
    [ "$skip" -eq 0 ] && filtered+="$line"$'\n'
  done <<< "$matches"
  if [ -n "$filtered" ]; then
    echo "ZERO-NETWORK GATE FAILED — network-capable API usage found (allowlist is empty):"
    printf '%s' "$filtered"
    exit 1
  fi
fi

echo "Zero-network gate: PASS (empty allowlist, no network API usage found)"
