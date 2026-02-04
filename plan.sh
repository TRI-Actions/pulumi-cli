#!/bin/bash
export CI=1

plan() {
  dir=$1
  cd $dir
  pulumi stack select main || pulumi stack init main 

  echo Running plan for $dir
  options=" --color=never"
  if [ "$DRIFT_CHECK" == "true" ]; then
    options+=" --refresh-only"

    pulumi preview $options --non-interactive > plan.out

    INDEX=$(awk '/Note: Objects have changed/{ print NR; exit }' plan.out)

    if [[ -n "$INDEX" ]]; then
      echo Drift Detected!
      sed -i "1,$((INDEX-1)) d" plan.out
      echo "DRIFTED" > drift.out
    else
      echo No drift detected!
      echo "IN-SYNC" > drift.out
      pulumi preview --non-interactive --color=never > plan.out
    fi
  else
    pulumi preview $options --non-interactive > plan.out
    INDEX=$(awk '/Pulumi used the selected providers/{ print NR; exit }' plan.out)
    sed -i "1,$((INDEX-1)) d" plan.out
    if grep -i 'error\|failed' plan.out; then
      sed -i "1iPlan failed!"
    fi
    echo "IN-SYNC" > drift.out
  fi
  if [ ! $i == '.' ]; then
    cd ..
  fi
}

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
  # if the workdir has a requirements.txt, install quietly so Pulumi doesn't create a venv and show downloads
  if [ -f "$i/requirements.txt" ]; then
    echo "Installing Python requirements for $i"
    python -m pip install -r "$i/requirements.txt" -q || { echo "Failed to install requirements for $i"; exit 1; }
  fi
  if [ ! -d $i ]; then
    echo $i is not a directory, skipping..
    continue
  fi
  plan $i
done

wait
echo Done!
exit 0
