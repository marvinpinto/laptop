#!/bin/bash

set -o pipefail
set -e

myname=`basename "$0"`
video_file=""
image_file=""
live_run=""
EXIFTOOL=""
verbose=${VERBOSE:-""}
video_clip_args=""
noise_reduction_args=""
join_video_args=""

show_help() {
  echo "usage: ${myname} OPTIONS"
  echo "Available Options:"
  echo "-v <video file>: Process & fix a single video file"
  echo "   Environment variables & defaults:"
  echo "     - OUTPUT_RESOLUTION: <option> <default: 1080p>"
  echo "        - 1440p: 1920x1440"
  echo "        - 1080p: 1920x1080"
  echo "        - 720p: 1280x720"
  echo "     - ENABLE_VIDEO_STABILIZATION: yes|<empty> <default: empty>"
  echo "     - VIDEO_STABILIZATION_SMOOTHING_FACTOR: 10"
  echo "     - VIDEO_STABILIZATION_SHAKINESS_FACTOR: 5"
  echo "     - VERBOSE: yes|<empty> <default: empty>"
  echo "     - ENABLE_FISHEYE: yes|<empty> <default: yes>"
  echo "     - CURVES_PRESET_FILTER: <option> <default: none>"
  echo "        - none"
  echo "        - color_negative"
  echo "        - cross_process"
  echo "        - darker"
  echo "        - increase_contrast"
  echo "        - lighter"
  echo "        - linear_contrast"
  echo "        - medium_contrast"
  echo "        - negative"
  echo "        - strong_contrast"
  echo "        - vintage"
  echo "     - VIDEO_SAMPLE_TIME: N seconds <default: 15>"
  echo "     - LIVE_RUN: yes|<empty> <default: empty>"
  echo "-i <single image file | ALL>: Process images"
  echo "   The string \"ALL\" will process all *.jpg images in the current directory."
  echo "   Environment variables & defaults:"
  echo "     - VERBOSE: yes|<empty> <default: empty>"
  echo "-l: Perform a LIVE run (rewrite source files, cleanup, etc)"
  echo "-c <video file> <start NN:NN:NN> <end NN:NN:NN>: Create a video clip"
  echo "   Environment variables & defaults:"
  echo "     - VERBOSE: yes|<empty> <default: empty>"
  echo "-s <video file> <noise sample start NN:NN:NN> <noise sample end NN:NN:NN>: Clean up background noise"
  echo "   Environment variables & defaults:"
  echo "     - VERBOSE: yes|<empty> <default: empty>"
  echo "     - SOX_NOISE_SENSITIVITY: num> <default: 0.21> Note 0.2 >= n <= 0.3 usually provides best results"
  echo "-j <video files>: Join two or more video files together"
  echo "   Environment variables & defaults:"
  echo "     - VERBOSE: yes|<empty> <default: empty>"
  echo "     - CROSSFADE: yes|<empty> <default: empty>"
  echo "     - FADE_DURATION: N seconds> <default: 2>"
}

while getopts ":v:i:lc:s:j:" opt; do
  case "$opt" in
    v) video_file=$OPTARG
       ;;
    c) video_clip_args=("$OPTARG")
       until [[ $(eval "echo \${$OPTIND}") =~ ^-.* ]] || [ -z $(eval "echo \${$OPTIND}") ]; do
           video_clip_args+=($(eval "echo \${$OPTIND}"))
           OPTIND=$((OPTIND + 1))
       done
       ;;
    s) noise_reduction_args=("$OPTARG")
       until [[ $(eval "echo \${$OPTIND}") =~ ^-.* ]] || [ -z $(eval "echo \${$OPTIND}") ]; do
           noise_reduction_args+=($(eval "echo \${$OPTIND}"))
           OPTIND=$((OPTIND + 1))
       done
       ;;
    j) join_video_args=("$OPTARG")
       until [[ $(eval "echo \${$OPTIND}") =~ ^-.* ]] || [ -z $(eval "echo \${$OPTIND}") ]; do
           join_video_args+=($(eval "echo \${$OPTIND}"))
           OPTIND=$((OPTIND + 1))
       done
       ;;
    i) image_file=$OPTARG
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
hash ffmpeg 2>/dev/null || { echo >&2 "ffmpeg does not appear to be available."; exit 1; }
hash ffprobe 2>/dev/null || { echo >&2 "ffprobe does not appear to be available."; exit 1; }
hash sox 2>/dev/null || { echo >&2 "sox does not appear to be available."; exit 1; }


