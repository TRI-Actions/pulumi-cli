#!/bin/bash
set -euo pipefail
export CI=1

REPO_NAME=$(echo "$GITHUB_REPOSITORY" | cut -d'/' -f2)

echo "Deploying to $REPO_NAME"

pulumi login "s3://tri-pulumi-state-us-east-1/$REPO_NAME"

for i in $WORKDIRS; do
  if [ ! -d "$i" ]; then
    echo "$i is not a directory, skipping.."
    continue
  fi

  pushd "$i" > /dev/null
  pulumi stack select main || pulumi stack init main
  echo "Deploying for $i"

  options="--yes --non-interactive --color=never"

  if [ "$UPDATE_STATE" == "true" ]; then
    echo "Updating state for $i"
    pulumi refresh --yes --non-interactive --color=never
  fi
  pulumi up $options > deploy.out

  popd > /dev/null
done
