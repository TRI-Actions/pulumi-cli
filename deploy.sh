#!/bin/bash
export CI=1

for i in $WORKDIRS; do
  if [ ! -d $i ]; then
    echo $i is not a directory, skipping..
    continue
  fi

  options="--yes --non-interactive --color=never"

  cd $i
  pulumi stack select main || pulumi stack init main 
  echo Deploying for $i
  if [ "$UPDATE_STATE" == "true" ]; then
    echo "Updating state for $i"
    pulumi refresh --yes --non-interactive --color=never > deploy.out
  fi
  pulumi up $options > deploy.out

  if [ ! $i == '.' ]; then
    cd ..
  fi
done

exit
