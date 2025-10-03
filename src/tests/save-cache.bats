#!/usr/bin/env bats

# Setup environment for the tests
setup() {
    # Create a mock S3 bucket and set environment variables
    export BUCKET_NAME="test-bucket"
    export CACHE_KEY="test-cache-key"
    export MAX_CONCURRENT_REQUESTS="20"
    export MAX_QUEUE_SIZE="10000"
    export S3_MULTIPART_THRESHOLD="64MB"

    # Create a temporary directory for testing
    export TMP_DIR=$(mktemp -d)
    cd "$TMP_DIR" || exit 1

    # Mock AWS CLI with a test script
    mkdir -p mock_aws
    echo '#!/bin/bash' > mock_aws/aws
    echo 'if [[ "$1" == "configure" ]]; then' >> mock_aws/aws
    echo '  exit 0' >> mock_aws/aws
    echo 'elif [[ "$1" == "s3" && "$2" == "cp" ]]; then' >> mock_aws/aws
    echo '  if [[ "$3" =~ \.tar\.gz$ && "$4" =~ ^s3:// ]]; then' >> mock_aws/aws
    echo '    exit 0' >> mock_aws/aws
    echo '  else' >> mock_aws/aws
    echo '    exit 1' >> mock_aws/aws
    echo '  fi' >> mock_aws/aws
    echo 'fi' >> mock_aws/aws
    chmod +x mock_aws/aws

    # Add the mock AWS CLI to PATH
    export PATH="$TMP_DIR/mock_aws:$PATH"
}

# Cleanup after tests
teardown() {
    rm -rf "$TMP_DIR"
}

@test "Skip upload if cache path does not exist" {
    export CACHE_PATH="$TMP_DIR/nonexistent-path"
    run bash "$BATS_TEST_DIRNAME/../scripts/save-cache.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Cache path does not exist. Skipping upload."* ]]
}

@test "Create archive and upload if cache path exists" {
    export CACHE_PATH="$TMP_DIR/cache-dir"
    mkdir -p "$CACHE_PATH"
    echo "test content" > "$CACHE_PATH/test-file.txt"

    run bash "$BATS_TEST_DIRNAME/../scripts/save-cache.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Cache path exists. Archiving..."* ]]
    [[ "$output" == *"Archive created: test-cache-key.tar.gz"* ]]
    [[ "$output" == *"Cache archive uploaded to S3."* ]]
}

@test "Exit with error if archive creation fails" {
    export CACHE_PATH="$TMP_DIR/cache-dir"
    mkdir -p "$CACHE_PATH"

    # Make tar fail by using an invalid path
    export CACHE_KEY="/invalid/path/key"

    run bash "$BATS_TEST_DIRNAME/../scripts/save-cache.sh"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Failed to create archive"* ]]
}
