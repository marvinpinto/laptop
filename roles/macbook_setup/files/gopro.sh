#!/bin/bash

set -o pipefail
set -e

myname=`basename "$0"`
video_file=""
image_mode=""
live_run=""
ffmpeg_filter=""
enable_fisheye="yes"
verbose=""
EXIFTOOL=""

show_help() {
  echo "usage: ${myname} <-v video_file | -i image_file | -u> [-l] [-f ffmpeg_filter] [-z] [-w]"
  echo "Available Options:"
  echo "-v <video file>: Video file to process"
  echo "-i <image file>: Image file to process"
  echo "-u: Process all *.jpg images in the current directory"
  echo "-l: Perform a LIVE run (will rewrite source files)"
  echo "-f <ffmpeg filter name>: Specify a custom ffmpeg filter (default: linear_contrast)"
  echo -ne "   Available filters: \n     none\n     color_negative\n     cross_process\n     darker\n     increase_contrast\n     lighter\n     linear_contrast\n     medium_contrast\n     negative\n     strong_contrast\n     vintage\n"
  echo "-z: Enable verbose mode"
  echo "-w: Disable fisheye correction"
  echo "e.g. ${myname} -v GOPR0735.MP4"
}

while getopts ":v:i:ulf:zw" opt; do
  case "$opt" in
    v) video_file=$OPTARG
       ;;
    i) image_file=$OPTARG
       ;;
    u) image_mode="yes"
       ;;
    l) live_run="yes"
       ;;
    f) ffmpeg_filter=$OPTARG
       ;;
    z) verbose="yes"
       ;;
    w) enable_fisheye=""
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

hash ffmpeg2 2>/dev/null || { echo >&2 "ffmpeg2 does not appear to be available."; exit 1; }
hash exiftool 2>/dev/null || { echo >&2 "exiftool does not appear to be available."; exit 1; }
hash mogrify 2>/dev/null || { echo >&2 "mogrify does not appear to be available."; exit 1; }
hash fredim-autocolor 2>/dev/null || { echo >&2 "fredim-autocolor does not appear to be available."; exit 1; }
hash fredim-enrich 2>/dev/null || { echo >&2 "fredim-enrich does not appear to be available."; exit 1; }
hash convert 2>/dev/null || { echo >&2 "convert does not appear to be available."; exit 1; }

[[ "$verbose" == "yes" ]] && set -x
[[ -z "$verbose" ]] && EXIFTOOL="exiftool -ignoreMinorErrors -q -q" || EXIFTOOL="exiftool"

