# Commit tagging

```bash
TAG=
REMOTE=

# Delete remote tag
git push --delete origin ${TAG}

# Delete tag
git tag -d ${TAG}

# Tag local commit
git tag ${TAG}

# Push tag to remote
git push ${REMOTE} ${TAG}
```
