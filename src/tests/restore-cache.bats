#!/usr/bin/env bats

# Setup environment for the tests
setup() {
    # Create a mock S3 bucket and set environment variables
    export BUCKET_NAME="test-bucket"
    export CACHE_KEY="test-cache-key"
    
    # Create a temporary directory for testing
    export TMP_DIR=$(mktemp -d)
    cd "$TMP_DIR" || exit 1

    # Mock AWS CLI with a test script
    mkdir -p mock_aws
    echo '#!/bin/bash' > mock_aws/aws
    echo 'if [[ "$1" == "s3" && "$2" == "ls" ]]; then' >> mock_aws/aws
    echo '  if [[ "$3" == "s3://test-bucket/test-cache-key/test-cache-key.tar.gz" ]]; then' >> mock_aws/aws
    echo '    echo "Found test-cache-key.tar.gz"' >> mock_aws/aws
    echo '    exit 0' >> mock_aws/aws
    echo '  else' >> mock_aws/aws
    echo '    exit 1' >> mock_aws/aws
    echo '  fi' >> mock_aws/aws
    echo 'elif [[ "$1" == "s3" && "$2" == "cp" ]]; then' >> mock_aws/aws
    echo '  if [[ "$3" == "s3://test-bucket/test-cache-key/test-cache-key.tar.gz" ]]; then' >> mock_aws/aws
    echo '    touch test-cache-key.tar.gz' >> mock_aws/aws
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

@test "Exit with error if CACHE_KEY is not set" {
    unset CACHE_KEY
    run ./test-script.sh
    [ "$status" -eq 1 ]
    [[ "$output" == *"Error: CACHE_KEY or CACHE_PATH is not set. Exiting..."* ]]
}

@test "Exit with error if S3 object does not exist" {
    export CACHE_KEY="nonexistent-cache-key"
    run ./test-script.sh
    [ "$status" -eq 1 ]
    [[ "$output" == *"Error: Cache archive not found in S3."* ]]
}

@test "Download the archive successfully if it exists" {
    export CACHE_KEY="test-cache-key"
    run ./test-script.sh
    [ "$status" -eq 0 ]
    [[ "$output" == *"Cache archive successfully downloaded - test-cache-key.tar.gz"* ]]
    [ -f "test-cache-key.tar.gz" ]
}
