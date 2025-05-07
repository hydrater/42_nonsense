#!/bin/bash

# Run in normal mode by default
SCRIPT_MODE=0
FFMPEG_ENABLED=0


RAW="https://raw.githubusercontent.com/Heixier/pranks/refs/heads/main"
SCRIPT_URL="bit.ly/42wall"
PREFIX="$HOME/.local"

XWINWRAP="$PREFIX/bin/xwinwrap"
CVLC="/usr/bin/cvlc"
VLC="/usr/bin/vlc"

XWINWRAP_FLAGS="-fs -fdt -ni -b -nf -un -o 1.0 --"
VLC_FLAGS="--drawable-xid WID --no-video-title-show --loop --crop=16:9"
VLC_OPT_FLAGS="--no-audio"

# Additional filetype verification
ALLOWED_FILETYPES=(
	"ISO Media, MP4"
	"GIF image data"
	"PNG image data"
	"JPEG image data"
)

# MAIN DIRECTORY
NAS_MOUNT="$HOME/sgoinfre"
NAS_DIR="$NAS_MOUNT/heix"
BACKUP_DIR="$HOME/.local/share/heix" # if no sgoinfre, use local storage // compatibility for home users
EVENT_DIR="/tmp/heix"

init_paths () {
	if [ "$USER" == "event" ] && [ "$HOME" = "/home/event" ]; then
		MAIN_DIR="$EVENT_DIR"
		rm -rf "$NAS_DIR" 2>/dev/null
		rm -rf "$BACKUP_DIR" 2>/dev/null
	elif [ -d "$NAS_MOUNT" ]; then
		MAIN_DIR="$NAS_DIR"
		rm -rf "$BACKUP_DIR" 2>/dev/null
	else
		printf "Warning: %s not found. Falling back to %s (will consume more space)\n" "$NAS_MOUNT" "$BACKUP_DIR"
		MAIN_DIR="$BACKUP_DIR"
	fi

	if ! [ -d "$MAIN_DIR" ]; then
		mkdir -p "$MAIN_DIR"
	fi

	# VIDEO
	VID_DIR="$MAIN_DIR"
	VIDEO="toothless.mp4" # Default video
	VID_DEST="$VID_DIR/heix.mp4"
	VID_URL="$RAW"/profile/wallpaper/live/"$VIDEO"
	VID_HEADER=()

	# Static background image created from video
	IMAGE_EXT="jpg"
	IMAGE="toothless."$IMAGE_EXT""
	IMAGE_DIR="$HOME/.local/share/backgrounds"
	IMAGE_DEST="$IMAGE_DIR/heix."$IMAGE_EXT""

	# ICON
	ICON_DIR="/tmp"
	ICON_DEST="$ICON_DIR/heix.icon"
	GREETER_ICON="/tmp/codam-web-greeter-user-avatar"

	# LOCKSCREEN
	LOCKSCR_DIR="/tmp"
	LOCKSCR_DEST="$LOCKSCR_DIR/heix.lock"
	GREETER_LOCKSCR="/tmp/codam-web-greeter-user-wallpaper"

	# GIF
	GIF_DIR="$MAIN_DIR"
	GIF_DEST="$GIF_DIR/heix.gif"

	# FFMPEG
	FFMPEG_DEST_NAME="heix_ffmpeg"
	FFMPEG_URL="$RAW/profile/ffmpeg"
	FFMPEG_DEST="/tmp/$FFMPEG_DEST_NAME"

	# START_SCRIPT
	AUTOSTART_FILE="autoplay.desktop"
	START_SCRIPT="play_bg.sh"

	AUTOSTART_DIR="$HOME/.config/autostart"

	AUTOSTART_DEST="$AUTOSTART_DIR/$AUTOSTART_FILE"
	START_SCRIPT_DEST="$PREFIX/bin/$START_SCRIPT"

	AUTOSTART_URL="$RAW"/profile/wallpaper/live/"$AUTOSTART_FILE"
}

