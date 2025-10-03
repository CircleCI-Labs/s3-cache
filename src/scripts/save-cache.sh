#!/bin/bash

# Function to process cache key with variable interpolation and checksum evaluation
process_cache_key() {
  local key="$1"
  
  # First, evaluate environment variables (e.g., ${CIRCLE_PROJECT_REPONAME})
  # Using eval to expand environment variables in the string
  key=$(eval echo "$key")
  
  # Process checksum functions: {{ checksum "filename" }} or {{ checksum filename }}
  # Match both quoted and unquoted filenames (quotes may be stripped by eval)
  while [[ "$key" =~ \{\{[[:space:]]*checksum[[:space:]]+\"?([^\"}\s]+)\"?[[:space:]]*\}\} ]]; do
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
    # Handle both quoted and unquoted versions
    key="${key//\{\{ checksum \"$file\" \}\}/$checksum_value}"
    key="${key//\{\{checksum \"$file\"\}\}/$checksum_value}"
    key="${key//\{\{ checksum $file \}\}/$checksum_value}"
    key="${key//\{\{checksum $file\}\}/$checksum_value}"
    # Handle various spacing variations with sed
    key=$(echo "$key" | sed -E "s/\{\{[[:space:]]*checksum[[:space:]]+\"?$(echo "$file" | sed 's/[\/&]/\\&/g')\"?[[:space:]]*\}\}/$checksum_value/g")
  done
  
  echo "$key"
}

echo "Cache Path is $CACHE_PATH"
echo "Original Cache Key: $CACHE_KEY"

# Process the cache key
CACHE_KEY=$(process_cache_key "$CACHE_KEY")
echo "Processed Cache Key: $CACHE_KEY"

# Check if the cache path exists
if [ -d "$CACHE_PATH" ]; then
  
  echo "Cache path exists. Archiving..."
  # Create the archive
  tar -czf "$CACHE_KEY.tar.gz" "$CACHE_PATH"
  if [ -f "$CACHE_KEY.tar.gz" ]; then
      echo "Archive created: $CACHE_KEY.tar.gz"
  else
      echo "Failed to create archive: $CACHE_KEY.tar.gz"
      exit 1
  fi

  # Configure S3 settings
  aws configure set default.s3.max_concurrent_requests "$MAX_CONCURRENT_REQUESTS"
  aws configure set default.s3.max_queue_size "$MAX_QUEUE_SIZE"
  aws configure set default.s3.multipart_threshold "$S3_MULTIPART_THRESHOLD"

  # Upload the archive to the S3 bucket
  aws s3 cp "$CACHE_KEY.tar.gz" "s3://$BUCKET_NAME/$CACHE_KEY/$CACHE_KEY.tar.gz"
  echo "Cache archive uploaded to S3."
else
  echo "Cache path does not exist. Skipping upload."
fi
