#!/bin/bash
export CI=1

# Reduce pip verbosity and disable pip version check to avoid noisy downloads in logs
export PIP_DISABLE_PIP_VERSION_CHECK=1
export PIP_PROGRESS_BAR=off
export PULUMI_PYTHON_CMD=python3

# Install top-level requirements if present (fallback when workdirs don't include their own)
if [ -f "requirements.txt" ]; then
  echo "Installing top-level Python requirements"
  python -m pip install -r requirements.txt -q || { echo "Failed to install top-level requirements"; exit 1; }
fi

for i in $WORKDIRS; do
  if [ ! -d $i ]; then
    echo $i is not a directory, skipping..
    continue
  fi

  # if the workdir has a requirements.txt, install quietly so Pulumi doesn't create a venv and show downloads
  if [ -f "$i/requirements.txt" ]; then
    echo "Installing Python requirements for $i"
    python -m pip install -r "$i/requirements.txt" -q || { echo "Failed to install requirements for $i"; exit 1; }
  fi

  options="--yes --non-interactive --color=never"

  cd $i
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
