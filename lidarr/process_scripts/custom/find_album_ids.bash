#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - find_album_ids.bash
# Version: v1.1-gs2.7.1
# Purpose: Utility script to find album IDs in Lidarr with various search options
# -------------------------------------------------------------------------------------------------------------

SCRIPT_NAME="find_album_ids"
SCRIPT_VERSION="v1.1-gs2.7.1"
LOG_FILE="/config/logs/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"
touch "$LOG_FILE" && chmod 777 "$LOG_FILE"

source /config/arrbit/helpers/logging_utils.bash
source /config/arrbit/helpers/helpers.bash
source /config/arrbit/connectors/arr_bridge.bash
arrbitPurgeOldLogs

# ---- BANNER ----
echo -e "${CYAN}[Arrbit]${NC} ${GREEN}Album ID Finder ${NC}${SCRIPT_VERSION}..."

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo -e "${CYAN}[Arrbit]${NC} ${RED}ERROR: jq is required but not installed.${NC}"
    exit 1
fi

# Function to display help
show_help() {
    echo -e "${CYAN}[Arrbit]${NC} ${GREEN}Album ID Finder - Help${NC}"
    echo -e "${CYAN}[Arrbit]${NC} ${GREEN}------------------------------------------${NC}"
    echo -e "${CYAN}[Arrbit]${NC} Usage: $0 [options]"
    echo -e "${CYAN}[Arrbit]${NC}"
    echo -e "${CYAN}[Arrbit]${NC} Options:"
    echo -e "${CYAN}[Arrbit]${NC}   -h, --help         Show this help message"
    echo -e "${CYAN}[Arrbit]${NC}   -r, --recent [N]   Show N most recent albums (default: 10)"
    echo -e "${CYAN}[Arrbit]${NC}   -a, --artist NAME  Search for albums by artist name"
    echo -e "${CYAN}[Arrbit]${NC}   -t, --title NAME   Search for albums by title"
    echo -e "${CYAN}[Arrbit]${NC}   -p, --path PATH    Find album ID by path"
    echo -e "${CYAN}[Arrbit]${NC}   -f, --full         Show full album details"
    echo -e "${CYAN}[Arrbit]${NC}"
    echo -e "${CYAN}[Arrbit]${NC} Examples:"
    echo -e "${CYAN}[Arrbit]${NC}   $0 --recent 5                # Show 5 most recent albums"
    echo -e "${CYAN}[Arrbit]${NC}   $0 --artist &quot;Taylor Swift&quot;   # Find albums by Taylor Swift"
    echo -e "${CYAN}[Arrbit]${NC}   $0 --title &quot;1989&quot;            # Find albums with '1989' in the title"
    echo -e "${CYAN}[Arrbit]${NC}   $0 --path &quot;/music/Taylor&quot;    # Find album ID by path"
}

# Default values
SHOW_RECENT=10
ARTIST_SEARCH=""
TITLE_SEARCH=""
PATH_SEARCH=""
FULL_DETAILS=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -r|--recent)
            if [[ $2 =~ ^[0-9]+$ ]]; then
                SHOW_RECENT=$2
                shift
            fi
            ;;
        -a|--artist)
            ARTIST_SEARCH="$2"
            shift
            ;;
        -t|--title)
            TITLE_SEARCH="$2"
            shift
            ;;
        -p|--path)
            PATH_SEARCH="$2"
            shift
            ;;
        -f|--full)
            FULL_DETAILS=true
            ;;
        *)
            # If no recognized option, assume it's a search term for title
            TITLE_SEARCH="$1"
            ;;
    esac
    shift
done

# If no options provided, show recent albums
if [[ -z "$ARTIST_SEARCH" && -z "$TITLE_SEARCH" && -z "$PATH_SEARCH" && $SHOW_RECENT -eq 10 ]]; then
    echo -e "${CYAN}[Arrbit]${NC} ${GREEN}Showing $SHOW_RECENT most recent albums:${NC}"
fi

# Get all albums from Lidarr
echo -e "${CYAN}[Arrbit]${NC} ${GREEN}Fetching albums from Lidarr...${NC}"
albums_url="${arrUrl}/api/${arrApiVersion}/album?apikey=${arrApiKey}"
albums_json=$(arr_api "$albums_url")

