#!/usr/bin/env bash

set -e

# # Verbose mode
# set -x

MYNAME=`basename "$0"`
log="logger -t ${MYNAME} "
AUDIO_LATENCY_MS=200

bt_device_names=()
bt_device_macs=()

populate_bluetooth_device_list() {
  while IFS= read -r line; do
    bt_device_names+=( "$(echo "$line" | awk '{ $NF=""; print $0 }')" )
    bt_device_macs+=( "$(echo "$line" | awk '{ print $NF }' | tr -d \(\))" )
  done < <( bt-device --list | awk 'NR>1 { print $0 }' )
}

$log "Populating device list with paired bluetooth devices"
populate_bluetooth_device_list

bt_device_index=$( printf "%s\n" "${bt_device_names[@]}" | rofi -format i -dmenu -i -p "Bluetooth output device" -no-custom)

$log "Setting the active profile to: off"
CARD_ID=$(pactl list cards short | awk '$2 ~ /^bluez_/ { print $2 }')
if [[ -n "$CARD_ID" ]]; then
  pactl set-card-profile $CARD_ID a2dp_sink
  pactl set-card-profile $CARD_ID off
fi

for i in "${bt_device_macs[@]}"; do
  $log "Disconnecting from bluetooth device $i (if connected)"
  bt-device --disconnect "$i" > /dev/null 2>&1
done

$log "Connecting to bluetooth device ${bt_device_names[$bt_device_index]} (${bt_device_macs[$bt_device_index]})"
coproc bluetoothctl
echo -e "connect ${bt_device_macs[$bt_device_index]}\nquit" >&${COPROC[1]}
output=$(cat <&${COPROC[0]})

sleep 5

$log "Setting the active profile to: a2dp_sink"
CARD_ID=$(pactl list cards short | awk '$2 ~ /^bluez_/ { print $2 }')
pactl set-card-profile $CARD_ID a2dp_sink

# Get the sink ID of the currently connected bluetooth speaker
SINK_ID=$(pactl list sinks short | awk '$2 ~ /^bluez_/ { print $1 }')
if [[ -z "$SINK_ID" ]]; then
  $log "Warning: Could not find any connected Bluetooth speakers"
  exit 0
fi
$log "Found bluetooth device with sink ID ${SINK_ID}"

pacmd set-default-sink $SINK_ID

# Switch all currently playing audio streams over to the connected bluetooth speaker
pactl list sink-inputs short | while read line
do
  sink_input=$(echo "$line" | awk '{ print $1 }')
  $log "Moving input $sink_input to $SINK_ID"
  pactl move-sink-input $sink_input $SINK_ID

  $log "Re-setting volume to 100% for input $sink_input"
  pactl set-sink-input-volume $sink_input 100%
done

# Set the audio latency
CARD_ID=$(pactl list cards short | awk '$2 ~ /^bluez_/ { print $2 }')
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
