#!/bin/bash
set -euo pipefail
export CI=1

plan() {
  local dir="$1"
  pushd "$dir" > /dev/null

  pulumi stack select main || pulumi stack init main

  echo "Running plan for $dir"
  local options="--color=never --diff"

  if [ "$DRIFT_CHECK" == "true" ]; then
    pulumi refresh --yes
    pulumi preview $options --non-interactive > plan.out

    local INDEX
    INDEX=$(awk '/Note: Objects have changed/{ print NR; exit }' plan.out)

    if [[ -n "$INDEX" ]]; then
      echo "Drift Detected!"
      tail -n "+$INDEX" plan.out > plan.out.tmp && mv plan.out.tmp plan.out
      echo "DRIFTED" > drift.out
    else
      echo "No drift detected!"
      echo "IN-SYNC" > drift.out
      pulumi preview $options --non-interactive > plan.out
    fi
  else
    pulumi preview $options --non-interactive > plan.out

    local INDEX
    INDEX=$(awk '/Pulumi used the selected providers/{ print NR; exit }' plan.out)
    if [[ -n "$INDEX" ]]; then
      tail -n "+$INDEX" plan.out > plan.out.tmp && mv plan.out.tmp plan.out
    fi
    if grep -qi 'error\|failed' plan.out; then
      { echo "Plan failed!"; cat plan.out; } > plan.out.tmp && mv plan.out.tmp plan.out
    fi
    echo "IN-SYNC" > drift.out
  fi

  echo "drift-status=$(cat drift.out)" >> "${GITHUB_OUTPUT:-/dev/null}"

  popd > /dev/null
}

REPO_NAME=$(echo "$GITHUB_REPOSITORY" | cut -d'/' -f2)

pulumi login "s3://tri-pulumi-state-us-east-1/$REPO_NAME"

for i in $WORKDIRS; do
  if [ ! -d "$i" ]; then
    echo "$i is not a directory, skipping.."
    continue
  fi
  plan "$i"
done

echo "Done!"
