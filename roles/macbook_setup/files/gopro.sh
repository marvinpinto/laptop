#!/bin/bash

set -o pipefail
set -e

myname=`basename "$0"`
video_files=""
image_mode=""
live_run=""
enable_fisheye=${ENABLE_FISHEYE:-"yes"}
EXIFTOOL=""
verbose=${VERBOSE:-""}
video_clip_args=""

show_help() {
  echo "usage: ${myname} <-v video_files | -i image_file | -u> [-l] [-c]"
  echo "Available Options:"
  echo "-v <video files>: Video files to process"
  echo "   Environment variables & defaults:"
  echo "   - OUTPUT_RESOLUTION: 720"
  echo "   - SMOOTHING_FACTOR: 10"
  echo "   - SHAKINESS_FACTOR: 5"
  echo "   - METADATA_FILE: <defaults to first supplied video arg>"
  echo "   - VERBOSE: yes|<empty> <default: empty>"
  echo "   - ENABLE_FISHEYE: yes|<empty> <default: yes>"
  echo "-i <image file>: Image file to process"
  echo "   Environment variables & defaults:"
  echo "   - VERBOSE: yes|<empty> <default: empty>"
  echo "-u: Process all *.jpg images in the current directory"
  echo "   Environment variables & defaults:"
  echo "   - VERBOSE: yes|<empty> <default: empty>"
  echo "-l: Perform a LIVE run (will rewrite source files)"
  echo "-c: <video file> <start NN:NN:NN> <end NN:NN:NN> Create a video clip"
  echo "e.g. ${myname} -v GOPR0735.MP4"
}

while getopts ":v:i:ulc:" opt; do
  case "$opt" in
    v) video_files=("$OPTARG")
       until [[ $(eval "echo \${$OPTIND}") =~ ^-.* ]] || [ -z $(eval "echo \${$OPTIND}") ]; do
           video_files+=($(eval "echo \${$OPTIND}"))
           OPTIND=$((OPTIND + 1))
       done
       ;;
    c) video_clip_args=("$OPTARG")
       until [[ $(eval "echo \${$OPTIND}") =~ ^-.* ]] || [ -z $(eval "echo \${$OPTIND}") ]; do
           video_clip_args+=($(eval "echo \${$OPTIND}"))
           OPTIND=$((OPTIND + 1))
       done
       ;;
    i) image_file=$OPTARG
       ;;
    u) image_mode="yes"
       ;;
    l) live_run="yes"
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
hash ffmpeg2 2>/dev/null || { echo >&2 "ffmpeg2 does not appear to be available."; exit 1; }


[[ "$verbose" == "yes" ]] && set -x
[[ -z "$verbose" ]] && EXIFTOOL="exiftool -ignoreMinorErrors -q -q" || EXIFTOOL="exiftool"