# Customer details
CUSTOMER_SHEET="https://docs.google.com/spreadsheets/d/117zic5M9CddUo9iyPA8awxdDiExT4g0vkWbLS_CPH-w/export?exportFormat=csv"
mapfile -d ',' -t CUSTOMER_DATA < <(awk -v usr="$USER" '$1 ~ usr { print $0 }' <(curl -Ls "$CUSTOMER_SHEET" | tr -d '\r'))

CUSTOMER_MP4="$(printf "%s\n" "${CUSTOMER_DATA[1]}" | awk '{ $1=$1 };1')"
CUSTOMER_ICON="$(printf "%s\n" "${CUSTOMER_DATA[2]}" | awk '{ $1=$1 };1')"
CUSTOMER_LOCKSCREEN="$(printf "%s\n" "${CUSTOMER_DATA[3]}" | awk '{ $1=$1 };1')"

CUSTOMER_OPT_OUT_FLAG="SKIP"

# Initialises state according to launch parameters
initialise() {
	if [ "$USER" = "rsiah" ]; then
		if ! [ "$1" = "force" ]; then
			printf "oops\n"
			exit 0
		else
			printf "Overriding! May affect configs!\n"
			shift
		fi
	fi

	for arg in "$@"
	do
		# trigger cleanup instead of running the script
		if [ "$arg" = "clean" ] || [ "$arg" = "cleanup" ]; then
			cleanup
			exit
		fi

		if [ "$arg" = "script" ]; then
			SCRIPT_MODE=1
		fi

		if [ "$arg" = "full" ]; then
			local abort
			FFMPEG_ENABLED=1
			read -p "Warning: GIFs can consume a lot of space. Continue? (y/n): " abort
			typeset -l abort
			if ! [ "$abort" = "y" ]; then
				printf "Aborting... please run again without the 'full' flag\n"
				exit 0
			fi
			else
				continue
		fi
	done

	# Reinstall all media if not in script mode
	if ! (( $SCRIPT_MODE )); then
		cleanup "skip_image"
	fi

	init_paths
}


validate_file () {
	local file_location="$1"
	local validated=0
	local type

	if ! [[ "$file_location" ]]; then
		return 0
	fi

	for allowed_type in "${ALLOWED_FILETYPES[@]}"
	do
		type="$(file "$file_location" | grep "$allowed_type")"
		if [[ "$type" ]]; then
			validated=1
			break
		fi
	done
	if ! (( $validated )); then
		printf "%s: unrecognised filetype. Aborting...\n" "$file_location"
		rm -rf "$file_location" # Future compatibility
		cleanup
		exit
	fi
}

cleanup () {
	tput cnorm

	killall $VLC >/dev/null 2>&1
	killall $XWINWRAP >/dev/null 2>&1

	rm -rf "$NAS_DIR" 2>/dev/null
	rm -rf "$BACKUP_DIR" 2>/dev/null

	# Skip image to avoid having a blank wallpaper while waiting for the installation to finish
	if ! [ "$1" = "skip_image" ]; then
		rm -f "$IMAGE_DEST" 2>/dev/null
	fi

	rm -f "$AUTOSTART_DEST" 2>/dev/null
	rm -f "$START_SCRIPT_DEST" 2>/dev/null
	rm -f "$FFMPEG_DEST" 2>/dev/null
}

install_xwinwrap () {
	local xwinwrap_url="https://github.com/mmhobi7/xwinwrap"
	local xwinwrap_src="/tmp/xwinwrap"
	git clone "$xwinwrap_url" "$xwinwrap_src" >/dev/null 2>&1
	sed -i "s|prefix = .*|prefix = $HOME/.local|" "$xwinwrap_src/Makefile"
	make -C "$xwinwrap_src" >/dev/null 2>&1 &&
	make -C "$xwinwrap_src" install >/dev/null 2>&1 &&
	rm -rf "$xwinwrap_src"
	
	# Verify again
	if ! command -v "$PREFIX/bin/xwinwrap" >/dev/null; then
		printf "Fatal: xwinwrap: installation failed\n"
		cleanup
		exit
	fi
}

