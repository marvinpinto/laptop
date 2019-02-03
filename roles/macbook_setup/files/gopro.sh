#!/bin/bash

set -o pipefail
set -e

myname=`basename "$0"`
video_file=""
image_mode=""
live_run=""
verbose=""
EXIFTOOL=""

show_help() {
  echo "usage: ${myname} <-v video_file | -i image_file | -u> [-l] [-z]"
  echo "Available Options:"
  echo "-v <video file>: Video file to process"
  echo "-i <image file>: Image file to process"
  echo "-u: Process all *.jpg images in the current directory"
  echo "-l: Perform a LIVE run (will rewrite source files)"
  echo "-z: Enable verbose mode"
  echo "e.g. ${myname} -v GOPR0735.MP4"
}

while getopts ":v:i:ulz" opt; do
  case "$opt" in
    v) video_file=$OPTARG
       ;;
    i) image_file=$OPTARG
       ;;
    u) image_mode="yes"
       ;;
    l) live_run="yes"
       ;;
    z) verbose="yes"
       ;;
    \?) echo "Unknown option: -$OPTARG"
        show_help
        exit 1
        ;;
    :)  echo "Missing option argument for -$OPTARG"
        show_help
        exit 1
        ;;
    *)  echo "Unimplemented option: -$OPTARG"
        show_help
        exit 1
        ;;
  esac
done

hash exiftool 2>/dev/null || { echo >&2 "exiftool does not appear to be available."; exit 1; }
hash mogrify 2>/dev/null || { echo >&2 "mogrify does not appear to be available."; exit 1; }
hash fredim-autocolor 2>/dev/null || { echo >&2 "fredim-autocolor does not appear to be available."; exit 1; }
hash fredim-enrich 2>/dev/null || { echo >&2 "fredim-enrich does not appear to be available."; exit 1; }
hash convert 2>/dev/null || { echo >&2 "convert does not appear to be available."; exit 1; }

[[ "$verbose" == "yes" ]] && set -x
[[ -z "$verbose" ]] && EXIFTOOL="exiftool -ignoreMinorErrors -q -q" || EXIFTOOL="exiftool"

