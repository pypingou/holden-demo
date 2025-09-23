#!/usr/bin/sh

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd $SCRIPT_DIR

image=true
while [[ $# -gt 0 ]]; do
  case $1 in
    --noimage)
      image=false
      shift # past argument
      ;;
  esac
done

arch=$(arch)

if [ $image = true ]; then
  automotive-image-builder --verbose \
    build \
    --distro autosd9 \
    --target qemu \
    --mode package \
    --build-dir=_build \
    --export image \
    holden-demo.aib.yml \
    holden-demo.$arch.img
fi
