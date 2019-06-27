#!/bin/bash

set -o pipefail
set -e

myname=`basename "$0"`
video_file=""
image_file=""
EXIFTOOL=""
verbose=${VERBOSE:-""}
video_clip_args=""
noise_reduction_args=""
join_video_args=""
create_lead_video_clip_args=""
change_video_speed_args=""
add_audio_clip_args=""
finalize_video_file_arg=""
CRF_FACTOR=22

show_help() {
  echo "usage: ${myname} OPTIONS"
  echo "Available Options:"
  echo "-v <video file>: Stabilize a single video file, in preparation for further processing (e.g. with kdenlive)"
  echo "   Environment variables & defaults:"
  echo "     - VIDEO_STABILIZATION_SMOOTHING_FACTOR: 10"
  echo "     - VIDEO_STABILIZATION_SHAKINESS_FACTOR: 5"
  echo "     - VERBOSE: yes|<empty> <default: empty>"
  echo "     - VIDEO_SAMPLE_TIME: N seconds <default: 15>"
  echo "     - LIVE_RUN: yes|<empty> <default: empty>"
  echo "-i <single image file | ALL>: Process images"
  echo "   The string \"ALL\" will process all *.jpg images in the current directory."
  echo "   Environment variables & defaults:"
  echo "     - VERBOSE: yes|<empty> <default: empty>"
  echo "     - LIVE_RUN: yes|<empty> <default: empty>"
  echo "-c <video file> <start NN:NN:NN> <end NN:NN:NN>: Create a video clip"
  echo "   Environment variables & defaults:"
  echo "     - VERBOSE: yes|<empty> <default: empty>"
  echo "-n <video file> <noise sample start NN:NN:NN> <noise sample end NN:NN:NN>: Clean up background noise"
  echo "   Environment variables & defaults:"
  echo "     - VERBOSE: yes|<empty> <default: empty>"
  echo "     - SOX_NOISE_SENSITIVITY: num> <default: 0.21> Note 0.2 >= n <= 0.3 usually provides best results"
  echo "-j <video files>: Join two or more video files together"
  echo "   Environment variables & defaults:"
  echo "     - VERBOSE: yes|<empty> <default: empty>"
  echo "     - CROSSFADE: yes|<empty> <default: empty>"
  echo "     - FADE_DURATION: N seconds> <default: 2>"
  echo "     - METADATA_FILE_INDEX: N> <default: 0>"
  echo "-l <text>: Create a lead video clip with the specified text"
  echo "   e.g: ${myname} -l \"Europe Trip 2019\" -l \"Day trip to Germany\" -l \"Feb 17, 2019\""
  echo "   Environment variables & defaults:"
  echo "     - VERBOSE: yes|<empty> <default: empty>"
  echo "     - OUTPUT_RESOLUTION: <option> <default: 1080p>"
  echo "        - 1440p: 1920x1440"
  echo "        - 1080p: 1920x1080"
  echo "        - 720p: 1280x720"
  echo "     - CLIP_DURATION: N seconds <default: 4>"
  echo "-s <video file> <speed factor>: Speed up or slow down a video clip"
  echo "   e.g: ${myname} -s input.mp4 4"
  echo "   Environment variables & defaults:"
  echo "     - VERBOSE: yes|<empty> <default: empty>"
  echo "-a <video file> <audio file> [start NN:NN:NN - default 00:00:00]: Add an audio clip to a video, starting from NN:NN:NN in the audio file"
  echo "   Royalty free music available at https://www.youtube.com/audiolibrary/music"
  echo "   Environment variables & defaults:"
  echo "     - VERBOSE: yes|<empty> <default: empty>"
  echo "-f <video file>: Finalize the video file (fade in/out, write file metadata, etc)"
  echo "   Environment variables & defaults:"
  echo "     - VERBOSE: yes|<empty> <default: empty>"
  echo "     - FADE_DURATION: N seconds> <default: 2>"
  echo "     - METADATA_TITLE: <string> <default: \"\">"
  echo "     - METADATA_ARTIST: <string> <default: \"Marvin Pinto\">"
  echo "     - METADATA_DESC: <string> <default: \"\">"
  echo "-z: Do a bit of local cleanup"
}

