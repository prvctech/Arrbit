#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - metadata_profiles.bash
# Version: v2.2-gs2.7.1
# Purpose: Configure Lidarr Metadata Profiles via API (Golden Standard v2.7.1 compliant)
# -------------------------------------------------------------------------------------------------------------

SCRIPT_NAME="metadata_profiles"
SCRIPT_VERSION="v2.2-gs2.7.1"
LOG_FILE="/config/logs/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"

# Source required helpers
source /config/arrbit/helpers/logging_utils.bash
source /config/arrbit/helpers/helpers.bash
source /config/arrbit/helpers/config_utils.bash

arrbitPurgeOldLogs

# Banner (only one echo allowed)
echo -e "${CYAN}[Arrbit]${NC} ${GREEN}Starting ${SCRIPT_NAME} module${NC} ${SCRIPT_VERSION}..."

mkdir -p /config/logs && touch "$LOG_FILE" && chmod 777 "$LOG_FILE"

# --- 1. Source arr_bridge for API variables and arr_api wrapper ---
if ! source /config/arrbit/connectors/arr_bridge.bash; then
  log_error "Could not source arr_bridge.bash (Required for API access, check Arrbit setup) (see log at /config/logs)"
  cat <<EOF | arrbitLogClean >> "$LOG_FILE"
[Arrbit] ERROR Could not source arr_bridge.bash
[WHY]: arr_bridge.bash is missing or failed to source.
[FIX]: Verify /config/arrbit/connectors/arr_bridge.bash exists and is correct. See log for details.
EOF
  exit 1
fi

# --- 2. Get module-specific configuration ---
# Get payload path from YAML if available, otherwise use default
PAYLOAD_PATH=$(get_yaml_value "autoconfig.paths.metadata_profiles_payload")
if [[ -z "$PAYLOAD_PATH" || "$PAYLOAD_PATH" == "null" ]]; then
  PAYLOAD_PATH="/config/arrbit/modules/data/payload-metadata_profiles.json"
fi

# --- 3. Check if payload file exists ---
if [[ ! -f "$PAYLOAD_PATH" ]]; then
  log_error "Payload file not found: ${PAYLOAD_PATH} (see log at /config/logs)"
  cat <<EOF | arrbitLogClean >> "$LOG_FILE"
[Arrbit] ERROR Payload file not found: $PAYLOAD_PATH
[WHY]: The file does not exist at the specified path.
[FIX]: Place a valid payload-metadata_profiles.json in $(dirname "$PAYLOAD_PATH") or update the path in configuration:
      autoconfig:
        paths:
          metadata_profiles_payload: "/path/to/your/payload-metadata_profiles.json"
EOF
  exit 1
fi

# --- 4. Read payload from file ---
# Log to file only, not terminal
payload=$(cat "$PAYLOAD_PATH")
printf '[Arrbit] Metadata Profiles payload:\n%s\n' "$payload" | arrbitLogClean >> "$LOG_FILE"

# --- 5. Check if settings already match ---
# Log to file only, not terminal
printf '[Arrbit] Checking current metadata profiles\n' | arrbitLogClean >> "$LOG_FILE"
current_profiles=$(arr_api "${arrUrl}/api/${arrApiVersion}/metadataprofile")
printf '[Arrbit] Current profiles:\n%s\n' "$current_profiles" | arrbitLogClean >> "$LOG_FILE"

