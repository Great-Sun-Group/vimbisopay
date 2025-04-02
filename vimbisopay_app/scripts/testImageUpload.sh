#!/bin/bash

# Configuration
TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJtZW1iZXJJRCI6IjFlM2QzMGMzLWQ0NDQtNDA0Ny05MTkxLTA4MmNlNTdhYTg2ZCIsImlhdCI6MTc0MzQyMDk5NiwibGFzdEFjdGl2aXR5IjoxNzQzNDIwOTk2LCJhYnNvbHV0ZUV4cGlyeSI6MTc0MzQyNDU5NiwidmVyc2lvbiI6InYxIiwiYXV0aE1ldGhvZCI6InBob25lX29ubHkifQ.OJf9x7XMAAF2-jkE8rGPB_CfVVV-zZ4MORhoFn8QlcE"
IMAGE_PATH="avatar_1.jpeg"
NAME="profile_pic"
DR_ACCOUNT_ID="2781cc65-55fd-4403-966e-cc7d6426f7f9"  # The debit account ID
CR_ACCOUNT_ID=""  # The credit account ID (optional)
CLIENT_API_KEY="gfnsrtj543dGJFDGjffDhjdyKGjugDg436vBNb"
BASE_URL="https://dev.mycredex.dev"  # Fixed: removed endpoint from base URL

# Extract member ID from JWT token
# This extracts the memberID from the JWT payload (middle part)
MEMBER_ID=$(echo $TOKEN | cut -d. -f2 | base64 -d 2>/dev/null | grep -o '"memberID":"[^"]*"' | cut -d'"' -f4)
echo "Member ID: $MEMBER_ID"

# Step 1: Upload and optimize the image
echo "Step 1: Uploading and optimizing image..."

# Convert image to base64
BASE64_IMAGE=$(base64 -i "$IMAGE_PATH")

# Create JSON payload for uploadAndOptimizeJpg
JSON_PAYLOAD=$(cat <<EOF
{
  "jpg": "$BASE64_IMAGE",
  "name": "$NAME",
  "drAccountID": "$DR_ACCOUNT_ID"
EOF
)

# Add crAccountID if provided
if [ -n "$CR_ACCOUNT_ID" ]; then
  JSON_PAYLOAD="$JSON_PAYLOAD,
  \"crAccountID\": \"$CR_ACCOUNT_ID\""
fi

# Close JSON object
JSON_PAYLOAD="$JSON_PAYLOAD
}"

# Make the request to uploadAndOptimizeJpg
echo "Sending request to $BASE_URL/uploadAndOptimizeJpg"
UPLOAD_RESPONSE=$(curl -s -X POST "$BASE_URL/uploadAndOptimizeJpg" \
  -H "Content-Type: application/json" \
  -H "x-client-api-key: $CLIENT_API_KEY" \
  -H "Authorization: Bearer $TOKEN" \
  -d "$JSON_PAYLOAD")

# Print full response for debugging
echo "Upload Response: $UPLOAD_RESPONSE"

# Extract asset IDs from the response
ORIGINAL_ASSET_ID=$(echo "$UPLOAD_RESPONSE" | grep -o '"originalAssetID":"[^"]*"' | cut -d'"' -f4)
ASSET_200_ID=$(echo "$UPLOAD_RESPONSE" | grep -o '"asset200ID":"[^"]*"' | cut -d'"' -f4)
ASSET_600_ID=$(echo "$UPLOAD_RESPONSE" | grep -o '"asset600ID":"[^"]*"' | cut -d'"' -f4)

echo "Original Asset ID: $ORIGINAL_ASSET_ID"
echo "200px Asset ID: $ASSET_200_ID"
echo "600px Asset ID: $ASSET_600_ID"

# Only proceed if we have asset IDs
if [ -z "$ORIGINAL_ASSET_ID" ] || [ -z "$ASSET_200_ID" ] || [ -z "$ASSET_600_ID" ]; then
  echo "Error: Failed to get asset IDs from upload response"
  exit 1
fi

# Step 2: Update profile pictures
echo "Step 2: Connecting images to member profile..."

# Create JSON payload for updateProfilePics (removed comment in JSON)
UPDATE_PAYLOAD=$(cat <<EOF
{
  "sourceID": "$MEMBER_ID",
  "originalAssetID": "$ORIGINAL_ASSET_ID",
  "thumbnailAssetID": "$ORIGINAL_ASSET_ID",
  "asset200ID": "$ASSET_200_ID",
  "asset600ID": "$ASSET_600_ID"
}
EOF
)

# Make the request to updateProfilePics
echo "Sending request to $BASE_URL/updateProfilePics"
UPDATE_RESPONSE=$(curl -s -X POST "$BASE_URL/updateProfilePics" \
  -H "Content-Type: application/json" \
  -H "x-client-api-key: $CLIENT_API_KEY" \
  -H "Authorization: Bearer $TOKEN" \
  -d "$UPDATE_PAYLOAD")

echo "Update Response: $UPDATE_RESPONSE"
echo "Profile picture update complete!"