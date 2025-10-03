#!/bin/bash

echo "Cache Path is $CACHE_PATH"

# Check if the cache path exists
if [ -d "$CACHE_PATH" ]; then
  
  # Check if cache already exists in S3 before compressing
  echo "Checking if cache already exists in S3..."
  S3_OBJECT_PATH="s3://$BUCKET_NAME/$CACHE_KEY/$CACHE_KEY.tar.gz"
  
  if aws s3api head-object --bucket "$BUCKET_NAME" --key "$CACHE_KEY/$CACHE_KEY.tar.gz" > /dev/null 2>&1; then
    echo "Cache key '$CACHE_KEY' already exists in S3. Skipping compression and upload."
    exit 0
  fi
  
  echo "Cache not found in S3. Proceeding with compression..."
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
  aws s3 cp "$CACHE_KEY.tar.gz" "$S3_OBJECT_PATH"
  echo "Cache archive uploaded to S3."
else
  echo "Cache path does not exist. Skipping upload."
fi