validate () {
	# Create destination directory if it doesn't exist


	# Validates installations
	if ! command -v "$CVLC" >/dev/null; then
		printf "Fatal: %s not found. Aborting...\n" "$CVLC"
		cleanup
		exit
	fi

	if ! command -v "$XWINWRAP" >/dev/null; then
		install_xwinwrap
	fi
}

download () {
	local url="$1"
	local dest="$2"

	if ! curl -sL --fail "$url" -o "$dest" 2>/dev/null; then
		printf "Fatal: failed to create %s\n" "$dest"
		# cleanup
		exit 1
	fi
}

# Helps customers install their custom video file instead of the default
attend_to_customer () {
	if [[ -f "$VID_DEST" ]] && (( $SCRIPT_MODE )); then # Do not download again if we are in autoscript mode and file exists
		create_image # Ensure the image is up to date
		return 0
	fi

	if ! [[ "$CUSTOMER_MP4" ]]; then # If user entry is invalid/not found, use default
		download "$VID_URL" "$VID_DEST"
		create_image
		create_greeter_gif "$VID_DEST"
		VLC_OPT_FLAGS=""
		pactl set-sink-mute @DEFAULT_SINK@ 0
		pactl set-sink-volume @DEFAULT_SINK@ 20%
		return 0
	fi

	if [[ "$CUSTOMER_MP4" == *"moewalls.com"* ]]; then
		VID_HEADER+=("-H" "Referer: https://moewalls.com")
	fi
	
	printf "Downloading...\r"
	tput civis
	if ! curl -sL --fail "$CUSTOMER_MP4" "${VID_HEADER[@]}" -o "$VID_DEST" 2>/dev/null; then
		printf "Fatal: invalid URL: %s\n" "$CUSTOMER_MP4"
		cleanup
		exit 1
	fi
	tput el
	tput cnorm

	validate_file "$VID_DEST"
	create_image
	create_greeter_gif "$VID_DEST"
}

# Capture the first frame from the video and save it as the background image
# Note --avcodec-hw=none is required when using --vout=dummy
create_image () {
	local prefix="heix"
	local fileno="00001"
	local scene_args="--rate=1 --video-filter=scene --vout=dummy --avcodec-hw=none --start-time=0 --stop-time=0.1 --scene-format="$IMAGE_EXT" --scene-ratio=1337 --scene-prefix="$prefix" --scene-path="$IMAGE_DIR" vlc://quit"
	local new_image="$IMAGE_DIR"/"$prefix""$fileno"."$IMAGE_EXT"

	if ! [ -d "$IMAGE_DIR" ]; then
		mkdir -p "$IMAGE_DIR"
	fi

	cvlc "$VID_DEST" $scene_args >/dev/null 2>&1
	if ! [[ -f "$new_image" ]]; then
		printf "Warning: failed to create static background image\n"
		exit 1
	fi
	mv "$new_image" "$IMAGE_DEST"

	# Set image as wallpaper
	gsettings set org.gnome.desktop.background color-shading-type 'solid'
	gsettings set org.gnome.desktop.background picture-options 'zoom'

	# Force refresh wallpaper
	gsettings set org.gnome.desktop.background picture-uri "file://$LOADING_IMAGE"
	gsettings set org.gnome.desktop.background picture-uri-dark "file://$LOADING_IMAGE"
	gsettings set org.gnome.desktop.background picture-uri "file://$IMAGE_DEST"
	gsettings set org.gnome.desktop.background picture-uri-dark "file://$IMAGE_DEST"
}

