#!/bin/bash
#
# Script: Set User and Location via Okta (v5.0)
# Author: Howard Levy
# Date: 2025-10-14
#
# Purpose:
#   - Detect logged-in user
#   - Normalize username → corporate email format
#   - Set username in Jamf via recon (triggers Okta enrichment)
#   - Run recon again for reporting
#   - Uses API token for clean authentication lifecycle
#
# Parameters:
#   $4 = Jamf Pro URL (e.g., https://companyname.jamfcloud.com)
#   $5 = API Client ID
#   $6 = API Client Secret
#
# Compatible with: macOS 15 / 26, Jamf Pro 11.9+
# ───────────────────────────────────────────────

jamfProURL="$4"
clientID="$5"
clientSecret="$6"

# ───────────────────────────────────────────────
# Detect logged-in user
# ───────────────────────────────────────────────
loggedInUser=$(stat -f "%Su" /dev/console)
if [[ "$loggedInUser" == "root" || "$loggedInUser" == "_mbsetupuser" || -z "$loggedInUser" ]]; then
    echo "⚠️ No valid user logged in. Exiting."
    exit 0
fi

# Normalize to email
if [[ "$loggedInUser" == *"@"* ]]; then
    userEmail="$loggedInUser"
else
    userEmail="${loggedInUser}@biofourmis.com"
fi

serialNumber=$(system_profiler SPHardwareDataType | awk '/Serial/ {print $4}')
echo "ℹ️ Serial: $serialNumber"
echo "ℹ️ Logged-in user: $userEmail"

# ───────────────────────────────────────────────
# Request API token
# ───────────────────────────────────────────────
echo "🔐 Requesting OAuth token..."
tokenResponse=$(curl -s -X POST "${jamfProURL}/api/oauth/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "client_id=${clientID}&client_secret=${clientSecret}&grant_type=client_credentials")

accessToken=$(echo "$tokenResponse" | /usr/bin/plutil -extract access_token raw - 2>/dev/null)
if [[ -z "$accessToken" || "$accessToken" == "null" ]]; then
    echo "❌ Failed to obtain token."
    echo "$tokenResponse"
    exit 1
fi
echo "✅ Token acquired."

# ───────────────────────────────────────────────
# Get Computer ID
# ───────────────────────────────────────────────
computerID=$(curl -s -H "Authorization: Bearer ${accessToken}" \
    "${jamfProURL}/api/v1/computers-inventory?filter=hardware.serialNumber==$serialNumber" \
    | /usr/bin/plutil -extract results.0.id raw - 2>/dev/null)

if [[ -z "$computerID" || "$computerID" == "null" ]]; then
    echo "❌ Unable to find matching computer record for serial: $serialNumber"
    exit 1
fi
echo "💻 Found Computer ID: $computerID"

# ───────────────────────────────────────────────
# Set username using recon (native)
# ───────────────────────────────────────────────
echo "🧭 Updating Jamf username via recon..."
/usr/local/bin/jamf recon -endUsername "$userEmail"

# ───────────────────────────────────────────────
# Wait briefly to allow Okta directory enrichment
# ───────────────────────────────────────────────
echo "⏳ Waiting 5 seconds for Okta enrichment..."
sleep 5

# ───────────────────────────────────────────────
# Verify the update
# ───────────────────────────────────────────────
verifyUser=$(curl -s -H "Authorization: Bearer ${accessToken}" \
    "${jamfProURL}/api/v1/computers-inventory-detail/${computerID}" \
    | /usr/bin/plutil -extract userAndLocation.username raw - 2>/dev/null)

if [[ "$verifyUser" == "$userEmail" ]]; then
    echo "✅ Verified Jamf username now set to: $verifyUser"
else
    echo "⚠️ Verification pending — enrichment may take another 30 seconds."
fi

# ───────────────────────────────────────────────
# Clean up
# ───────────────────────────────────────────────
curl -s -X POST "${jamfProURL}/api/v1/auth/invalidate-token" \
    -H "Authorization: Bearer ${accessToken}" >/dev/null

echo "✅ Completed Jamf user sync for $userEmail"
exit 0
