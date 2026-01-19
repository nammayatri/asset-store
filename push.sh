#!/bin/bash -xev

# USAGE
#
#  This script provides 6 flags
#    --sandbox     : pushes to beta-hyper-sdk-assets bucket on S3
#    --no-compress : skips compression of images
#    --no-resize   : skips images resizing
#
#  Extra flags
#    --f      : for pushing without confirmation
#
#  ---- For pushing to production bucket
#       This defaults to s3://jp-remote-assets/hyper/...
#       $ bash -e push.sh <path to asset to be pushed>
#       eg: bash -e push.sh hyper/images/common/amazon_pay.png
#
#  ---- For pushing to sandbox bucket
#       This defaults to s3://beta-hyper-sdk-assets/hyper/...
#       $ bash -e push.sh <path to asset to be pushed> --sandbox
#       eg: bash -e push.sh hyper/images/common/amazon_pay.png
#

#### FUNCTIONS

if [[ "$@" =~ --f ]]
then force_push=true; fi

check_if_local_path_exists()
{
  local_path="$1"
  if [ -f "$local_path" ]
  then return 0
  else return 1; fi
}

check_if_png_is_valid()
{
  local_path="$1"
  printf "check_if_png_is_valid local_path : $local_path"
  if pngcheck "$local_path"
  then
    image_name=$(echo $local_path | rev | cut -d"/" -f1 | rev)
    if [[ "$image_name" =~ ^([a-z0-9]|_)*(\.9)?\.png$ ]]
    then return 0
    else return 1; fi
  else return 1; fi
}

invalidate_asset()
{
  s3_path="$1"
  aws cloudfront create-invalidation --distribution-id $distributionId --paths $s3_path
  printf "invalidated $s3_path"
}

push_asset() {
  local_path="$1"
  s3_path="$2"

  printf "s3_path $s3_path .. \n"

  if [ "$force_push" = true ]
  then read -p "Press enter to push to $s3_path"; fi

  printf "Pushing $local_path to $s3_path ...\n\n"

  aws s3 cp $local_path $s3_path
}

asset=""
# Use S3_BUCKET from environment if set, otherwise default to beckn-frontend-assets
bucket="${S3_BUCKET:-beckn-frontend-assets}"
# Use CF_DISTRIBUTION_ID from environment if set, otherwise use default
distributionId="${CF_DISTRIBUTION_ID:-EZCA94ADQWCV1}"
force_push=false

if [ $(echo $@ | sed "s/--[a-zA-Z]*-*[a-zA-Z]*//g" | tr -d '[:space:]' | wc -c) -ne 0 ]
then asset=$(echo $@ | sed "s/--[a-zA-Z]*-*[a-zA-Z]*//g" | tr -d '[:space:]'); fi

if [[ "$@" =~ --sandbox ]]                  
then bucket="${S3_BUCKET:-beckn-frontend-assets}"; fi    # Use env var if set, otherwise default

echo -------------- s3 push starting -------------------

if [ "$asset" != "" ]
then
  local_path=$(pwd)/$asset

  check_if_local_path_exists $local_path
  if [ "$?" != 0 ]
  then echo "$local_path does not exist. Exiting ..." && exit 1; fi

  if [[ "$local_path" =~ \.png$ ]]
  then
    if [[ ! "$@" =~ --no-check ]]
    then
      check_if_png_is_valid $local_path
      if [ "$?" != 0 ]
      then echo "Image at $local_path is invalid. Exiting ..." && exit 1; fi
    fi

    if [[ ! "$@" =~ (\.9\.png|credit|bbfresho|hyperupi) ]]
    then
      if [[ ! "$@" =~ --no-resize ]] && [[ "$local_path" =~ \.png ]]
      then
        set +e
        python3 resizeImages.py $local_path
        if [ "$?" != 0 ]
        then echo "IMAGE_RESIZE_FAIL"
        else echo "IMAGE_RESIZE_SUCCESS"
        fi
        set -e
      fi
      if [[ ! "$@" =~ --no-compress ]] && [[ "$local_path" =~ \.png ]]
      then
        set +e
        node compressImages.js $local_path
        if [ "$?" != 0 ]
        then echo "IMAGE_COMPRESS_FAIL"
        else echo "IMAGE_COMPRESS_SUCCESS"
        fi
        set -e
      fi
    else echo "Skipping compression"; fi
  fi

  pathToPush="s3://$bucket/$asset"
  push_asset $local_path $pathToPush
  # Invalidate CloudFront cache using the asset path (relative to distribution root)
  invalidate_asset "/$asset"
fi