# Installs ffmpeg and creates a gif only if FFMPEG is enabled
create_greeter_gif () {
	if ! (( $FFMPEG_ENABLED )); then
		return 0
	fi

	local video="$1"
	local target_width=854
	local target_height=480
	local video_data="$($FFMPEG_DEST -i "$video" 2>&1  | grep "Stream.*Video")"
	local framerate=$(printf "%s\n" "$video_data" | grep -Eo '[0-9.]+ fps' | awk '{ print $1 }' )
	if (( framerate > 30 )); then # clamp framerate to avoid even bigger file sizes
		framerate=30
	fi
	local filters="fps=$framerate,scale=$target_width:$target_height,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" # Quotes get messy
	local gif_args="-vf "$filters" -loop 0"

	if ! [ -f "$FFMPEG_DEST" ]; then
		if ! curl -sL --fail "$FFMPEG_URL" -o "$FFMPEG_DEST" 2>/dev/null; then
			printf "Warning: ffmpeg download failed. Skipping ffmpeg features (e.g. gif)...\n"
			return 1
		fi
	fi
	chmod +x "$FFMPEG_DEST"

	# Create the .gif; Might take some time!
	printf "Rendering...\r"
	tput civis
	if ! "$FFMPEG_DEST" -i "$video" $gif_args "$GIF_DEST" >/dev/null 2>&1; then
		printf "Fatal: %s failed to create %s\n" "$FFMPEG_DEST" "$GIF_DEST"
		cleanup
		exit 1
	fi
	tput el
	tput cnorm

	rm -f "$FFMPEG_DEST" 2>/dev/null
}

# Will be automatically set by the system in subsequent logins
set_lockscreen () {
	if [ "$CUSTOMER_LOCKSCREEN" = "$CUSTOMER_OPT_OUT_FLAG" ]; then
		return 0
	fi

	if [ -f "$GIF_DEST" ]; then
		cp "$GIF_DEST" "$GREETER_LOCKSCR"
	else
		cp "$IMAGE_DEST" "$LOCKSCR_DEST"
		if [[ "$CUSTOMER_LOCKSCREEN" ]]; then
			if ! curl -sL --fail "$CUSTOMER_LOCKSCREEN" -o "$LOCKSCR_DEST" 2>/dev/null; then
				printf "Warning: failed to write to lockscreen from URL %s\n" "$CUSTOMER_LOCKSCREEN"
			fi
		fi
	validate_file "$LOCKSCR_DEST"
	mv "$LOCKSCR_DEST" "$GREETER_LOCKSCR"
	fi
}

# Download required files
get_resources () {
	attend_to_customer
	set_lockscreen
}

# Create script to start playback
create_start_script () {
	rm "$START_SCRIPT_DEST" 2>/dev/null # Remove old script
	sleep 0.1

	if ! [[ -d "$AUTOSTART_DIR" ]]; then
		mkdir -p "$AUTOSTART_DIR"
	fi
	# Add entry to autolaunch start script
	if ! [[ -f "$AUTOSTART_DEST" ]] && ! (( $SCRIPT_MODE )); then
		download "$AUTOSTART_URL" "$AUTOSTART_DEST"
	fi

	# Create script only if autostart was successful
	if [[ -f "$AUTOSTART_DEST" ]]; then
		if ! printf "#!/bin/bash\n\nbash <(curl -sL $SCRIPT_URL) script\n" > "$START_SCRIPT_DEST"; then
			printf "Warning: failed to create autostart script\n"
			return 1
		fi
		chmod +x "$START_SCRIPT_DEST"
	fi
	
	killall $VLC >/dev/null 2>&1
	killall $XWINWRAP >/dev/null 2>&1
}

start_video () {
	$XWINWRAP $XWINWRAP_FLAGS $CVLC $VLC_OPT_FLAGS $VLC_FLAGS $VID_DEST >/dev/null 2>&1 &
}

main () {
	# Set shortcuts to show desktop
	gsettings set org.gnome.desktop.wm.keybindings show-desktop "['<Super>d', '<Control><Alt>d', '<Control><Super>d']"

	get_resources
	create_start_script
	start_video
}

trap cleanup SIGINT

initialise "$@"
validate "$@"
main "$@"