[[ "$verbose" == "yes" ]] && set -x
[[ -z "$verbose" ]] && EXIFTOOL="exiftool -ignoreMinorErrors -q -q" || EXIFTOOL="exiftool"

process_single_video() {
  local temp_video_dir=${myname}-temp-videos
  rm -rf "$temp_video_dir"
  mkdir -p "$temp_video_dir"

  local original_filename=$(basename -- "$video_file")
  local sample_time_seconds=${VIDEO_SAMPLE_TIME:-15}
  local output_resolution=${OUTPUT_RESOLUTION:-1080p}
  local video_stabilization_smoothing_factor=${VIDEO_STABILIZATION_SMOOTHING_FACTOR:-10}
  local video_stabilization_shakiness_factor=${VIDEO_STABILIZATION_SHAKINESS_FACTOR:-5}
  local enable_fisheye=${ENABLE_FISHEYE:-"yes"}
  local curves_preset_filter=${CURVES_PRESET_FILTER:-none}

  $EXIFTOOL -overwrite_original -tagsfromfile "${video_file}" "${temp_video_dir}/metadata-info.mie"

  local ffmpeg_requested_width=""
  local ffmpeg_requested_height=""
  if [[ "$output_resolution" == "1440p" ]]; then
    ffmpeg_requested_width="1920"
    ffmpeg_requested_height="1440"
  elif [[ "$output_resolution" == "1080p" ]]; then
    ffmpeg_requested_width="1920"
    ffmpeg_requested_height="1080"
  else
    ffmpeg_requested_width="1280"
    ffmpeg_requested_height="720"
  fi

  echo "- Processing video file: ${video_file}"
  echo "- Creating working copy"
  local renamed_file=${original_filename// /_}
  cp "${video_file}" "${temp_video_dir}/${renamed_file}"

  local filename=$(basename -- "$renamed_file")
  local extension="${filename##*.}"
  filename="${filename%.*}"

  local video_stabilization_filter=""
  if [[ -n "$ENABLE_VIDEO_STABILIZATION" ]]; then
    echo "- Initiating video stabilization"
    local vidstabtrf_args=()
    [[ -z "$verbose" ]] && vidstabtrf_args+=(-loglevel fatal) || vidstabtrf_args+=(-loglevel info)
    [[ -z "$LIVE_RUN" ]] && vidstabtrf_args+=(-y)
    vidstabtrf_args+=(-threads $(nproc --ignore=1))
    vidstabtrf_args+=(-i "${temp_video_dir}/${filename}.${extension}")
    [[ -z "$LIVE_RUN" ]] && vidstabtrf_args+=(-t $sample_time_seconds)
    vidstabtrf_args+=(-vf "vidstabdetect=shakiness=${video_stabilization_shakiness_factor}:result=${temp_video_dir}/${filename}-transform_vectors.trf")
    vidstabtrf_args+=(-f null -)
    ffmpeg2 "${vidstabtrf_args[@]}"

    video_stabilization_filter="vidstabtransform=input=${temp_video_dir}/${filename}-transform_vectors.trf:zoom=0:smoothing=${video_stabilization_smoothing_factor},unsharp,"
  fi

  local ffmpeg_video_aspect_ratio=$(ffprobe -v error -select_streams v:0 -show_entries stream=display_aspect_ratio -of default=nw=1:nk=1 ${video_file})
  local ffmpeg_video_width=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of default=nw=1:nk=1 ${video_file})
  local ffmpeg_video_height=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of default=nw=1:nk=1 ${video_file})

  # If the input video's aspect ratio is already 16x9, scale it down to the requested (resolution) height (if the requested height is less than the current height, since we only scale down) - e.g. scale=-2:'min(REQUESTED_HEIGHT,ih)'
  # If the input video's aspect ratio is *not* 16:9, crop, then scale it to the requested size.
  # The second option will throw an error if the input video is less than the requested resolution, since we only scale down.
  local ffmpeg_resolution_filter=""
  if [[ "$ffmpeg_video_aspect_ratio" == "16:9" ]]; then
    echo "- Downscaling file to ${ffmpeg_requested_width}x${ffmpeg_requested_height}"
    ffmpeg_resolution_filter="scale=-2:'min(${ffmpeg_requested_height},ih)'"
  else
    if [[ $ffmpeg_requested_height -gt $ffmpeg_video_height ]]; then
      echo "Error: Requested resolution of ${ffmpeg_requested_width}x${ffmpeg_requested_height} is larger resolution of ${video_file} (${ffmpeg_video_width}x${ffmpeg_video_height})."
      exit 1
    fi

    echo "- Cropping & downscaling file to ${ffmpeg_requested_width}x${ffmpeg_requested_height}"
    ffmpeg_resolution_filter="crop=w=${ffmpeg_requested_width}:h=${ffmpeg_requested_height},scale=-2:${ffmpeg_requested_height}"
  fi

  echo "- Re-encoding video"
  local base_video_filter="${video_stabilization_filter}${ffmpeg_resolution_filter},curves=preset='${curves_preset_filter}'"
  local reencode_output_filename_type=""
  [[ -z "$LIVE_RUN" ]] && reencode_output_filename_type="sample"
  [[ -n "$LIVE_RUN" ]] && reencode_output_filename_type="reencoded"
  reencode_args=()
  [[ -z "$verbose" ]] && reencode_args+=(-loglevel fatal) || reencode_args+=(-loglevel info)
  [[ -z "$LIVE_RUN" ]] && reencode_args+=(-y)
  reencode_args+=(-threads $(nproc --ignore=1))
  reencode_args+=(-i "${temp_video_dir}/${filename}.${extension}")
  [[ -z "$LIVE_RUN" ]] && reencode_args+=(-t $sample_time_seconds)
  [[ -n "$enable_fisheye" ]] && reencode_args+=(-vf "${base_video_filter},lenscorrection=k1=-0.227:k2=-0.022") || reencode_args+=(-vf "${base_video_filter}")
  reencode_args+=(-vcodec libx264)
  reencode_args+=(-acodec copy)
  reencode_args+=(-preset slow)
  reencode_args+=(-crf 15)
  reencode_args+=("${temp_video_dir}/${filename}-${reencode_output_filename_type}.mp4")
  ffmpeg2 "${reencode_args[@]}"

  if [[ -z "$LIVE_RUN" ]]; then
    echo "- Generating side-by-side sample"
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

  echo "- EXIF metadata"
  find ${temp_video_dir}/ -maxdepth 1 -iname "${filename}*.mp4" | while read file; do
    $EXIFTOOL -overwrite_original -tagsfromfile "${temp_video_dir}/metadata-info.mie" "${file}"
    set +e
    $EXIFTOOL -overwrite_original '-datetimeoriginal<CreateDate' -if '(not $datetimeoriginal or ($datetimeoriginal eq "0000:00:00 00:00:00"))' "${file}"
    set -e
  done

  echo "- Renaming re-encoded outputs"
  find "${temp_video_dir}/" -iname "${filename}.mp4" -exec $EXIFTOOL -overwrite_original '-FileName<DateTimeOriginal' -if '($datetimeoriginal)' -d "%Y-%m-%d_%H.%M.%S%%-c-${filename}.%%le" {} \;
  [[ -z "$LIVE_RUN" ]] && $EXIFTOOL  -overwrite_original '-FileName<DateTimeOriginal' -if '($datetimeoriginal)' -d "%Y-%m-%d_%H.%M.%S%%-c-${filename}-${reencode_output_filename_type}.%%le" "${temp_video_dir}/${filename}-${reencode_output_filename_type}.mp4"
  [[ -z "$LIVE_RUN" ]] && $EXIFTOOL  -overwrite_original '-FileName<DateTimeOriginal' -if '($datetimeoriginal)' -d "%Y-%m-%d_%H.%M.%S%%-c-${filename}-combined.%%le" "${temp_video_dir}/${filename}-combined.mp4"

  if [[ -z "$LIVE_RUN" ]]; then
    echo -ne "\n"
    echo "****************************"
    echo " Sample Generation Complete "
    echo "****************************"
    echo "Look through the ${temp_video_dir} directory for updated files and side-by-side comparisons"
    echo -ne "\n"
    echo "If everything looks good, re-run this script with the -l flag."
  fi

  if [[ -n "$LIVE_RUN" ]]; then
    echo "- Final cleanup"
    mv ${temp_video_dir}/*${filename}-${reencode_output_filename_type}.mp4 .
    $EXIFTOOL  -overwrite_original '-FileName<DateTimeOriginal' -if '($datetimeoriginal)' -d "%Y-%m-%d_%H.%M.%S%%-c.%%le" *${filename}-${reencode_output_filename_type}.mp4
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

  if [[ "$image_file" == "ALL" ]]; then
    # Process all jpg images in the current directory
    find . -maxdepth 1 -iname "*.jpg" | while read file; do
      process_single_image "$file" "$temp_image_dir"
    done
  else
    process_single_image "$image_file" "$temp_image_dir"
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

clean_background_noise() {
  local temp_video_dir=${myname}-temp-videos
  rm -rf "$temp_video_dir"
  mkdir -p "$temp_video_dir"

  local video_file=${noise_reduction_args[0]}
  local noise_start=${noise_reduction_args[1]}
  local noise_end=${noise_reduction_args[2]}

  local original_filename=$(basename -- "$video_file")
  local renamed_file=${original_filename// /_}
  local filename=$(basename -- "$renamed_file")
  local extension="${filename##*.}"
  filename="${filename%.*}"
  local sox_noise_sensitivity=${SOX_NOISE_SENSITIVITY:-0.21}

  echo "- Separating video stream"
  local ffmpeg_noise_video_stream_args=()
  [[ -z "$verbose" ]] && ffmpeg_noise_video_stream_args+=(-loglevel fatal) || ffmpeg_noise_video_stream_args+=(-loglevel info)
  [[ -z "$live_run" ]] && ffmpeg_noise_video_stream_args+=(-y)
  ffmpeg_noise_video_stream_args+=(-threads $(nproc --ignore=1))
  ffmpeg_noise_video_stream_args+=(-i "${video_file}")
  ffmpeg_noise_video_stream_args+=(-vcodec copy)
  ffmpeg_noise_video_stream_args+=(-an)
  ffmpeg_noise_video_stream_args+=("${temp_video_dir}/${filename}-video_stream.mp4")
  ffmpeg2 "${ffmpeg_noise_video_stream_args[@]}"

  echo "- Separating audio stream"
  local ffmpeg_noise_audio_stream_args=()
  [[ -z "$verbose" ]] && ffmpeg_noise_audio_stream_args+=(-loglevel fatal) || ffmpeg_noise_audio_stream_args+=(-loglevel info)
  [[ -z "$live_run" ]] && ffmpeg_noise_audio_stream_args+=(-y)
  ffmpeg_noise_audio_stream_args+=(-threads $(nproc --ignore=1))
  ffmpeg_noise_audio_stream_args+=(-i "${video_file}")
  ffmpeg_noise_audio_stream_args+=(-acodec pcm_s16le)
  ffmpeg_noise_audio_stream_args+=(-ar 128k)
  ffmpeg_noise_audio_stream_args+=(-vn)
  ffmpeg_noise_audio_stream_args+=("${temp_video_dir}/${filename}-audio_stream.wav")
  ffmpeg2 "${ffmpeg_noise_audio_stream_args[@]}"

  echo "- Generating noise sample"
  local ffmpeg_noise_sample_args=()
  [[ -z "$verbose" ]] && ffmpeg_noise_sample_args+=(-loglevel fatal) || ffmpeg_noise_sample_args+=(-loglevel info)
  [[ -z "$live_run" ]] && ffmpeg_noise_sample_args+=(-y)
  ffmpeg_noise_sample_args+=(-threads $(nproc --ignore=1))
  ffmpeg_noise_sample_args+=(-i "${video_file}")
  ffmpeg_noise_sample_args+=(-acodec pcm_s16le)
  ffmpeg_noise_sample_args+=(-ar 128k)
  ffmpeg_noise_sample_args+=(-vn)
  ffmpeg_noise_sample_args+=(-ss "${noise_start}")
  ffmpeg_noise_sample_args+=(-to "${noise_end}")
  ffmpeg_noise_sample_args+=("${temp_video_dir}/${filename}-noise-sample.wav")
  ffmpeg2 "${ffmpeg_noise_sample_args[@]}"

  echo "- Generating noise profile"
  sox "${temp_video_dir}/${filename}-noise-sample.wav" -n noiseprof "${temp_video_dir}/${filename}-sox-noise-profile.prof"

  echo "- Cleaning audio noise"
  sox "${temp_video_dir}/${filename}-audio_stream.wav" "${temp_video_dir}/${filename}-audio_stream_cleaned.wav" noisered "${temp_video_dir}/${filename}-sox-noise-profile.prof" ${sox_noise_sensitivity}

  echo "- Merging cleaned audio & video streams"
  local ffmpeg_noise_merge_streams_args=()
  [[ -z "$verbose" ]] && ffmpeg_noise_merge_streams_args+=(-loglevel fatal) || ffmpeg_noise_merge_streams_args+=(-loglevel info)
  [[ -z "$live_run" ]] && ffmpeg_noise_merge_streams_args+=(-y)
  ffmpeg_noise_merge_streams_args+=(-threads $(nproc --ignore=1))
  ffmpeg_noise_merge_streams_args+=(-i "${temp_video_dir}/${filename}-video_stream.mp4")
  ffmpeg_noise_merge_streams_args+=(-i "${temp_video_dir}/${filename}-audio_stream_cleaned.wav")
  ffmpeg_noise_merge_streams_args+=(-map 0:v)
  ffmpeg_noise_merge_streams_args+=(-map 1:a)
  ffmpeg_noise_merge_streams_args+=(-c:v copy)
  ffmpeg_noise_merge_streams_args+=(-c:a aac)
  ffmpeg_noise_merge_streams_args+=(-b:a 128k)
  ffmpeg_noise_merge_streams_args+=("${temp_video_dir}/${filename}-cleaned.mp4")
  ffmpeg2 "${ffmpeg_noise_merge_streams_args[@]}"

  echo "- Renaming & adding EXIF data"
  $EXIFTOOL -overwrite_original -tagsfromfile "${video_file}" "${temp_video_dir}/metadata-info.mie"
  $EXIFTOOL -overwrite_original -tagsfromfile "${temp_video_dir}/metadata-info.mie" "${temp_video_dir}/${filename}-cleaned.mp4"
  set +e
  $EXIFTOOL -overwrite_original '-datetimeoriginal<CreateDate' -if '(not $datetimeoriginal or ($datetimeoriginal eq "0000:00:00 00:00:00"))' "${temp_video_dir}/${filename}-cleaned.mp4"
  set -e
  $EXIFTOOL  -overwrite_original '-FileName<DateTimeOriginal' -if '($datetimeoriginal)' -d "./noise-cleaned-${filename}-%Y-%m-%d_%H.%M.%S%%-c.%%le" "${temp_video_dir}/${filename}-cleaned.mp4"
  rm -rf "$temp_video_dir"
}

join_video_files() {
  local temp_video_dir=${myname}-temp-videos
  rm -rf "$temp_video_dir"
  mkdir -p "$temp_video_dir"

  local ffmpeg_input_args=()
  local ffmpeg_filter_str=()
  local ARRAY_CTR=0
  local FFMPEG_IDX_CTR=0
  local fade_duration_secs=${FADE_DURATION:-2}

  if [[ ${#join_video_args[@]} -lt 2 ]]; then
    echo "Error: Supply at least two video_file arguments"
    exit 1
  fi

  # Copy over the video metadata, for later
  $EXIFTOOL -overwrite_original -tagsfromfile "${join_video_args[0]}" "${temp_video_dir}/metadata-info.mie"

  [[ -z "$verbose" ]] && ffmpeg_input_args+=(-loglevel fatal) || ffmpeg_input_args+=(-loglevel info)
  ffmpeg_input_args+=(-y)
  ffmpeg_input_args+=(-threads $(nproc --ignore=1))

  local ffmpeg_fade_suffix=()
  local ffmpeg_acrossfade_suffix=()

  if [[ -n "$CROSSFADE" ]]; then
    echo "- Joining and crossfading the following input files: ${join_video_args[@]}"
  else
    echo "- Joining the following input files: ${join_video_args[@]}"
  fi

  for video in "${join_video_args[@]}"; do
    local previous_video_clip=""
    local current_video_clip="$video"
    if [[ "$current_video_clip" != "${join_video_args[0]}" ]]; then
      previous_video_clip="${join_video_args[$((ARRAY_CTR-1))]}"
    fi

    # If this is the first clip in the sequence, we need to generate a blank
    # dummy clip to "lead in" to this one.
    if [[ -n "$CROSSFADE" ]] && [[ -z "${previous_video_clip}" ]]; then
      local avg_frame_rate=$(echo "$(ffprobe -v error -select_streams v:0 -show_entries stream=avg_frame_rate -of default=nw=1:nk=1 ${current_video_clip})" | bc)
      local audio_channel_layout=$(ffprobe -v error -select_streams a:0 -show_entries stream=channel_layout -of default=nw=1:nk=1 ${current_video_clip})
      local audio_sample_rate=$(ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate -of default=nw=1:nk=1 ${current_video_clip})
      local video_height=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of default=nw=1:nk=1 ${current_video_clip})
      local video_width=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of default=nw=1:nk=1 ${current_video_clip})

      echo "- Generating dummy video to lead in to ${current_video_clip}"
      local dummy_lead_in_duration=$fade_duration_secs
      local ffmpeg_dummy_leadin_args=()
      [[ -z "$verbose" ]] && ffmpeg_dummy_leadin_args+=(-loglevel fatal) || ffmpeg_dummy_leadin_args+=(-loglevel info)
      [[ -z "$live_run" ]] && ffmpeg_dummy_leadin_args+=(-y)
      ffmpeg_dummy_leadin_args+=(-threads $(nproc --ignore=1))
      ffmpeg_dummy_leadin_args+=(-f lavfi)
      ffmpeg_dummy_leadin_args+=(-i "color=black:s=${video_width}x${video_height}:r=${avg_frame_rate}")
      ffmpeg_dummy_leadin_args+=(-f lavfi)
      ffmpeg_dummy_leadin_args+=(-i "anullsrc=r=${audio_sample_rate}:cl=${audio_channel_layout}")
      ffmpeg_dummy_leadin_args+=(-vcodec libx264)
      ffmpeg_dummy_leadin_args+=(-acodec aac)
      ffmpeg_dummy_leadin_args+=(-t ${dummy_lead_in_duration})
      ffmpeg_dummy_leadin_args+=("${temp_video_dir}/empty_${dummy_lead_in_duration}.mp4")
      ffmpeg2 "${ffmpeg_dummy_leadin_args[@]}"

      # Initialize the compound string with the dummy video
      previous_video_clip="${temp_video_dir}/empty_${dummy_lead_in_duration}.mp4"
      ffmpeg_input_args+=(-i "${temp_video_dir}/empty_${dummy_lead_in_duration}.mp4")

      # Add an appropriate audio-crossfade filter
      ffmpeg_acrossfade_suffix+=([0:a:0][1:a:0]acrossfade=d=${fade_duration_secs}[1-a]\;)
    else
      # Add an appropriate audio-crossfade filter
      ffmpeg_acrossfade_suffix+=([${FFMPEG_IDX_CTR}-a][$((FFMPEG_IDX_CTR+1)):a:0]acrossfade=d=${fade_duration_secs}[$((FFMPEG_IDX_CTR+1))-a]\;)
    fi

    ffmpeg_input_args+=(-i "$current_video_clip")

    if [[ -n "$CROSSFADE" ]]; then
      local prev_video_duration=$(ffprobe -v error -select_streams v:0 -show_entries stream=duration -of default=nw=1:nk=1 "${previous_video_clip}")
      local prev_video_start=$(echo "$prev_video_duration - $fade_duration_secs" | bc)

      # Generate the last portion of the previous clip, which will be used as the fadeout
      ffmpeg_filter_str+=([${FFMPEG_IDX_CTR}:v:0] trim=start=${prev_video_start},setpts=PTS-STARTPTS[clip-${FFMPEG_IDX_CTR}-fadeoutsrc-v]\;)
      FFMPEG_IDX_CTR=$((FFMPEG_IDX_CTR+1))

      # Generate the clip + fadein for the current video
      local curr_video_duration=$(ffprobe -v error -select_streams v:0 -show_entries stream=duration -of default=nw=1:nk=1 "${current_video_clip}")

      # If this is the last clip in the series, run it all the way to the end
      local curr_video_end=$(echo "$curr_video_duration - $fade_duration_secs" | bc)
      if [[ $((ARRAY_CTR+1)) -eq ${#join_video_args[@]} ]]; then
        curr_video_end=$curr_video_duration
      fi

      ffmpeg_filter_str+=([${FFMPEG_IDX_CTR}:v:0] trim=start=0:end=${fade_duration_secs},setpts=PTS-STARTPTS[clip-${FFMPEG_IDX_CTR}-fadeinsrc-v]\;)
      ffmpeg_filter_str+=([${FFMPEG_IDX_CTR}:v:0] trim=start=${fade_duration_secs}:end=${curr_video_end},setpts=PTS-STARTPTS[clip-${FFMPEG_IDX_CTR}-clip-v]\;)

      # Generate the fadein/fadeout portions
      ffmpeg_filter_str+=([clip-$((FFMPEG_IDX_CTR-1))-fadeoutsrc-v] format=pix_fmts=yuva420p,fade=t=out:st=0:d=${fade_duration_secs}:alpha=1[clip-${FFMPEG_IDX_CTR}-fadeout-v]\;)
      ffmpeg_filter_str+=([clip-${FFMPEG_IDX_CTR}-fadeinsrc-v] format=pix_fmts=yuva420p,fade=t=in:st=0:d=${fade_duration_secs}:alpha=1[clip-${FFMPEG_IDX_CTR}-fadein-v]\;)

      # Generate the fifo/crossfade portions
      ffmpeg_filter_str+=([clip-${FFMPEG_IDX_CTR}-fadeout-v]fifo[clip-${FFMPEG_IDX_CTR}-fadeoutfifo-v]\;)
      ffmpeg_filter_str+=([clip-${FFMPEG_IDX_CTR}-fadein-v]fifo[clip-${FFMPEG_IDX_CTR}-fadeinfifo-v]\;)
      ffmpeg_filter_str+=([clip-${FFMPEG_IDX_CTR}-fadeoutfifo-v][clip-${FFMPEG_IDX_CTR}-fadeinfifo-v]overlay[clip-${FFMPEG_IDX_CTR}-crossfade-v]\;)

      # Finally add these generated clips in order
      ffmpeg_fade_suffix+=([clip-${FFMPEG_IDX_CTR}-crossfade-v][clip-${FFMPEG_IDX_CTR}-clip-v])
    else
      ffmpeg_filter_str+=([${ARRAY_CTR}:v:0][${ARRAY_CTR}:a:0])
    fi

    ARRAY_CTR=$((ARRAY_CTR+1))
  done

  # Map the final audio stream to "outa"
  ffmpeg_acrossfade_suffix+=([${FFMPEG_IDX_CTR}-a]afifo[outa]\;)

  local filter_str="$(echo -e "${ffmpeg_filter_str[@]}" | tr -d '[:space:]')"
  local concat_ctr=$(echo "$FFMPEG_IDX_CTR * 2" | bc)
  if [[ -n "$CROSSFADE" ]]; then
    filter_str+="$(echo -e "${ffmpeg_acrossfade_suffix[@]}" | tr -d '[:space:]')"
    filter_str+="$(echo -e "${ffmpeg_fade_suffix[@]}" | tr -d '[:space:]')"
    filter_str+="concat=n=${concat_ctr}:v=1:a=0[outv]"
  else
    filter_str+="concat=n=${ARRAY_CTR}:v=1:a=1[outv][outa]"
  fi

  echo "- Finalizing joined ouput"
  # For whatever reason, using acrossfade with the following commands results
  # in a segfault on "ffmpeg2", yet works correctly with "ffmpeg".
  ffmpeg ${ffmpeg_input_args[@]} -an -filter_complex "${filter_str}" -map "[outv]" -map "[outa]" -vcodec libx264 -acodec aac -strict experimental ${temp_video_dir}/joined-output.mp4
  $EXIFTOOL -overwrite_original -tagsfromfile "${temp_video_dir}/metadata-info.mie" "${temp_video_dir}/joined-output.mp4"
  set +e
  $EXIFTOOL -overwrite_original '-datetimeoriginal<CreateDate' -if '(not $datetimeoriginal or ($datetimeoriginal eq "0000:00:00 00:00:00"))' "${temp_video_dir}/joined-output.mp4"
  set -e

  echo "- Cleaning up"
  mv "${temp_video_dir}/joined-output.mp4" .
  $EXIFTOOL  -overwrite_original '-FileName<DateTimeOriginal' -if '($datetimeoriginal)' -d "joined-output-%Y-%m-%d_%H.%M.%S%%-c.%%le" "./joined-output.mp4"
  rm -rf "$temp_video_dir"
}

if [[ -n "$video_file" ]]; then
  process_single_video
elif [[ -n "$image_file" ]]; then
  process_images
elif [[ -n "$video_clip_args" ]]; then
  create_video_clip
elif [[ -n "$noise_reduction_args" ]]; then
  clean_background_noise
elif [[ -n "$join_video_args" ]]; then
  join_video_files
else
  show_help
  exit 1
fi
