# Usage of the Changelog directory

## Continuous development:

- Every merge on develop MUST have a corresponding entry in the Changelog
- Content to the changelog is added by the person who raised the Pull Request

## When cutting a "rc" or "build" branch:

### Step 1: Prepare for RC branch
- This is expected to be done BEFORE the branch is created
- rename `develop.md` to <version>.md
- in the version.md, if there are "empty" sections, then they should be replaced with "No changed"
- commit and merge into develop, and then create a branch with a comment of the format: `Migrate develop CHANGELOG to <version>`
- Any changes to the rc branch, will get updated in the `version.md` file

### Step 2: Cut branch

# Step 3: Create new Changelog file for develop
- copy `CHANGELOG.md.template` to `develop.md`
- commit to develop with comment: `Clean changelog after version branching`

