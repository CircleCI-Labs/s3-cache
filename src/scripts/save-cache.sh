#!/bin/bash

echo "Cache Path is $CACHE_PATH"

# Check if the cache path exists
if [ -d "$CACHE_PATH" ]; then
  
  echo "Cache path exists. Archiving..."
  # Create the archive with zstd compression
  tar --use-compress-program="zstd -T0 -19" -cf "$CACHE_KEY.tar.zst" "$CACHE_PATH"
  if [ -f "$CACHE_KEY.tar.zst" ]; then
      echo "Archive created: $CACHE_KEY.tar.zst"
  else
      echo "Failed to create archive: $CACHE_KEY.tar.zst"
      exit 1
  fi

  # Configure S3 settings
  aws configure set default.s3.max_concurrent_requests "$MAX_CONCURRENT_REQUESTS"
  aws configure set default.s3.max_queue_size "$MAX_QUEUE_SIZE"
  aws configure set default.s3.multipart_threshold "$S3_MULTIPART_THRESHOLD"

  # Upload the archive to the S3 bucket
  aws s3 cp "$CACHE_KEY.tar.zst" "s3://$BUCKET_NAME/$CACHE_KEY/$CACHE_KEY.tar.zst"
  echo "Cache archive uploaded to S3."
else
  echo "Cache path does not exist. Skipping upload."
fi