# Parse the payload to determine if it's a single object or an array
if [[ $(echo "$payload" | jq 'type') == '"array"' ]]; then
  # It's an array of metadata profiles
  profile_count=$(echo "$payload" | jq 'length')
  
  # Process each profile in the array
  success_count=0
  failure_count=0
  skipped_count=0
  
  for ((i=0; i<profile_count; i++)); do
    profile=$(echo "$payload" | jq ".[$i]")
    profile_name=$(echo "$profile" | jq -r '.name')
    
    # Skip reserved names
    if [[ "$profile_name" == "None" ]]; then
      log_warning "Skipping reserved profile name: None"
      ((skipped_count++))
      continue
    fi
    
    # Check if profile exists
    existing_profile=$(echo "$current_profiles" | jq ".[] | select(.name == &quot;$profile_name&quot;)")
    
    if [[ -n "$existing_profile" ]]; then
      existing_id=$(echo "$existing_profile" | jq -r '.id')
      
      # Compare settings (ignoring id)
      existing_without_id=$(echo "$existing_profile" | jq 'del(.id)')
      profile_without_id=$(echo "$profile" | jq 'del(.id)')
      
      if [[ "$(echo "$existing_without_id" | jq -S .)" == "$(echo "$profile_without_id" | jq -S .)" ]]; then
        # Log to file only, not terminal
        printf '[Arrbit] Profile already exists and matches: %s - skipping\n' "$profile_name" | arrbitLogClean >> "$LOG_FILE"
        ((skipped_count++))
        continue
      fi
      
      # Ensure required fields are present
      # Check for primary album types
      if [[ $(echo "$profile_without_id" | jq '.primaryAlbumTypes | length') -eq 0 ]]; then
        log_warning "Adding required primary album types to profile: ${profile_name}"
        profile_without_id=$(echo "$profile_without_id" | jq '.primaryAlbumTypes = [{"albumType": "Album", "allowed": true}]')
      fi
      
      # Check for secondary album types
      if [[ $(echo "$profile_without_id" | jq '.secondaryAlbumTypes | length') -eq 0 ]]; then
        log_warning "Adding required secondary album types to profile: ${profile_name}"
        profile_without_id=$(echo "$profile_without_id" | jq '.secondaryAlbumTypes = [{"albumType": "Studio", "allowed": true}]')
      fi
      
      # Check for release statuses
      if [[ $(echo "$profile_without_id" | jq '.releaseStatuses | length') -eq 0 ]]; then
        log_warning "Adding required release statuses to profile: ${profile_name}"
        profile_without_id=$(echo "$profile_without_id" | jq '.releaseStatuses = [{"releaseStatus": "Official", "allowed": true}]')
      fi
      
      # Update existing profile
      log_info "Updating metadata profile: ${profile_name}"
      response=$(arr_api -X PUT --data-raw "$profile_without_id" "${arrUrl}/api/${arrApiVersion}/metadataprofile/$existing_id")
      
      # Log response to file only, not terminal
      printf '[API Response for %s]\n%s\n[/API Response]\n' "$profile_name" "$response" | arrbitLogClean >> "$LOG_FILE"
      
      # Check if operation was successful
      if echo "$response" | jq -e '.id' >/dev/null 2>&1; then
        ((success_count++))
      else
        log_error "Failed to update metadata profile: ${profile_name} (see log at /config/logs)"
        cat <<EOF | arrbitLogClean >> "$LOG_FILE"
[Arrbit] ERROR Failed to update metadata profile: $profile_name
[WHY]: API response did not validate (expected fields missing or invalid)
[FIX]: Check payload JSON fields for correctness, or see [API Response] section below for more info.
[API Response]
$response
[/API Response]
EOF
        ((failure_count++))
      fi
    else
      # Create new profile
      log_info "Creating metadata profile: ${profile_name}"
      profile_without_id=$(echo "$profile" | jq 'del(.id)')
      
      # Ensure required fields are present
      # Check for primary album types
      if [[ $(echo "$profile_without_id" | jq '.primaryAlbumTypes | length') -eq 0 ]]; then
        log_warning "Adding required primary album types to profile: ${profile_name}"
        profile_without_id=$(echo "$profile_without_id" | jq '.primaryAlbumTypes = [{"albumType": "Album", "allowed": true}]')
      fi
      
      # Check for secondary album types
      if [[ $(echo "$profile_without_id" | jq '.secondaryAlbumTypes | length') -eq 0 ]]; then
        log_warning "Adding required secondary album types to profile: ${profile_name}"
        profile_without_id=$(echo "$profile_without_id" | jq '.secondaryAlbumTypes = [{"albumType": "Studio", "allowed": true}]')
      fi
      
      # Check for release statuses
      if [[ $(echo "$profile_without_id" | jq '.releaseStatuses | length') -eq 0 ]]; then
        log_warning "Adding required release statuses to profile: ${profile_name}"
        profile_without_id=$(echo "$profile_without_id" | jq '.releaseStatuses = [{"releaseStatus": "Official", "allowed": true}]')
      fi
      
      response=$(arr_api -X POST --data-raw "$profile_without_id" "${arrUrl}/api/${arrApiVersion}/metadataprofile")
      
      # Log response to file only, not terminal
      printf '[API Response for %s]\n%s\n[/API Response]\n' "$profile_name" "$response" | arrbitLogClean >> "$LOG_FILE"
      
      # Check if operation was successful
      if echo "$response" | jq -e '.id' >/dev/null 2>&1; then
        ((success_count++))
      else
        log_error "Failed to create metadata profile: ${profile_name} (see log at /config/logs)"
        cat <<EOF | arrbitLogClean >> "$LOG_FILE"
[Arrbit] ERROR Failed to create metadata profile: $profile_name
[WHY]: API response did not validate (expected fields missing or invalid)
[FIX]: Check payload JSON fields for correctness, or see [API Response] section below for more info.
[API Response]
$response
[/API Response]
EOF
        ((failure_count++))
      fi
    fi
  done
  
  # Log summary
  if [[ $success_count -gt 0 && $failure_count -eq 0 ]]; then
    log_info "The module was configured successfully."
    if [[ $skipped_count -gt 0 ]]; then
      log_info "Skipped $skipped_count profiles (already exist or reserved names)."
    fi
  elif [[ $success_count -gt 0 && $failure_count -gt 0 ]]; then
    log_warning "Partially successful: Added/updated $success_count profiles, failed to add/update $failure_count profiles"
  elif [[ $failure_count -gt 0 ]]; then
    log_warning "Failed to configure $failure_count metadata profile(s)"
  elif [[ $skipped_count -gt 0 && $success_count -eq 0 && $failure_count -eq 0 ]]; then
    log_info "Predefined settings already present. Skipping..."
  fi
