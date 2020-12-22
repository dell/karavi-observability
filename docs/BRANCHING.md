<!--
Copyright (c) 2020 Dell Inc., or its subsidiaries. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0
-->

# Branching Strategy

This repository will use a release branching strategy.  Maintainers will create a release branch for a future release and all changes related to that release will be made on that branch.  When changes for a release are complete, the release branch is merged into the main branch after being approved as part of a pull request.

When contributing to other Karavi Observability repositories, please follow the documentation in those repositories as the branching strategy may differ.

## Branch Naming Convention

The only type of branch that should be created in this repository is a release branch.  Release branches should follow the naming convention below.

|  Branch Type |  Example                          |  Comment                                  |
|--------------|-----------------------------------|-------------------------------------------|
|  main        |  main                             |                                           |
|  Release     |  release-1.0                      |  hotfix: release-1.1 patch: release-1.0.1 |

## Steps for working on a release branch

1. Fork the repository.
2. Create a branch off of the release branch. The branch name should follow [branch naming convention](#branch-naming-convention).
3. Make your changes and commit them to your branch.
4. If other code changes have merged into the upstream release branch, perform a rebase of those changes into your branch.
5. Open a [pull request](#pull-requests) between your branch and the upstream release branch.
6. Once your pull request has merged, your branch can be deleted.