process_video() {
  local filename=$(basename -- "$video_file")
  local extension="${filename##*.}"
  filename="${filename%.*}"

  if [[ -n "$ffmpeg_filter" ]] && [[ ! "$ffmpeg_filter" =~ ^(none|color_negative|cross_process|darker|increase_contrast|lighter|linear_contrast|medium_contrast|negative|strong_contrast|vintage)$ ]]; then
    show_help
    exit 1
  fi

  if [[ -z "$ffmpeg_filter" ]]; then
    # set the default filter
    ffmpeg_filter="linear_contrast"
  fi

  echo "- Creating a working copy of ${video_file}"
  cp "${video_file}" "${tempdir}/${filename}-copy.${extension}"
  $EXIFTOOL -overwrite_original '-datetimeoriginal<CreateDate' -if '(not $datetimeoriginal or ($datetimeoriginal eq "0000:00:00 00:00:00"))' "${tempdir}/${filename}-copy.${extension}"

  echo "- Initiating video stabilization"
  local vidstabtrf_args=()
  [[ -z "$verbose" ]] && vidstabtrf_args+=(-loglevel fatal) || vidstabtrf_args+=(-loglevel info)
  [[ -z "$live_run" ]] && vidstabtrf_args+=(-y)
  vidstabtrf_args+=(-threads $(nproc --ignore=1))
  vidstabtrf_args+=(-i "${tempdir}/${filename}-copy.${extension}")
  [[ -z "$live_run" ]] && vidstabtrf_args+=(-t 10)
  vidstabtrf_args+=(-vf "vidstabdetect=stepsize=32:shakiness=10:accuracy=10:result=${tempdir}/transform_vectors.trf")
  vidstabtrf_args+=(-f null -)
  ffmpeg2 "${vidstabtrf_args[@]}"

  echo "- Re-encoding video"
  local base_video_filter="vidstabtransform=input=${tempdir}/transform_vectors.trf:zoom=0:smoothing=10,unsharp=5:5:0.8:3:3:0.4,curves=preset='${ffmpeg_filter}'"
  local reencode_output_filename_type=""
  [[ -z "$live_run" ]] && reencode_output_filename_type="sample"
  [[ -n "$live_run" ]] && reencode_output_filename_type="reencoded"
  reencode_args=()
  [[ -z "$verbose" ]] && reencode_args+=(-loglevel fatal) || reencode_args+=(-loglevel info)
  [[ -z "$live_run" ]] && reencode_args+=(-y)
  reencode_args+=(-threads $(nproc --ignore=1))
  reencode_args+=(-i "${tempdir}/${filename}-copy.${extension}")
  [[ -z "$live_run" ]] && reencode_args+=(-t 10)
  reencode_args+=(-af "highpass=f=300, lowpass=f=4000, bass=frequency=100:gain=-50, bandreject=frequency=200:width_type=h:width=200, compand=attacks=.05:decays=.05:points=-90/-90 -70/-90 -15/-15 0/-10:soft-knee=6:volume=-70:gain=10")
  [[ -n "$enable_fisheye" ]] && reencode_args+=(-vf "${base_video_filter},lenscorrection=cx=0.5:cy=0.5:k1=-0.227:k2=-0.022") || reencode_args+=(-vf "${base_video_filter}")
  reencode_args+=(-vcodec libx264)
  reencode_args+=(-acodec aac)
  reencode_args+=(-tune film)
  reencode_args+=(-preset slow)
  reencode_args+=("${filename}-${reencode_output_filename_type}.mp4")
  ffmpeg2 "${reencode_args[@]}"
  $EXIFTOOL -overwrite_original -tagsfromfile "${tempdir}/${filename}-copy.${extension}" "${filename}-${reencode_output_filename_type}.mp4"

  if [[ -z "$live_run" ]]; then
    echo "- Generating side-by-side sample"
    local sidebyside_args=()
    [[ -z "$verbose" ]] && sidebyside_args+=(-loglevel fatal) || sidebyside_args+=(-loglevel info)
    sidebyside_args+=(-y)
    sidebyside_args+=(-threads $(nproc --ignore=1))
    sidebyside_args+=(-i "$video_file")
    sidebyside_args+=(-i "${filename}-sample.mp4")
    sidebyside_args+=(-t 10)
    sidebyside_args+=(-an)
    sidebyside_args+=(-filter_complex "[0:v:0]pad=iw*2:ih[bg]; [bg][1:v:0]overlay=w")
    sidebyside_args+=(${filename}-combined.mp4)
    ffmpeg2 "${sidebyside_args[@]}"
    $EXIFTOOL -overwrite_original -tagsfromfile "${tempdir}/${filename}-copy.${extension}" "${filename}-combined.mp4"
  fi

  echo "- Renaming re-encoded outputs"
  [[ -n "$live_run" ]] && $EXIFTOOL  -overwrite_original '-FileName<DateTimeOriginal' -d "%Y-%m-%d_%H.%M.%S%%-c.%%e" "${filename}-${reencode_output_filename_type}.mp4"
  [[ -z "$live_run" ]] && $EXIFTOOL  -overwrite_original '-FileName<DateTimeOriginal' -d "%Y-%m-%d_%H.%M.%S%%-c-${filename}-${reencode_output_filename_type}.%%e" "${filename}-${reencode_output_filename_type}.mp4"
  [[ -z "$live_run" ]] && $EXIFTOOL  -overwrite_original '-FileName<DateTimeOriginal' -d "%Y-%m-%d_%H.%M.%S%%-c-${filename}-combined.%%e" "${filename}-combined.mp4"

  echo "- Performing cleanup"
  rm -rf "${tempdir}"
  [[ -n "$live_run" ]] && rm -f *-${filename}-sample.mp4 *-${filename}-reencoded.mp4 *-${filename}-combined.mp4
  [[ -n "$live_run" ]] && rm -f "${video_file}"

  if [[ -z "$live_run" ]]; then
    echo -ne "\n"
    echo "****************************"
    echo " Sample Generation Complete "
    echo "****************************"
    echo "Re-encoded sample: <filename>-sample.mp4"
    echo "Side-by-side sample comparison: <filename>-combined.mp4"
    echo -ne "\n"
    echo "If everything looks good, re-run this script with the -l flag."
  fi
}

process_single_image() {
  local file=$1
  local temp_image_dir=$2
  local filename=$(basename -- "$file")
  local extension="${filename##*.}"
  filename="${filename%.*}"

  echo "- Processing file: ${filename}.jpg"
  cp ${file} ${temp_image_dir}/${filename}.jpg
  set +e
  $EXIFTOOL -overwrite_original '-datetimeoriginal<CreateDate' -if '(not $datetimeoriginal or ($datetimeoriginal eq "0000:00:00 00:00:00"))' "${temp_image_dir}/${filename}.jpg"
  set -e

  if [[ -n "$enable_fisheye" ]]; then
    # Fix fisheye
    echo "    - Fisheye: ${filename}.jpg"
    mogrify -distort barrel "0.01,0,-0.31" ${temp_image_dir}/${filename}.jpg
  fi

  # Utilize Fred's IM autocolor script
  echo "    - Autocolor: ${filename}.jpg"
  fredim-autocolor -m gamma -c separate ${temp_image_dir}/${filename}.jpg ${temp_image_dir}/${filename}.jpg

  # Utilize Fred's IM enrich script
  echo "    - Enrich: ${filename}.jpg"
  fredim-enrich ${temp_image_dir}/${filename}.jpg ${temp_image_dir}/${filename}.jpg

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