while getopts ":v:i:c:n:j:l:s:a:f:z" opt; do
  case "$opt" in
    v) video_file=$OPTARG
       ;;
    c) video_clip_args=("$OPTARG")
       until [[ $(eval "echo \${$OPTIND}") =~ ^-.* ]] || [ -z $(eval "echo \${$OPTIND}") ]; do
           video_clip_args+=($(eval "echo \${$OPTIND}"))
           OPTIND=$((OPTIND + 1))
       done
       ;;
    n) noise_reduction_args=("$OPTARG")
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
    l) create_lead_video_clip_args+=("$OPTARG")
       ;;
    s) change_video_speed_args=("$OPTARG")
       until [[ $(eval "echo \${$OPTIND}") =~ ^-.* ]] || [ -z $(eval "echo \${$OPTIND}") ]; do
           change_video_speed_args+=($(eval "echo \${$OPTIND}"))
           OPTIND=$((OPTIND + 1))
       done
       ;;
    a) add_audio_clip_args=("$OPTARG")
       until [[ $(eval "echo \${$OPTIND}") =~ ^-.* ]] || [ -z $(eval "echo \${$OPTIND}") ]; do
           add_audio_clip_args+=($(eval "echo \${$OPTIND}"))
           OPTIND=$((OPTIND + 1))
       done
       ;;
    f) finalize_video_file_arg=$OPTARG
       ;;
    z) echo "- Cleaning up"
       rm -rf "${myname}-temp-videos" "${myname}-temp-images"
       exit 0
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
shift $((OPTIND -1))

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
  mkdir -p "$temp_video_dir"

  local original_filename=$(basename -- "$video_file")
  local sample_time_seconds=${VIDEO_SAMPLE_TIME:-15}
  local video_stabilization_smoothing_factor=${VIDEO_STABILIZATION_SMOOTHING_FACTOR:-10}
  local video_stabilization_shakiness_factor=${VIDEO_STABILIZATION_SHAKINESS_FACTOR:-5}

  echo "- Processing video file: ${video_file}"
  echo "- Creating working copy"
  local renamed_file=${original_filename// /_}
  cp "${video_file}" "${temp_video_dir}/${renamed_file}"

  local filename=$(basename -- "$renamed_file")
  local extension="${filename##*.}"
  filename="${filename%.*}"

  $EXIFTOOL -overwrite_original -tagsfromfile "${video_file}" "${temp_video_dir}/${filename}-metadata-info.mie"

  local video_stabilization_filter=""
  echo "- Initiating video stabilization"
  local vidstabtrf_args=()
  [[ -z "$verbose" ]] && vidstabtrf_args+=(-loglevel fatal) || vidstabtrf_args+=(-loglevel info)
  vidstabtrf_args+=(-y)
  vidstabtrf_args+=(-threads $(nproc --ignore=1))
  vidstabtrf_args+=(-i "pipe:0")
  [[ -z "$LIVE_RUN" ]] && vidstabtrf_args+=(-t $sample_time_seconds)
  vidstabtrf_args+=(-vf "vidstabdetect=stepsize=32:shakiness=${video_stabilization_shakiness_factor}:accuracy=10:result=${temp_video_dir}/${filename}-transform_vectors.trf")
  vidstabtrf_args+=(-f null -)
  pv "${temp_video_dir}/${filename}.${extension}" | ffmpeg2 "${vidstabtrf_args[@]}"

  video_stabilization_filter="vidstabtransform=input=${temp_video_dir}/${filename}-transform_vectors.trf:zoom=0:smoothing=${video_stabilization_smoothing_factor},unsharp=5:5:0.8:3:3:0.4"

  echo "- Re-encoding video"
  local reencode_output_filename_type=""
  [[ -z "$LIVE_RUN" ]] && reencode_output_filename_type="sample"
  [[ -n "$LIVE_RUN" ]] && reencode_output_filename_type="reencoded"
  reencode_args=()
  [[ -z "$verbose" ]] && reencode_args+=(-loglevel fatal) || reencode_args+=(-loglevel info)
  reencode_args+=(-y)
  reencode_args+=(-threads $(nproc --ignore=1))
  reencode_args+=(-i "pipe:0")
  [[ -z "$LIVE_RUN" ]] && reencode_args+=(-t $sample_time_seconds)
  reencode_args+=(-vf "${video_stabilization_filter}")
  reencode_args+=(-vcodec libx264)
  reencode_args+=(-acodec copy)
  reencode_args+=(-preset slow)
  reencode_args+=(-crf ${CRF_FACTOR})
  reencode_args+=("${temp_video_dir}/${filename}-${reencode_output_filename_type}.mp4")
  pv "${temp_video_dir}/${filename}.${extension}" | ffmpeg2 "${reencode_args[@]}"

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
    $EXIFTOOL -overwrite_original -tagsfromfile "${temp_video_dir}/${filename}-metadata-info.mie" "${file}"
    set +e
    $EXIFTOOL -overwrite_original '-datetimeoriginal<CreateDate' -if '(not $datetimeoriginal or ($datetimeoriginal eq "0000:00:00 00:00:00"))' "${file}"
    set -e
  done

  echo "- Renaming re-encoded outputs"
  find "${temp_video_dir}/" -iname "${filename}.mp4" -exec $EXIFTOOL -overwrite_original '-FileName<DateTimeOriginal' -if '($datetimeoriginal)' -d "${filename}.%%le" {} \;
  [[ -z "$LIVE_RUN" ]] && $EXIFTOOL  -overwrite_original '-FileName<DateTimeOriginal' -if '($datetimeoriginal)' -d "${filename}-${reencode_output_filename_type}.%%le" "${temp_video_dir}/${filename}-${reencode_output_filename_type}.mp4"
  [[ -z "$LIVE_RUN" ]] && $EXIFTOOL  -overwrite_original '-FileName<DateTimeOriginal' -if '($datetimeoriginal)' -d "${filename}-combined.%%le" "${temp_video_dir}/${filename}-combined.mp4"

  if [[ -z "$LIVE_RUN" ]]; then
    echo -ne "\n"
    echo "****************************"
    echo " Sample Generation Complete "
    echo "****************************"
    echo "Look through the ${temp_video_dir} directory for updated files and side-by-side comparisons"
    echo -ne "\n"
    echo "If everything looks good, re-run this script with the LIVE_RUN=yes flag."
  fi

  if [[ -n "$LIVE_RUN" ]]; then
    echo "- Final cleanup"
    mv ${temp_video_dir}/*${filename}-${reencode_output_filename_type}.mp4 .
    $EXIFTOOL  -overwrite_original '-FileName<DateTimeOriginal' -if '($datetimeoriginal)' -d "${filename}-stabilized.%%le" *${filename}-${reencode_output_filename_type}.mp4
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

  if [[ -z "$LIVE_RUN" ]]; then
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

  if [[ -n "$LIVE_RUN" ]]; then
    echo "    - Cleanup: ${filename}.jpg"
    rm -f ${temp_image_dir}/*-${filename}-combined.jpg
    mv ${temp_image_dir}/*-${filename}.jpg .
    rm -f "${file}"
    $EXIFTOOL -overwrite_original '-FileName<DateTimeOriginal' -d "%Y-%m-%d_%H.%M.%S%%-c.%%le" *-${filename}.jpg
  fi
}

process_images() {
  local temp_image_dir=${myname}-temp-images
  mkdir -p "$temp_image_dir"

  if [[ "$image_file" == "ALL" ]]; then
    # Process all jpg images in the current directory
    find . -maxdepth 1 -iname "*.jpg" | while read file; do
      process_single_image "$file" "$temp_image_dir"
    done
  else
    process_single_image "$image_file" "$temp_image_dir"
  fi

  if [[ -z "$LIVE_RUN" ]]; then
    echo -ne "\n"
    echo "****************************"
    echo " Sample Generation Complete "
    echo "****************************"
    echo "Look through the ${temp_image_dir} directory for updated files and side-by-side comparisons"
    echo -ne "\n"
    echo "If everything looks good, re-run this script with the -l flag."
  fi
}

create_video_clip() {
  local temp_video_dir=${myname}-temp-videos
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
  ffmpeg_args+=(-y)
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
  $EXIFTOOL -overwrite_original -tagsfromfile "${video_file}" "${temp_video_dir}/${filename}-metadata-info.mie"
  $EXIFTOOL -overwrite_original -tagsfromfile "${temp_video_dir}/${filename}-metadata-info.mie" "${temp_video_dir}/${filename}-clip.mp4"
  set +e
  $EXIFTOOL -overwrite_original '-datetimeoriginal<CreateDate' -if '(not $datetimeoriginal or ($datetimeoriginal eq "0000:00:00 00:00:00"))' "${temp_video_dir}/${filename}-clip.mp4"
  set -e
  $EXIFTOOL  -overwrite_original '-FileName<DateTimeOriginal' -if '($datetimeoriginal)' -d "./clip-${filename}-%Y-%m-%d_%H.%M.%S%%-c.%%le" "${temp_video_dir}/${filename}-clip.mp4"
}

clean_background_noise() {
  local temp_video_dir=${myname}-temp-videos
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
  ffmpeg_noise_video_stream_args+=(-y)
  ffmpeg_noise_video_stream_args+=(-threads $(nproc --ignore=1))
  ffmpeg_noise_video_stream_args+=(-i "${video_file}")
  ffmpeg_noise_video_stream_args+=(-vcodec copy)
  ffmpeg_noise_video_stream_args+=(-an)
  ffmpeg_noise_video_stream_args+=("${temp_video_dir}/${filename}-video_stream.mp4")
  ffmpeg2 "${ffmpeg_noise_video_stream_args[@]}"

  echo "- Separating audio stream"
  local ffmpeg_noise_audio_stream_args=()
  [[ -z "$verbose" ]] && ffmpeg_noise_audio_stream_args+=(-loglevel fatal) || ffmpeg_noise_audio_stream_args+=(-loglevel info)
  ffmpeg_noise_audio_stream_args+=(-y)
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
  ffmpeg_noise_sample_args+=(-y)
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
  ffmpeg_noise_merge_streams_args+=(-y)
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
  $EXIFTOOL -overwrite_original -tagsfromfile "${video_file}" "${temp_video_dir}/${filename}-metadata-info.mie"
  $EXIFTOOL -overwrite_original -tagsfromfile "${temp_video_dir}/${filename}-metadata-info.mie" "${temp_video_dir}/${filename}-cleaned.mp4"
  set +e
  $EXIFTOOL -overwrite_original '-datetimeoriginal<CreateDate' -if '(not $datetimeoriginal or ($datetimeoriginal eq "0000:00:00 00:00:00"))' "${temp_video_dir}/${filename}-cleaned.mp4"
  set -e
  $EXIFTOOL  -overwrite_original '-FileName<DateTimeOriginal' -if '($datetimeoriginal)' -d "./noise-cleaned-${filename}-%Y-%m-%d_%H.%M.%S%%-c.%%le" "${temp_video_dir}/${filename}-cleaned.mp4"
}

join_video_files() {
  local temp_video_dir=${myname}-temp-videos
  mkdir -p "$temp_video_dir"

  local ffmpeg_input_args=()
  local ffmpeg_filter_str=()
  local ARRAY_CTR=0
  local FFMPEG_IDX_CTR=0
  local fade_duration_secs=${FADE_DURATION:-2}
  local metadata_file_index=${METADATA_FILE_INDEX:-0}

  if [[ ${#join_video_args[@]} -lt 2 ]]; then
    echo "Error: Supply at least two video_file arguments"
    exit 1
  fi

  # Create a "unique" string from the names of the joined files
  local unique_str=""
  for bn_video in "${join_video_args[@]}"; do
    local bn=$(basename -- "$bn_video")
    unique_str+="$bn"
  done
  unique_str=$(echo "$unique_str" | tr '[:upper:]' '[:lower:]' | sed -e 's/[^a-z._-]/_/g')

  # Copy over the video metadata, for later
  $EXIFTOOL -overwrite_original -tagsfromfile "${join_video_args[${metadata_file_index}]}" "${temp_video_dir}/${unique_str}-metadata-info.mie"

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

    if [[ -n "$CROSSFADE" ]] && [[ -n "${previous_video_clip}" ]]; then
      # If this is not the first clip in the sequence, add an appropriate
      # audio-crossfade filter.
      ffmpeg_acrossfade_suffix+=([${FFMPEG_IDX_CTR}-a][$((FFMPEG_IDX_CTR+1)):a:0]acrossfade=d=${fade_duration_secs}[$((FFMPEG_IDX_CTR+1))-a]\;)
    elif [[ -n "$CROSSFADE" ]]; then
      # Add an appropriate audio-crossfade filter for the first clip in the
      # sequence - basically copies the stream to a named output
      ffmpeg_acrossfade_suffix+=([0:a:0]afifo[0-a]\;)
    fi

    ffmpeg_input_args+=(-i "$current_video_clip")

    if [[ -n "$CROSSFADE" ]] && [[ -n "${previous_video_clip}" ]]; then
      # If this is not the first clip in the sequence, generate an appropriate
      # video-crossfade filter.
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
    elif [[ -n "$CROSSFADE" ]]; then
      # If this is the first clip in the sequence, generate the initial
      # filter-concat string
      local curr_video_duration=$(ffprobe -v error -select_streams v:0 -show_entries stream=duration -of default=nw=1:nk=1 "${current_video_clip}")
      local curr_video_end=$(echo "$curr_video_duration - $fade_duration_secs" | bc)
      ffmpeg_filter_str+=([0:v:0] trim=start=0:end=${curr_video_end},setpts=PTS-STARTPTS[clip-0-clip-v]\;)
      ffmpeg_fade_suffix+=([clip-0-clip-v])
    else
      # Perform a basic video concatenation (without crossfading)
      ffmpeg_filter_str+=([${ARRAY_CTR}:v:0][${ARRAY_CTR}:a:0])
    fi

    ARRAY_CTR=$((ARRAY_CTR+1))
  done

  # Map the final audio stream to "outa"
  ffmpeg_acrossfade_suffix+=([${FFMPEG_IDX_CTR}-a]afifo[outa]\;)

  local filter_str="$(echo -e "${ffmpeg_filter_str[@]}" | tr -d '[:space:]')"
  local concat_ctr=$(echo "($FFMPEG_IDX_CTR * 2) + 1" | bc)
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
  $EXIFTOOL -overwrite_original -tagsfromfile "${temp_video_dir}/${unique_str}-metadata-info.mie" "${temp_video_dir}/joined-output.mp4"
  set +e
  $EXIFTOOL -overwrite_original '-datetimeoriginal<CreateDate' -if '(not $datetimeoriginal or ($datetimeoriginal eq "0000:00:00 00:00:00"))' "${temp_video_dir}/joined-output.mp4"
  set -e

  echo "- Cleaning up"
  mv "${temp_video_dir}/joined-output.mp4" .
  $EXIFTOOL  -overwrite_original '-FileName<DateTimeOriginal' -if '($datetimeoriginal)' -d "joined-output-%Y-%m-%d_%H.%M.%S%%-c.%%le" "./joined-output.mp4"
}

create_lead_video_clip() {
  local temp_video_dir=${myname}-temp-videos
  mkdir -p "$temp_video_dir"

  local bg_color="#A85546"
  local font_color="#DCDAB4"
  local font_subtext_size=50
  local font_title_size=80
  local clip_duration=${CLIP_DURATION:-4}

  local output_resolution=${OUTPUT_RESOLUTION:-1080p}
  local title_width=""
  local title_height=""
  if [[ "$output_resolution" == "1440p" ]]; then
    title_width="1920"
    title_height="1440"
  elif [[ "$output_resolution" == "1080p" ]]; then
    title_width="1920"
    title_height="1080"
  else
    title_width="1280"
    title_height="720"
  fi

  local line_one=${create_lead_video_clip_args[1]}
  local line_two=${create_lead_video_clip_args[2]}
  local line_three=${create_lead_video_clip_args[3]}

  [[ -n "$verbose" ]] && echo "Argument line one: ${line_one}"
  [[ -n "$verbose" ]] && echo "Argument line two: ${line_two}"
  [[ -n "$verbose" ]] && echo "Argument line three: ${line_three}"

  echo "- Generating image"
  local lead_image_args=()
  lead_image_args+=(-size ${title_width}x${title_height})
  lead_image_args+=(xc:"$bg_color")
  lead_image_args+=(-gravity North)
  lead_image_args+=(-font /usr/share/fonts/truetype/lato/Lato-Bold.ttf)
  local text_y_position=0

  if [[ -n "$line_one" ]]; then
    text_y_position=$(echo "$font_subtext_size * 1.8" | bc)
    lead_image_args+=(-pointsize $font_subtext_size -fill "$font_color" -draw "text 0,${text_y_position} '${line_one}'")
  fi

  if [[ -n "$line_two" ]]; then
    text_y_position=$(echo "$text_y_position * 2" | bc)
    lead_image_args+=(-pointsize $font_title_size -fill "$font_color" -draw "text 0,${text_y_position} '${line_two}'")
  fi

  if [[ -n "$line_three" ]]; then
    text_y_position=$(echo "$text_y_position * 2" | bc)
    lead_image_args+=(-pointsize $font_subtext_size -fill "$font_color" -draw "text 0,${text_y_position} '${line_three}'")
  fi

  lead_image_args+=("${temp_video_dir}/generated-lead-image.png")
  convert "${lead_image_args[@]}"

  echo "- Generating ${clip_duration} second video clip"
  local ffmpeg_clip_args=()
  [[ -z "$verbose" ]] && ffmpeg_clip_args+=(-loglevel fatal) || ffmpeg_clip_args+=(-
oglevel info)
  ffmpeg_clip_args+=(-y)
  ffmpeg_clip_args+=(-threads $(nproc --ignore=1))
  ffmpeg_clip_args+=(-loop 1)
  ffmpeg_clip_args+=(-i "${temp_video_dir}/generated-lead-image.png")

  ffmpeg_clip_args+=(-f lavfi)
  ffmpeg_clip_args+=(-i "anullsrc=r=32000:cl=mono")

  ffmpeg_clip_args+=(-t $clip_duration)
  ffmpeg_clip_args+=(-vf "scale=${title_width}:${title_height}")
  ffmpeg_clip_args+=(-vcodec libx264)
  ffmpeg_clip_args+=(-acodec aac)
  ffmpeg_clip_args+=(-preset slow)
  ffmpeg_clip_args+=(-crf ${CRF_FACTOR})
  ffmpeg_clip_args+=(-r 30)
  ffmpeg_clip_args+=("${temp_video_dir}/generated-lead-video.mp4")
  ffmpeg2 "${ffmpeg_clip_args[@]}"

  echo "- Cleaning up"
  mv "${temp_video_dir}/generated-lead-video.mp4" "./lead-clip.mp4"
}

change_video_speed() {
  local temp_video_dir=${myname}-temp-videos
  mkdir -p "$temp_video_dir"

  local video_file=${change_video_speed_args[0]}
  local speed_factor=${change_video_speed_args[1]}

  local original_filename=$(basename -- "$video_file")
  local renamed_file=${original_filename// /_}
  local filename=$(basename -- "$renamed_file")
  local extension="${filename##*.}"
  filename="${filename%.*}"

  local video_fps=$(echo "$(ffprobe -v error -select_streams v:0 -show_entries stream=avg_frame_rate -of default=nw=1:nk=1 ${video_file})" | bc)
  local pts_rate=$(echo "scale=2; 1 / $speed_factor" | bc -l)

  echo "- Re-encoding ${video_file} (${video_fps}fps) to speed factor ${speed_factor}"
  local ffmpeg_speed_args=()
  [[ -z "$verbose" ]] && ffmpeg_speed_args+=(-loglevel fatal) || ffmpeg_speed_args+=(-loglevel info)
  ffmpeg_speed_args+=(-y)
  ffmpeg_speed_args+=(-threads $(nproc --ignore=1))
  ffmpeg_speed_args+=(-i "${video_file}")
  ffmpeg_speed_args+=(-r "${video_fps}")
  ffmpeg_speed_args+=(-vf "setpts=${pts_rate}*PTS")
  ffmpeg_speed_args+=(-vcodec libx264)
  ffmpeg_speed_args+=(-an)
  ffmpeg_speed_args+=("${temp_video_dir}/${filename}-speed_${speed_factor}.mp4")
  ffmpeg2 "${ffmpeg_speed_args[@]}"

  echo "- Renaming & adding EXIF data"
  $EXIFTOOL -overwrite_original -tagsfromfile "${video_file}" "${temp_video_dir}/${filename}-metadata-info.mie"
  $EXIFTOOL -overwrite_original -tagsfromfile "${temp_video_dir}/${filename}-metadata-info.mie" "${temp_video_dir}/${filename}-speed_${speed_factor}.mp4"
  set +e
  $EXIFTOOL -overwrite_original '-datetimeoriginal<CreateDate' -if '(not $datetimeoriginal or ($datetimeoriginal eq "0000:00:00 00:00:00"))' "${temp_video_dir}/${filename}-speed_${speed_factor}.mp4"
  set -e
  $EXIFTOOL  -overwrite_original '-FileName<DateTimeOriginal' -if '($datetimeoriginal)' -d "./speed_${speed_factor}-${filename}-%Y-%m-%d_%H.%M.%S%%-c.%%le" "${temp_video_dir}/${filename}-speed_${speed_factor}.mp4"
}

add_audio_clip() {
  local temp_video_dir=${myname}-temp-videos
  mkdir -p "$temp_video_dir"

  local video_file=${add_audio_clip_args[0]}
  local audio_file=${add_audio_clip_args[1]}
  local audio_start_time=${add_audio_clip_args[2]:-"00:00:00"}

  local original_filename=$(basename -- "$video_file")
  local renamed_file=${original_filename// /_}
  local filename=$(basename -- "$renamed_file")
  local extension="${filename##*.}"
  filename="${filename%.*}"

  echo "- Truncating ${audio_file} up until ${audio_start_time}"
  local ffmpeg_audio_tr_args=()
  [[ -z "$verbose" ]] && ffmpeg_audio_tr_args+=(-loglevel fatal) || ffmpeg_audio_tr_args+=(-loglevel info)
  ffmpeg_audio_tr_args+=(-y)
  ffmpeg_audio_tr_args+=(-threads $(nproc --ignore=1))
  ffmpeg_audio_tr_args+=(-i "${audio_file}")
  ffmpeg_audio_tr_args+=(-ss "${audio_start_time}")
  ffmpeg_audio_tr_args+=("${temp_video_dir}/${filename}-truncated-audio.mp3")
  ffmpeg2 "${ffmpeg_audio_tr_args[@]}"

  echo "- Re-encoding ${video_file} with new audio stream"
  local ffmpeg_reencode_args=()
  [[ -z "$verbose" ]] && ffmpeg_reencode_args+=(-loglevel fatal) || ffmpeg_reencode_args+=(-loglevel info)
  ffmpeg_reencode_args+=(-y)
  ffmpeg_reencode_args+=(-threads $(nproc --ignore=1))
  ffmpeg_reencode_args+=(-i "$video_file")
  ffmpeg_reencode_args+=(-i "${temp_video_dir}/${filename}-truncated-audio.mp3")
  ffmpeg_reencode_args+=(-vcodec libx264)
  ffmpeg_reencode_args+=(-acodec aac)
  ffmpeg_reencode_args+=(-preset slow)
  ffmpeg_reencode_args+=(-crf ${CRF_FACTOR})
  ffmpeg_reencode_args+=(-shortest)
  ffmpeg_reencode_args+=("${temp_video_dir}/${filename}-audio-substituted.mp4")
  ffmpeg2 "${ffmpeg_reencode_args[@]}"

  echo "- Renaming & adding EXIF data"
  $EXIFTOOL -overwrite_original -tagsfromfile "${video_file}" "${temp_video_dir}/${filename}-metadata-info.mie"
  $EXIFTOOL -overwrite_original -tagsfromfile "${temp_video_dir}/${filename}-metadata-info.mie" "${temp_video_dir}/${filename}-audio-substituted.mp4"
  set +e
  $EXIFTOOL -overwrite_original '-datetimeoriginal<CreateDate' -if '(not $datetimeoriginal or ($datetimeoriginal eq "0000:00:00 00:00:00"))' "${temp_video_dir}/${filename}-audio-substituted.mp4"
  set -e
  $EXIFTOOL  -overwrite_original '-FileName<DateTimeOriginal' -if '($datetimeoriginal)' -d "./audio_substituted-${filename}-%Y-%m-%d_%H.%M.%S%%-c.%%le" "${temp_video_dir}/${filename}-audio-substituted.mp4"
}

finalize_video_file() {
  local temp_video_dir=${myname}-temp-videos
  mkdir -p "$temp_video_dir"

  local video_file=$finalize_video_file_arg
  local original_filename=$(basename -- "$video_file")
  local sample_time_seconds=${VIDEO_SAMPLE_TIME:-15}
  local output_resolution=${OUTPUT_RESOLUTION:-1080p}
  local video_stabilization_smoothing_factor=${VIDEO_STABILIZATION_SMOOTHING_FACTOR:-10}
  local video_stabilization_shakiness_factor=${VIDEO_STABILIZATION_SHAKINESS_FACTOR:-5}
  local fade_duration_secs=${FADE_DURATION:-2}
  local metadata_title=${METADATA_TITLE:-""}
  local metadata_artist=${METADATA_ARTIST:-"Marvin Pinto"}
  local metadata_desc=${METADATA_DESC:-""}

  echo "- Finalizing video file: ${video_file}"
  echo "- Creating working copy"
  local renamed_file=${original_filename// /_}
  cp "${video_file}" "${temp_video_dir}/${renamed_file}"

  local filename=$(basename -- "$renamed_file")
  local extension="${filename##*.}"
  filename="${filename%.*}"

  echo "- Retrieving video metadata"
  local video_width=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of default=nw=1:nk=1 ${video_file})
  local video_height=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of default=nw=1:nk=1 ${video_file})
  local avg_frame_rate=$(echo "$(ffprobe -v error -select_streams v:0 -show_entries stream=avg_frame_rate -of default=nw=1:nk=1 ${video_file})" | bc)
  local audio_sample_rate=$(ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate -of default=nw=1:nk=1 ${video_file})
  local audio_channel_layout=$(ffprobe -v error -select_streams a:0 -show_entries stream=channel_layout -of default=nw=1:nk=1 ${video_file})
  local video_duration=$(ffprobe -v error -select_streams v:0 -show_entries stream=duration -of default=nw=1:nk=1 "${video_file}")

  echo "- Generating dummy video clip (to lead-in/out of ${video_file})"
  local ffmpeg_dummy_lead_args=()
  [[ -z "$verbose" ]] && ffmpeg_dummy_lead_args+=(-loglevel fatal) || ffmpeg_dummy_lead_args+=(-loglevel info)
  ffmpeg_dummy_lead_args+=(-y)
  ffmpeg_dummy_lead_args+=(-threads $(nproc --ignore=1))
  ffmpeg_dummy_lead_args+=(-f lavfi)
  ffmpeg_dummy_lead_args+=(-i "color=black:s=${video_width}x${video_height}:r=${avg_frame_rate}")
  ffmpeg_dummy_lead_args+=(-f lavfi)
  ffmpeg_dummy_lead_args+=(-i "anullsrc=r=${audio_sample_rate}:cl=${audio_channel_layout}")
  ffmpeg_dummy_lead_args+=(-vcodec libx264)
  ffmpeg_dummy_lead_args+=(-acodec aac)
  ffmpeg_dummy_lead_args+=(-t ${fade_duration_secs})
  ffmpeg_dummy_lead_args+=("${temp_video_dir}/empty_${fade_duration_secs}.mp4")
  ffmpeg2 "${ffmpeg_dummy_lead_args[@]}"

  echo "- Joining input files"
  local fade_out_start=$(echo "$video_duration - $fade_duration_secs" | bc)
  local ffmpeg_join_args=()
  [[ -z "$verbose" ]] && ffmpeg_join_args+=(-loglevel fatal) || ffmpeg_join_args+=(-loglevel info)
  ffmpeg_join_args+=(-y)
  ffmpeg_join_args+=(-threads $(nproc --ignore=1))
  ffmpeg_join_args+=(-i "${temp_video_dir}/empty_${fade_duration_secs}.mp4")
  ffmpeg_join_args+=(-i "${video_file}")
  ffmpeg_join_args+=(-i "${temp_video_dir}/empty_${fade_duration_secs}.mp4")

  local ffmpeg_filter_str=()
  ffmpeg_filter_str+=([1:v:0] fade=t=in:st=0:d=${fade_duration_secs}, fade=t=out:st=${fade_out_start}:d=${fade_duration_secs} [1v]\;)
  ffmpeg_filter_str+=([1:a:0] afade=t=in:st=0:d=${fade_duration_secs}, afade=t=out:st=${fade_out_start}:d=${fade_duration_secs} [1a]\;)
  ffmpeg_filter_str+=([0:v:0][0:a:0][1v][1a][2:v:0][2:a:0])
  ffmpeg_filter_str+=(concat=n=3:v=1:a=1[outv][outa])
  local filter_str="$(echo -e "${ffmpeg_filter_str[@]}" | tr -d '[:space:]')"

  ffmpeg_join_args+=(-filter_complex "${filter_str}")
  ffmpeg_join_args+=(-map "[outv]")
  ffmpeg_join_args+=(-map "[outa]")
  ffmpeg_join_args+=(-vcodec libx264)
  ffmpeg_join_args+=(-acodec aac)
  ffmpeg_join_args+=(-preset slow)
  ffmpeg_join_args+=(-crf ${CRF_FACTOR})
  ffmpeg_join_args+=("${temp_video_dir}/${filename}-finalized.mp4")
  ffmpeg2 "${ffmpeg_join_args[@]}"

  echo "- Saving a copy of ${video_file} mp4 container metadata"
  local ffmpeg_md_save_args=()
  [[ -z "$verbose" ]] && ffmpeg_md_save_args+=(-loglevel fatal) || ffmpeg_md_save_args+=(-loglevel info)
  ffmpeg_md_save_args+=(-y)
  ffmpeg_md_save_args+=(-threads $(nproc --ignore=1))
  ffmpeg_md_save_args+=(-i "${video_file}")
  ffmpeg_md_save_args+=(-c copy)
  ffmpeg_md_save_args+=(-map_metadata 0)
  ffmpeg_md_save_args+=(-map_metadata:s:v 0:s:v)
  ffmpeg_md_save_args+=(-map_metadata:s:a 0:s:a)
  ffmpeg_md_save_args+=(-f ffmetadata)
  ffmpeg_md_save_args+=("${temp_video_dir}/${filename}-mp4-container-metadata.txt")
  ffmpeg2 "${ffmpeg_md_save_args[@]}"

  echo "- Writing mp4 container metadata"
  local ffmpeg_md_write_args=()
  [[ -z "$verbose" ]] && ffmpeg_md_write_args+=(-loglevel fatal) || ffmpeg_md_write_args+=(-loglevel info)
  ffmpeg_md_write_args+=(-y)
  ffmpeg_md_write_args+=(-threads $(nproc --ignore=1))
  ffmpeg_md_write_args+=(-i "${temp_video_dir}/${filename}-finalized.mp4")
  ffmpeg_md_write_args+=(-f ffmetadata)
  ffmpeg_md_write_args+=(-i "${temp_video_dir}/${filename}-mp4-container-metadata.txt")
  ffmpeg_md_write_args+=(-c copy)
  ffmpeg_md_write_args+=(-map_metadata 1)
  ffmpeg_md_write_args+=("${temp_video_dir}/${filename}-finalized-with-metadata.mp4")
  ffmpeg2 "${ffmpeg_md_write_args[@]}"

  echo "- Writing custom mp4 metadata (title, artist, description)"
  local metadata_date=$(exiftool -createdate ${video_file} | awk '{print $4}' | sed -e 's/:/-/g')
  mv "${temp_video_dir}/${filename}-finalized-with-metadata.mp4" "${temp_video_dir}/${filename}-finalized.mp4"
  local ffmpeg_md_cust_args=()
  [[ -z "$verbose" ]] && ffmpeg_md_cust_args+=(-loglevel fatal) || ffmpeg_md_cust_args+=(-loglevel info)
  ffmpeg_md_cust_args+=(-y)
  ffmpeg_md_cust_args+=(-threads $(nproc --ignore=1))
  ffmpeg_md_cust_args+=(-i "${temp_video_dir}/${filename}-finalized.mp4")
  ffmpeg_md_cust_args+=(-metadata title="$metadata_title")
  ffmpeg_md_cust_args+=(-metadata artist="$metadata_artist")
  ffmpeg_md_cust_args+=(-metadata comment="$metadata_desc")
  ffmpeg_md_cust_args+=(-metadata description="$metadata_desc")
  ffmpeg_md_cust_args+=(-metadata date="$metadata_date")
  ffmpeg_md_cust_args+=("${temp_video_dir}/${filename}-finalized-with-metadata.mp4")
  ffmpeg2 "${ffmpeg_md_cust_args[@]}"

  echo "- Renaming & adding EXIF data"
  mv "${temp_video_dir}/${filename}-finalized-with-metadata.mp4" "${temp_video_dir}/${filename}-finalized.mp4"
  local filename_title=$(echo "$metadata_title" | tr '[:upper:]' '[:lower:]' | sed -e 's/[^a-z._-]/_/g')
  $EXIFTOOL -overwrite_original -tagsfromfile "${video_file}" "${temp_video_dir}/${filename}-metadata-info.mie"
  $EXIFTOOL -overwrite_original -tagsfromfile "${temp_video_dir}/${filename}-metadata-info.mie" "${temp_video_dir}/${filename}-finalized.mp4"
  set +e
  $EXIFTOOL -overwrite_original '-datetimeoriginal<CreateDate' -if '(not $datetimeoriginal or ($datetimeoriginal eq "0000:00:00 00:00:00"))' "${temp_video_dir}/${filename}-finalized.mp4"
  set -e
  $EXIFTOOL  -overwrite_original '-FileName<DateTimeOriginal' -if '($datetimeoriginal)' -d "./%Y-%m-%d_%H.%M.%S%%-c-${filename_title}.%%le" "${temp_video_dir}/${filename}-finalized.mp4"
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
elif [[ -n "${create_lead_video_clip_args[@]}" ]]; then
  create_lead_video_clip
elif [[ -n "$change_video_speed_args" ]]; then
  change_video_speed
elif [[ -n "$add_audio_clip_args" ]]; then
  add_audio_clip
elif [[ -n "$finalize_video_file_arg" ]]; then
  finalize_video_file
else
  show_help
  exit 1
fi
