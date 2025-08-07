#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - jq_helper.bash
# Version: v1.0-gs2.7.1
# Purpose: Helper functions for safe JQ operations
# -------------------------------------------------------------------------------------------------------------

# Source guard to prevent multiple inclusion
if [[ -z "${ARRBIT_JQ_HELPER_INCLUDED:-}" ]]; then
  ARRBIT_JQ_HELPER_INCLUDED=1

  # -------------------------------------------------------------------------------------------------------------
  # jq_select_by_name: Safely select an object from a JSON array by name
  # Usage: jq_select_by_name "$json_array" "$name_value"
  # Returns: The matching object, or empty string if not found
  # -------------------------------------------------------------------------------------------------------------
  jq_select_by_name() {
    local json_array="$1"
    local name_value="$2"
    
    # Use proper escaping for JQ
    echo "$json_array" | jq -r ".[] | select(.name == &quot;$name_value&quot;)"
  }

  # -------------------------------------------------------------------------------------------------------------
  # jq_select_by_name_get_id: Safely select an object from a JSON array by name and return its ID
  # Usage: jq_select_by_name_get_id "$json_array" "$name_value"
  # Returns: The ID of the matching object, or empty string if not found
  # -------------------------------------------------------------------------------------------------------------
  jq_select_by_name_get_id() {
    local json_array="$1"
    local name_value="$2"
    
    # Use proper escaping for JQ
    echo "$json_array" | jq -r ".[] | select(.name == &quot;$name_value&quot;) | .id"
  }

  # -------------------------------------------------------------------------------------------------------------
  # jq_check_name_exists: Check if a name exists in a JSON array
  # Usage: jq_check_name_exists "$json_array" "$name_value"
  # Returns: "true" if exists, "false" if not
  # -------------------------------------------------------------------------------------------------------------
  jq_check_name_exists() {
    local json_array="$1"
    local name_value="$2"
    
    # Use proper escaping for JQ
    if [[ -n $(echo "$json_array" | jq -r ".[] | select(.name == &quot;$name_value&quot;) | .name") ]]; then
      echo "true"
    else
      echo "false"
    fi
  }

  # -------------------------------------------------------------------------------------------------------------
  # jq_get_names: Extract all names from a JSON array
  # Usage: jq_get_names "$json_array"
  # Returns: Newline-separated list of names
  # -------------------------------------------------------------------------------------------------------------
  jq_get_names() {
    local json_array="$1"
    
    # Extract all names
    echo "$json_array" | jq -r '.[].name'
  }

fi # End of source guard