process_single_video() {
  local file=$1
  local temp_video_dir=$2
  local original_filename=$(basename -- "$file")
  local sample_time_seconds=15
  local  __resultvar=$3
  local output_resolution=${OUTPUT_RESOLUTION:-720}
  local smoothing_factor=${SMOOTHING_FACTOR:-10}
  local shakiness_factor=${SHAKINESS_FACTOR:-5}

  echo "- Processing video file: ${file}"
  echo "  - Creating working copy"
  local renamed_file=${original_filename// /_}
  cp "${file}" "${temp_video_dir}/${renamed_file}"

  local filename=$(basename -- "$renamed_file")
  local extension="${filename##*.}"
  filename="${filename%.*}"

  echo "  - Initiating video stabilization"
  local vidstabtrf_args=()
  [[ -z "$verbose" ]] && vidstabtrf_args+=(-loglevel fatal) || vidstabtrf_args+=(-loglevel info)
  [[ -z "$live_run" ]] && vidstabtrf_args+=(-y)
  vidstabtrf_args+=(-threads $(nproc --ignore=1))
  vidstabtrf_args+=(-i "${temp_video_dir}/${filename}.${extension}")
  [[ -z "$live_run" ]] && vidstabtrf_args+=(-t $sample_time_seconds)
  vidstabtrf_args+=(-vf "vidstabdetect=shakiness=${shakiness_factor}:result=${temp_video_dir}/${filename}-transform_vectors.trf")
  vidstabtrf_args+=(-f null -)
  ffmpeg2 "${vidstabtrf_args[@]}"

  echo "  - Re-encoding video"
  local base_video_filter="scale=-1:'min(${output_resolution},ih)',pp=al,vidstabtransform=input=${temp_video_dir}/${filename}-transform_vectors.trf:zoom=0:smoothing=${smoothing_factor},unsharp"
  local reencode_output_filename_type=""
  [[ -z "$live_run" ]] && reencode_output_filename_type="sample"
  [[ -n "$live_run" ]] && reencode_output_filename_type="reencoded"
  reencode_args=()
  [[ -z "$verbose" ]] && reencode_args+=(-loglevel fatal) || reencode_args+=(-loglevel info)
  [[ -z "$live_run" ]] && reencode_args+=(-y)
  reencode_args+=(-threads $(nproc --ignore=1))
  reencode_args+=(-i "${temp_video_dir}/${filename}.${extension}")
  [[ -z "$live_run" ]] && reencode_args+=(-t $sample_time_seconds)
  reencode_args+=(-af "highpass=f=300, lowpass=f=4000, bass=frequency=100:gain=-50, bandreject=frequency=200:width_type=h:width=200, compand=attacks=.05:decays=.05:points=-90/-90 -70/-90 -15/-15 0/-10:soft-knee=6:volume=-70:gain=10")
  [[ -n "$enable_fisheye" ]] && reencode_args+=(-vf "${base_video_filter},lenscorrection=k1=-0.227:k2=-0.022") || reencode_args+=(-vf "${base_video_filter}")
  reencode_args+=(-vcodec libx264)
  reencode_args+=(-acodec aac)
  reencode_args+=(-preset slow)
  reencode_args+=(-crf 22)
  reencode_args+=("${temp_video_dir}/${filename}-${reencode_output_filename_type}.mp4")
  ffmpeg2 "${reencode_args[@]}"

  if [[ -z "$live_run" ]]; then
    echo "  - Generating side-by-side sample"
    local sidebyside_args=()
    [[ -z "$verbose" ]] && sidebyside_args+=(-loglevel fatal) || sidebyside_args+=(-loglevel info)
    sidebyside_args+=(-y)
    sidebyside_args+=(-threads $(nproc --ignore=1))
    sidebyside_args+=(-i "${temp_video_dir}/${filename}.${extension}")
    sidebyside_args+=(-i "${temp_video_dir}/${filename}-sample.mp4")
    sidebyside_args+=(-t $sample_time_seconds)
    sidebyside_args+=(-an)
    sidebyside_args+=(-filter_complex "[0:v]pad=iw*2:ih[int];[int][1:v]overlay=W/2:0[vid]")
    sidebyside_args+=(-map [vid])
    sidebyside_args+=(-preset veryfast)
    sidebyside_args+=(${temp_video_dir}/${filename}-combined.mp4)
    ffmpeg2 "${sidebyside_args[@]}"
  fi

  if [[ -n "$live_run" ]]; then
    echo "  - Deleting original file: ${file}"
    rm -f "${file}"
  fi

  eval $__resultvar="'${filename}'"
}

process_videos() {
  local temp_video_dir=${myname}-temp-videos
  rm -rf "$temp_video_dir"
  mkdir -p "$temp_video_dir"

  local ffmpeg_input_args=()
  local ffmpeg_filter_str=()
  local CTR=0
  local processed_video_filenames=()
  local video_metadata_file=${METADATA_FILE:-${video_files[0]}}

  $EXIFTOOL -overwrite_original -tagsfromfile "${video_metadata_file}" "${temp_video_dir}/metadata-info.mie"

  local reencode_output_filename_type=""
  [[ -z "$live_run" ]] && reencode_output_filename_type="sample"
  [[ -n "$live_run" ]] && reencode_output_filename_type="reencoded"

  [[ -z "$verbose" ]] && ffmpeg_input_args+=(-loglevel fatal) || ffmpeg_input_args+=(-loglevel info)
  [[ -z "$live_run" ]] && ffmpeg_input_args+=(-y)
  ffmpeg_input_args+=(-threads $(nproc --ignore=1))

  for video in "${video_files[@]}"; do
    process_single_video "$video" "$temp_video_dir" RESULT_VAR

    ffmpeg_input_args+=(-i "${temp_video_dir}/${RESULT_VAR}-${reencode_output_filename_type}.mp4")
    ffmpeg_filter_str+=([${CTR}:v:0][${CTR}:a:0])
    CTR=$((CTR+1))

    echo "  - EXIF metadata"
    find ${temp_video_dir}/ -maxdepth 1 -iname "${RESULT_VAR}*.mp4" | while read file; do
      $EXIFTOOL -overwrite_original -tagsfromfile "${temp_video_dir}/metadata-info.mie" "${file}"
      set +e
      $EXIFTOOL -overwrite_original '-datetimeoriginal<CreateDate' -if '(not $datetimeoriginal or ($datetimeoriginal eq "0000:00:00 00:00:00"))' "${file}"
      set -e
    done

    processed_video_filenames+=($RESULT_VAR)
  done

  local filter_str="$(echo -e "${ffmpeg_filter_str[@]}" | tr -d '[:space:]')"
  filter_str+="concat=n=${CTR}:v=1:a=1[outv][outa]"

  echo "- Finalizing concatenated ouput"
  ffmpeg2 ${ffmpeg_input_args[@]} -filter_complex "${filter_str}" -map "[outv]" -map "[outa]" ${temp_video_dir}/concatenated-output.mp4
  $EXIFTOOL -overwrite_original -tagsfromfile "${temp_video_dir}/metadata-info.mie" "${temp_video_dir}/concatenated-output.mp4"
  set +e
  $EXIFTOOL -overwrite_original '-datetimeoriginal<CreateDate' -if '(not $datetimeoriginal or ($datetimeoriginal eq "0000:00:00 00:00:00"))' "${temp_video_dir}/concatenated-output.mp4"
  set -e
  [[ -z "$live_run" ]] &&  $EXIFTOOL  -overwrite_original '-FileName<DateTimeOriginal' -if '($datetimeoriginal)' -d "%Y-%m-%d_%H.%M.%S%%-c-concatenated-output.%%le" "${temp_video_dir}/concatenated-output.mp4"

  echo "- Renaming re-encoded outputs"
  for video in "${processed_video_filenames[@]}"; do
    find "${temp_video_dir}/" -iname "${video}.mp4" -exec $EXIFTOOL -overwrite_original '-FileName<DateTimeOriginal' -if '($datetimeoriginal)' -d "%Y-%m-%d_%H.%M.%S%%-c-${video}.%%le" {} \;
    [[ -z "$live_run" ]] && $EXIFTOOL  -overwrite_original '-FileName<DateTimeOriginal' -if '($datetimeoriginal)' -d "%Y-%m-%d_%H.%M.%S%%-c-${video}-${reencode_output_filename_type}.%%le" "${temp_video_dir}/${video}-${reencode_output_filename_type}.mp4"
    [[ -z "$live_run" ]] && $EXIFTOOL  -overwrite_original '-FileName<DateTimeOriginal' -if '($datetimeoriginal)' -d "%Y-%m-%d_%H.%M.%S%%-c-${video}-combined.%%le" "${temp_video_dir}/${video}-combined.mp4"
  done

  if [[ -z "$live_run" ]]; then
    echo -ne "\n"
    echo "****************************"
    echo " Sample Generation Complete "
    echo "****************************"
    echo "Look through the ${temp_video_dir} directory for updated files and side-by-side comparisons"
    echo -ne "\n"
    echo "If everything looks good, re-run this script with the -l flag."
  fi

  if [[ -n "$live_run" ]]; then
    echo "- Final cleanup"
    mv "${temp_video_dir}/concatenated-output.mp4" .
    $EXIFTOOL  -overwrite_original '-FileName<DateTimeOriginal' -if '($datetimeoriginal)' -d "%Y-%m-%d_%H.%M.%S%%-c.%%le" "./concatenated-output.mp4"
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
    $EXIFTOOL -overwrite_original '-FileName<DateTimeOriginal' -d "%Y-%m-%d_%H.%M.%S%%-c-${filename}-combined.%%le" "${temp_image_dir}/${filename}-combined.jpg"
  fi

  # Write original EXIF tags + renaming
  echo "    - EXIF tags: ${filename}.jpg"
  $EXIFTOOL -overwrite_original -tagsfromfile "${file}" "${temp_image_dir}/${filename}.jpg"
  set +e
  $EXIFTOOL -overwrite_original -geotag "*.gpx" -if 'not ($GPSLatitude and $GPSLongitude)' -api GeoMaxIntSecs=120 -api GeoMaxExtSecs=120 "${temp_image_dir}/${filename}.jpg"
  $EXIFTOOL -overwrite_original '-FileName<DateTimeOriginal' -if '($datetimeoriginal)' -d "%Y-%m-%d_%H.%M.%S%%-c-${filename}.%%le" "${temp_image_dir}/${filename}.jpg"
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
    $EXIFTOOL -overwrite_original '-FileName<DateTimeOriginal' -d "%Y-%m-%d_%H.%M.%S%%-c.%%le" *-${filename}.jpg
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

create_video_clip() {
  local temp_video_dir=${myname}-temp-videos
  rm -rf "$temp_video_dir"
  mkdir -p "$temp_video_dir"

  local video_file=${video_clip_args[0]}
  local seek_start=${video_clip_args[1]}
  local seek_end=${video_clip_args[2]}

  local original_filename=$(basename -- "$video_file")
  local renamed_file=${original_filename// /_}
  local filename=$(basename -- "$renamed_file")
  local extension="${filename##*.}"
  filename="${filename%.*}"

  echo "- Creating clip from ${filename}.${extension}"
  local ffmpeg_args=()
  [[ -z "$verbose" ]] && ffmpeg_args+=(-loglevel fatal) || ffmpeg_args+=(-loglevel info)
  [[ -z "$live_run" ]] && ffmpeg_args+=(-y)
  ffmpeg_args+=(-threads $(nproc --ignore=1))
  ffmpeg_args+=(-i "${video_file}")
  ffmpeg_args+=(-ss "${seek_start}")
  ffmpeg_args+=(-to "${seek_end}")
  ffmpeg_args+=(-q:a 1)
  ffmpeg_args+=(-q:v 1)
  ffmpeg_args+=(-vcodec libx264)
  ffmpeg_args+=("${temp_video_dir}/${filename}-clip.mp4")
  ffmpeg2 "${ffmpeg_args[@]}"

  echo "- Renaming & adding EXIF data"
  $EXIFTOOL -overwrite_original -tagsfromfile "${video_file}" "${temp_video_dir}/metadata-info.mie"
  $EXIFTOOL -overwrite_original -tagsfromfile "${temp_video_dir}/metadata-info.mie" "${temp_video_dir}/${filename}-clip.mp4"
  set +e
  $EXIFTOOL -overwrite_original '-datetimeoriginal<CreateDate' -if '(not $datetimeoriginal or ($datetimeoriginal eq "0000:00:00 00:00:00"))' "${temp_video_dir}/${filename}-clip.mp4"
  set -e
  $EXIFTOOL  -overwrite_original '-FileName<DateTimeOriginal' -if '($datetimeoriginal)' -d "./clip-${filename}-%Y-%m-%d_%H.%M.%S%%-c.%%le" "${temp_video_dir}/${filename}-clip.mp4"
  rm -rf "$temp_video_dir"
}

if [[ -n "$video_files" ]]; then
  process_videos
elif [[ -n "$image_file" ]]; then
  process_images
elif [[ -n "$image_mode" ]]; then
  process_images
elif [[ -n "$video_clip_args" ]]; then
  create_video_clip
else
  show_help
  exit 1
fi