else
  # It's a single metadata profile
  profile_name=$(echo "$payload" | jq -r '.name')
  
  # Skip reserved names
  if [[ "$profile_name" == "None" ]]; then
    log_warning "Skipping reserved profile name: None"
    log_info "Log saved to $LOG_FILE"
    log_info "Done."
    exit 0
  fi
  
  # Check if profile exists
  existing_profile=$(echo "$current_profiles" | jq ".[] | select(.name == &quot;$profile_name&quot;)")
  
  if [[ -n "$existing_profile" ]]; then
    existing_id=$(echo "$existing_profile" | jq -r '.id')
    
    # Compare settings (ignoring id)
    existing_without_id=$(echo "$existing_profile" | jq 'del(.id)')
    payload_without_id=$(echo "$payload" | jq 'del(.id)')
    
    if [[ "$(echo "$existing_without_id" | jq -S .)" == "$(echo "$payload_without_id" | jq -S .)" ]]; then
      log_info "Predefined settings already present. Skipping..."
      log_info "Log saved to $LOG_FILE"
      log_info "Done."
      exit 0
    fi
    
    # Ensure required fields are present
    # Check for primary album types
    if [[ $(echo "$payload_without_id" | jq '.primaryAlbumTypes | length') -eq 0 ]]; then
      log_warning "Adding required primary album types to profile: ${profile_name}"
      payload_without_id=$(echo "$payload_without_id" | jq '.primaryAlbumTypes = [{"albumType": "Album", "allowed": true}]')
    fi
    
    # Check for secondary album types
    if [[ $(echo "$payload_without_id" | jq '.secondaryAlbumTypes | length') -eq 0 ]]; then
      log_warning "Adding required secondary album types to profile: ${profile_name}"
      payload_without_id=$(echo "$payload_without_id" | jq '.secondaryAlbumTypes = [{"albumType": "Studio", "allowed": true}]')
    fi
    
    # Check for release statuses
    if [[ $(echo "$payload_without_id" | jq '.releaseStatuses | length') -eq 0 ]]; then
      log_warning "Adding required release statuses to profile: ${profile_name}"
      payload_without_id=$(echo "$payload_without_id" | jq '.releaseStatuses = [{"releaseStatus": "Official", "allowed": true}]')
    fi
    
    # Update existing profile
    log_info "Updating metadata profile: ${profile_name}"
    response=$(arr_api -X PUT --data-raw "$payload_without_id" "${arrUrl}/api/${arrApiVersion}/metadataprofile/$existing_id")
  else
    # Create new profile
    log_info "Creating metadata profile: ${profile_name}"
    payload_without_id=$(echo "$payload" | jq 'del(.id)')
    
    # Ensure required fields are present
    # Check for primary album types
    if [[ $(echo "$payload_without_id" | jq '.primaryAlbumTypes | length') -eq 0 ]]; then
      log_warning "Adding required primary album types to profile: ${profile_name}"
      payload_without_id=$(echo "$payload_without_id" | jq '.primaryAlbumTypes = [{"albumType": "Album", "allowed": true}]')
    fi
    
    # Check for secondary album types
    if [[ $(echo "$payload_without_id" | jq '.secondaryAlbumTypes | length') -eq 0 ]]; then
      log_warning "Adding required secondary album types to profile: ${profile_name}"
      payload_without_id=$(echo "$payload_without_id" | jq '.secondaryAlbumTypes = [{"albumType": "Studio", "allowed": true}]')
    fi
    
    # Check for release statuses
    if [[ $(echo "$payload_without_id" | jq '.releaseStatuses | length') -eq 0 ]]; then
      log_warning "Adding required release statuses to profile: ${profile_name}"
      payload_without_id=$(echo "$payload_without_id" | jq '.releaseStatuses = [{"releaseStatus": "Official", "allowed": true}]')
    fi
    
    response=$(arr_api -X POST --data-raw "$payload_without_id" "${arrUrl}/api/${arrApiVersion}/metadataprofile")
  fi
  
  # Log response to file only, not terminal
  printf '[API Response]\n%s\n[/API Response]\n' "$response" | arrbitLogClean >> "$LOG_FILE"
  
  # Check if operation was successful
  if echo "$response" | jq -e '.id' >/dev/null 2>&1; then
    log_info "The module was configured successfully."
  else
    log_error "Metadata Profiles API call failed (see log at /config/logs)"
    cat <<EOF | arrbitLogClean >> "$LOG_FILE"
[Arrbit] ERROR Metadata Profiles API call failed
[WHY]: API response did not validate (expected fields missing or invalid)
[FIX]: Check payload JSON fields for correctness, or see [API Response] section above for details.
[API Response]
$response
[/API Response]
EOF
    exit 1
  fi
fi

# --- 6. Log completion and exit ---
log_info "Log saved to $LOG_FILE"
log_info "Done."
exit 0
