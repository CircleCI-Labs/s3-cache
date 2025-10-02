#!/bin/bash

# Function to process cache key with variable interpolation and checksum evaluation
process_cache_key() {
  local key="$1"
  
  # First, evaluate environment variables (e.g., ${CIRCLE_PROJECT_REPONAME})
  # Using eval to expand environment variables in the string
  key=$(eval echo "$key")
  
  # Process checksum functions: {{ checksum "filename" }}
  while [[ "$key" =~ \{\{[[:space:]]*checksum[[:space:]]+\"([^\"]+)\"[[:space:]]*\}\} ]]; do
    local file="${BASH_REMATCH[1]}"
    local checksum_value=""
    
    if [ -f "$file" ]; then
      # Calculate SHA256 checksum of the file
      if command -v sha256sum &> /dev/null; then
        checksum_value=$(sha256sum "$file" | awk '{print $1}')
      elif command -v shasum &> /dev/null; then
        checksum_value=$(shasum -a 256 "$file" | awk '{print $1}')
      else
        echo "Warning: Neither sha256sum nor shasum found. Using md5."
        if command -v md5sum &> /dev/null; then
          checksum_value=$(md5sum "$file" | awk '{print $1}')
        elif command -v md5 &> /dev/null; then
          checksum_value=$(md5 -q "$file")
        else
          echo "Error: No checksum utility found."
          exit 1
        fi
      fi
    else
      echo "Warning: File '$file' not found for checksum. Using 'missing' as value."
      checksum_value="missing"
    fi
    
    # Replace the checksum pattern with the actual checksum value
    key="${key//\{\{ checksum \"$file\" \}\}/$checksum_value}"
    key="${key//\{\{checksum \"$file\"\}\}/$checksum_value}"
    # Handle various spacing variations
    key=$(echo "$key" | sed -E "s/\{\{[[:space:]]*checksum[[:space:]]+\"$(echo "$file" | sed 's/[\/&]/\\&/g')\"[[:space:]]*\}\}/$checksum_value/g")
  done
  
  echo "$key"
}

echo "Original Cache Key: $CACHE_KEY"

# Process the cache key
CACHE_KEY=$(process_cache_key "$CACHE_KEY")
echo "Processed Cache Key: $CACHE_KEY"

# Check if CACHE_KEY and CACHE_PATH are set
if [ -z "$CACHE_KEY" ]; then
  echo "Error: CACHE_KEY or CACHE_PATH is not set. Exiting..."
  exit 1
fi

# Check if the archive exists in the S3 bucket
echo "Checking if s3://$BUCKET_NAME/$CACHE_KEY/$CACHE_KEY.tar.gz exists..."
if aws s3 ls "s3://$BUCKET_NAME/$CACHE_KEY/$CACHE_KEY.tar.gz" > /dev/null 2>&1; then
    echo "Cache archive found. Downloading..."
    
    # Download the archive from the S3 bucket
    if aws s3 cp "s3://$BUCKET_NAME/$CACHE_KEY/$CACHE_KEY.tar.gz" "$CACHE_KEY.tar.gz"; then
        echo "Cache archive successfully downloaded - $CACHE_KEY.tar.gz"
    else
        echo "Error: Failed to download cache archive from S3."
        exit 1
    fi
else
    echo "Error: Cache archive not found in S3."
    exit 1
fi