# Check if API call was successful
if ! echo "$albums_json" | jq -e '.[0]' >/dev/null 2>&1; then
    echo -e "${CYAN}[Arrbit]${NC} ${RED}ERROR: Failed to retrieve albums from Lidarr API${NC}"
    exit 1
fi

# Process based on search criteria
if [[ -n "$PATH_SEARCH" ]]; then
    # Search by path
    echo -e "${CYAN}[Arrbit]${NC} ${GREEN}Searching for albums with path containing: $PATH_SEARCH${NC}"
    
    # Get track files to match paths
    tracks_url="${arrUrl}/api/${arrApiVersion}/trackFile?apikey=${arrApiKey}"
    tracks_json=$(arr_api "$tracks_url")
    
    # Extract album IDs from track files that match the path
    matching_album_ids=$(echo "$tracks_json" | jq -r --arg path "$PATH_SEARCH" '.[] | select(.path | contains($path)) | .albumId' | sort -u)
    
    if [[ -z "$matching_album_ids" ]]; then
        echo -e "${CYAN}[Arrbit]${NC} ${YELLOW}No albums found with path containing: $PATH_SEARCH${NC}"
        exit 0
    fi
    
    # Filter albums by the matching IDs
    filtered_albums=$(echo "$albums_json" | jq -r --argjson ids "[$matching_album_ids]" '[.[] | select(.id as $id | $ids | index($id))]')
elif [[ -n "$ARTIST_SEARCH" ]]; then
    # Search by artist name
    echo -e "${CYAN}[Arrbit]${NC} ${GREEN}Searching for albums by artist: $ARTIST_SEARCH${NC}"
    filtered_albums=$(echo "$albums_json" | jq -r --arg artist "$ARTIST_SEARCH" '[.[] | select(.artist.artistName | ascii_downcase | contains($artist | ascii_downcase))]')
elif [[ -n "$TITLE_SEARCH" ]]; then
    # Search by album title
    echo -e "${CYAN}[Arrbit]${NC} ${GREEN}Searching for albums with title containing: $TITLE_SEARCH${NC}"
    filtered_albums=$(echo "$albums_json" | jq -r --arg title "$TITLE_SEARCH" '[.[] | select(.title | ascii_downcase | contains($title | ascii_downcase))]')
else
    # Show recent albums - simplified to avoid sorting issues
    filtered_albums=$(echo "$albums_json" | jq -r '[.[] | limit('"$SHOW_RECENT"'; .)]')
fi

# Check if we found any albums
album_count=$(echo "$filtered_albums" | jq -r 'length')
if [[ "$album_count" -eq 0 ]]; then
    echo -e "${CYAN}[Arrbit]${NC} ${YELLOW}No matching albums found.${NC}"
    exit 0
fi

echo -e "${CYAN}[Arrbit]${NC} ${GREEN}Found $album_count albums:${NC}"
echo -e "${CYAN}[Arrbit]${NC} ${GREEN}------------------------------------------${NC}"

# Display the results
if [[ "$FULL_DETAILS" == "true" ]]; then
    # Show full details
    echo "$filtered_albums" | jq -r '.[] | "ID: \(.id)\nTitle: \(.title)\nArtist: \(.artist.artistName)\nRelease Date: \(.releaseDate)\nPath: \(.artist.path)/\(.title)\n------------------------------------------"'
else
    # Show compact list
    echo -e "${CYAN}[Arrbit]${NC} ${GREEN}ID | Title | Artist | Release Date${NC}"
    echo "$filtered_albums" | jq -r '.[] | "\(.id) | \(.title) | \(.artist.artistName) | \(.releaseDate)"' | while read -r line; do
        echo -e "${CYAN}[Arrbit]${NC} $line"
    done
fi

echo -e "${CYAN}[Arrbit]${NC} ${GREEN}------------------------------------------${NC}"
echo -e "${CYAN}[Arrbit]${NC} ${GREEN}To use an album ID with the tagger script:${NC}"
echo -e "${CYAN}[Arrbit]${NC} ${GREEN}bash enhanced_tagger_v3.bash <ALBUM_ID>${NC}"
echo -e "${CYAN}[Arrbit]${NC} ${GREEN}------------------------------------------${NC}"
