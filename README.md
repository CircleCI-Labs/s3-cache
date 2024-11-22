# CircleCI Labs - s3-cache Orb (Unofficial)


[![CircleCI Build Status](https://circleci.com/gh/CircleCI-Labs/s3-cache.svg?style=shield "CircleCI Build Status")](https://circleci.com/gh/CircleCI-Labs/s3-cache) [![CircleCI Orb Version](https://badges.circleci.com/orbs/cci-labs/s3-cache.svg)](https://circleci.com/developer/orbs/orb/cci-labs/s3-cache) [![GitHub License](https://img.shields.io/badge/license-MIT-lightgrey.svg)](https://raw.githubusercontent.com/CircleCI-Labs/s3-cache/master/LICENSE) [![CircleCI Community](https://img.shields.io/badge/community-CircleCI%20Discuss-343434.svg)](https://discuss.circleci.com/c/ecosystem/orbs)

---
**Disclaimer:**

CircleCI Labs, including this repo, is a collection of solutions developed by members of CircleCI's field engineering teams through our engagement with various customer needs.

-   ✅ Created by engineers @ CircleCI
-   ✅ Used by real CircleCI customers
-   ❌ **not** officially supported by CircleCI support

---

### Example Usage: CircleCI Config with the custom S3 Cache Orb

```

version: 2.1

orbs:
  s3-cache: cci-labs/s3-cache@0.0.1
  aws-cli: circleci/aws-cli@4.1.3

commands:
  aws-auth-setup:
    steps:
      - aws-cli/setup:
          region: << pipeline.parameters.aws-default-region >>
          role_arn: << pipeline.parameters.role-name >>
          role_session_name: "CircleCI-${CIRCLE_WORKFLOW_ID}-${CIRCLE_JOB}"

parameters:
  account-id:
    type: string
    default: "999999999999"
  aws-default-region:
    type: string
    default: "us-west-2"
  role-name:
    type: string
    default: "arn:aws:iam::999999999999:role/awesome_aws_ci_oidc_role"
  cache-path:
    type: string
    default: "/tmp/cache-dir"
  cache-key:
    type: string
    description: "Cache Key for storing in S3"
    default: << pipeline.git.branch >>
jobs:
  s3-custom-cache:
    docker:
      - image: cimg/base:current
    parallelism: 1
    steps:
      - checkout
      - aws-auth-setup
      - run:
          name: "Create a Dummy Cache"
          command: |
             mkdir << pipeline.parameters.cache-path >>
             head -c 85765 </dev/urandom > /tmp/cache-dir/cache-file-$CIRCLE_NODE_INDEX
      - s3-cache/save-cache:
           cache-path: << pipeline.parameters.cache-path >>
           bucket-name: cci-labs-bucket
           cache-key: << pipeline.git.branch >>
      - s3-cache/restore-cache:
           cache-key: << pipeline.git.branch >>
           bucket-name: cci-labs-bucket


workflows:
  custom-cache-workflow: 
    jobs:
      - s3-custom-cache
```

## Resources

[CircleCI Orb Registry Page](https://circleci.com/developer/orbs/orb/cci-labs/s3-cache) - The official registry page of this orb for all versions, executors, commands, and jobs described.

### How to Contribute

We welcome [issues](https://github.com/CircleCI-Labs/s3-cache/issues) to and [pull requests](https://github.com/CircleCI-Labs/s3-cache/pulls) against this repository!

### How to Publish An Update
1. Merge pull requests with desired changes to the main branch.
    - For the best experience, squash-and-merge and use [Conventional Commit Messages](https://conventionalcommits.org/).
2. Find the current version of the orb.
    - You can run `circleci orb info cci-labs/s3-cache | grep "Latest"` to see the current version.
3. Create a [new Release](https://github.com/CircleCI-Labs/s3-cache/releases/new) on GitHub.
    - Click "Choose a tag" and _create_ a new [semantically versioned](http://semver.org/) tag. (ex: v1.0.0)
      - We will have an opportunity to change this before we publish if needed after the next step.
4.  Click _"+ Auto-generate release notes"_.
    - This will create a summary of all of the merged pull requests since the previous release.
    - If you have used _[Conventional Commit Messages](https://conventionalcommits.org/)_ it will be easy to determine what types of changes were made, allowing you to ensure the correct version tag is being published.
5. Now ensure the version tag selected is semantically accurate based on the changes included.
6. Click _"Publish Release"_.
    - This will push a new tag and trigger your publishing pipeline on CircleCI.
