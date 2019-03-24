#!/usr/bin/env bash

set -e

# # Verbose mode
# set -x

MYNAME=`basename "$0"`
log="logger -t ${MYNAME} "
AUDIO_LATENCY_MS=200

# Get the sink ID of the currently connected bluetooth speaker
SINK_ID=$(pactl list sinks short | awk '$2 ~ /^bluez_/ { print $1 }')

if [[ -z "$SINK_ID" ]]; then
  $log "Warning: Could not find any connected Bluetooth speakers"
  exit 0
fi
$log "Found bluetooth device with sink ID ${SINK_ID}"

# Switch all currently playing audio streams over to the connected bluetooth speaker
pactl list sink-inputs short | while read line
do
  sink_input=$(echo "$line" | awk '{ print $1 }')
  $log "Moving input $sink_input to $SINK_ID"
  pactl move-sink-input $sink_input $SINK_ID

  $log "Re-setting volume to 100% for input $sink_input"
  pactl set-sink-input-volume $sink_input 100%
done

# Switch the card profile
CARD_ID=$(pactl list cards short | awk '$2 ~ /^bluez_/ { print $2 }')
pactl set-card-profile $CARD_ID a2dp_sink
pactl set-card-profile $CARD_ID off
pactl set-card-profile $CARD_ID a2dp_sink
$log "Toggled card profile successfully for ${CARD_ID}"

# Set the audio latency
latency=$(echo "$AUDIO_LATENCY_MS * 1000" | bc)
latency_successfully_set=0
set +e
for output_type in 'speaker-output' 'unknown-output'; do
  pactl set-port-latency-offset $CARD_ID $output_type $latency > /dev/null 2>&1
  latency_successfully_set=$?
  if [[ $latency_successfully_set == 0 ]]; then
    break
  fi
done;
set -e
if [[ $latency_successfully_set != 0 ]]; then
  $log "Could not set audio latency to ${AUDIO_LATENCY_MS}ms for ${CARD_ID}"
  exit 1
fi
$log "Successfully set audio latency to ${AUDIO_LATENCY_MS}ms for ${CARD_ID}"