process_video() {
  local original_filename=$(basename -- "$video_file")
  local temp_video_dir=${myname}-temp-videos

  rm -rf "$temp_video_dir"
  mkdir -p "$temp_video_dir"

  echo "- Creating a working copy of ${video_file}"
  local renamed_file=${original_filename// /_}
  cp "${video_file}" "${temp_video_dir}/${renamed_file}"

  local filename=$(basename -- "$renamed_file")
  local extension="${filename##*.}"
  filename="${filename%.*}"

  set +e
  $EXIFTOOL -overwrite_original '-datetimeoriginal<CreateDate' -if '(not $datetimeoriginal or ($datetimeoriginal eq "0000:00:00 00:00:00"))' "${temp_video_dir}/${filename}.${extension}"
  set -e

  # Write original EXIF tags + renaming
  echo "- EXIF tags: ${filename}.${extension}"
  $EXIFTOOL -overwrite_original -tagsfromfile "${video_file}" "${temp_video_dir}/${filename}.${extension}"
  set +e
  $EXIFTOOL -overwrite_original '-FileName<DateTimeOriginal' -if '($datetimeoriginal)' -d "%Y-%m-%d_%H.%M.%S%%-c-${filename}.%%e" "${temp_video_dir}/${filename}.${extension}"
  if [ $? -ne 0 ]; then
    echo "File ${filename} does not appear to have the EXIF DateTimeOriginal tag set."
    exit 1
  fi
  set -e

  if [[ -n "$live_run" ]]; then
    echo "- Cleanup: ${filename}.${extension}"
    mv ${temp_video_dir}/*-${filename}.${extension} .
    rm -f "${video_file}"
    $EXIFTOOL -overwrite_original '-FileName<DateTimeOriginal' -d "%Y-%m-%d_%H.%M.%S%%-c.%%e" *-${filename}.${extension}
    rm -rf "$temp_video_dir"
  fi
}

process_single_image() {
  local file=$1
  local temp_image_dir=$2
  local original_filename=$(basename -- "$file")
  local renamed_file=${original_filename// /_}

  local filename=$(basename -- "$renamed_file")
  local extension="${filename##*.}"
  filename="${filename%.*}"

  echo "- Processing file: ${filename}.jpg"
  cp "${file}" ${temp_image_dir}/${filename}.jpg
  set +e
  $EXIFTOOL -overwrite_original '-datetimeoriginal<CreateDate' -if '(not $datetimeoriginal or ($datetimeoriginal eq "0000:00:00 00:00:00"))' "${temp_image_dir}/${filename}.jpg"
  set -e

  local im_args=""

  echo "    - Auto-orientation: ${filename}.jpg"
  im_args+=" -auto-orient"

  # Execute imagemagick with the specified arguments
  mogrify $im_args ${temp_image_dir}/${filename}.jpg

  if [[ -z "$live_run" ]]; then
    # Create a side-by-side preview of this image
    echo "    - Side-by-side preview: ${filename}.jpg"
    convert "${file}" "${temp_image_dir}/${filename}.jpg" +append "${temp_image_dir}/${filename}-combined.jpg"
    $EXIFTOOL -overwrite_original -tagsfromfile "${file}" "${temp_image_dir}/${filename}-combined.jpg"
    $EXIFTOOL -overwrite_original '-FileName<DateTimeOriginal' -d "%Y-%m-%d_%H.%M.%S%%-c-${filename}-combined.%%e" "${temp_image_dir}/${filename}-combined.jpg"
  fi

  # Write original EXIF tags + renaming
  echo "    - EXIF tags: ${filename}.jpg"
  $EXIFTOOL -overwrite_original -tagsfromfile "${file}" "${temp_image_dir}/${filename}.jpg"
  set +e
  $EXIFTOOL -overwrite_original -geotag "*.gpx" -if 'not ($GPSLatitude and $GPSLongitude)' -api GeoMaxIntSecs=120 -api GeoMaxExtSecs=120 "${temp_image_dir}/${filename}.jpg"
  $EXIFTOOL -overwrite_original '-FileName<DateTimeOriginal' -if '($datetimeoriginal)' -d "%Y-%m-%d_%H.%M.%S%%-c-${filename}.%%e" "${temp_image_dir}/${filename}.jpg"
  if [ $? -ne 0 ]; then
    echo "File ${filename} does not appear to have the EXIF DateTimeOriginal tag set."
    exit 1
  fi
  set -e

  if [[ -n "$live_run" ]]; then
    echo "    - Cleanup: ${filename}.jpg"
    rm -f ${temp_image_dir}/*-${filename}-combined.jpg
    mv ${temp_image_dir}/*-${filename}.jpg .
    rm -f "${file}"
    $EXIFTOOL -overwrite_original '-FileName<DateTimeOriginal' -d "%Y-%m-%d_%H.%M.%S%%-c.%%e" *-${filename}.jpg
  fi
}

process_images() {
  local temp_image_dir=${myname}-temp-images
  rm -rf "$temp_image_dir"
  mkdir -p "$temp_image_dir"

  if [[ -n "$image_file" ]]; then
    process_single_image "$image_file" "$temp_image_dir"
  else
    # Process all jpg images in the current directory
    find . -maxdepth 1 -iname "*.jpg" | while read file; do
      process_single_image "$file" "$temp_image_dir"
    done
  fi

  if [[ -z "$live_run" ]]; then
    echo -ne "\n"
    echo "****************************"
    echo " Sample Generation Complete "
    echo "****************************"
    echo "Look through the ${temp_image_dir} directory for updated files and side-by-side comparisons"
    echo -ne "\n"
    echo "If everything looks good, re-run this script with the -l flag."
  fi

  if [[ -n "$live_run" ]]; then
    echo "- Final cleanup"
    rm -rf "$temp_image_dir"
  fi
}

if [[ -n "$video_file" ]]; then
  process_video
elif [[ -n "$image_file" ]]; then
  process_images
elif [[ -n "$image_mode" ]]; then
  process_images
else
  show_help
  exit 1
fi
