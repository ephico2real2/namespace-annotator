#!/bin/bash

# Function to display usage
usage() {
  echo "Usage: $0 -f <config_file> | -n <namespace> -a <annotation_key=value> [--dry-run] [--verbose]"
  echo "  -f <config_file>       Path to the YAML configuration file"
  echo "  -n <namespace>         Namespace(s) to annotate (can be specified multiple times)"
  echo "  -a <annotation>        Annotation key-value pair (can be specified multiple times)"
  echo "  --dry-run              Simulate the changes without applying them"
  echo "  --verbose              Enable verbose output"
  exit 1
}

# Function to log messages
log() {
  if [ "$VERBOSE" = true ]; then
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $1"
  fi
}

# Function to validate CLI tools are installed
validate_tools() {
  if ! command -v kubectl &> /dev/null; then
    log "kubectl CLI is not installed. Please install it and try again."
    exit 1
  fi
  if ! command -v yq &> /dev/null; then
    log "yq is not installed. Please install it and try again."
    exit 1
  fi
  if ! command -v jq &> /dev/null; then
    log "jq is not installed. Please install it and try again."
    exit 1
  fi
}

# Function to read current annotations of a namespace
read_current_annotations() {
  local namespace=$1
  kubectl get namespace "$namespace" -o jsonpath="{.metadata.annotations}" 2>/dev/null
}

# Function to validate annotation values
validate_annotation_value() {
  local key=$1
  local value=$2

  case $key in
    "linkerd.io/inject")
      if [[ "$value" != "enabled" && "$value" != "disabled" ]]; then
        log "Invalid value '$value' for annotation key '$key'. Expected values are: enabled, disabled"
        return 1
      fi
      ;;
  esac
  return 0
}

# Function to annotate a namespace
annotate_namespace() {
  local namespace=$1
  shift
  local annotations=("$@")

  # Read current annotations of the namespace
  current_annotations=$(read_current_annotations "$namespace")
  log "Current annotations for $namespace: $current_annotations"

  for annotation in "${annotations[@]}"; do
    key=$(echo "$annotation" | cut -d'=' -f1)
    value=$(echo "$annotation" | cut -d'=' -f2)

    # Validate the annotation value if needed
    if ! validate_annotation_value "$key" "$value"; then
      log "Skipping invalid annotation $key=$value for namespace $namespace."
      continue
    fi

    # Check if the current annotation matches the desired value
    current_value=$(echo "$current_annotations" | jq -r ".\"$key\"")
    log "For key $key, current value: $current_value, desired value: $value"
    if [ "$current_value" == "$value" ]; then
      log "Namespace $namespace already annotated with $key=$value. Skipping."
      continue
    fi

    log "Annotating namespace: $namespace with $key=$value"
    if [ "$DRY_RUN" = true ]; then
      log "Dry run: Would annotate namespace $namespace with $key=$value"
      kubectl annotate namespace "$namespace" "$key=$value" --overwrite --dry-run=client
    else
      kubectl annotate namespace "$namespace" "$key=$value" --overwrite
      if [ $? -eq 0 ]; then
        log "Successfully annotated namespace $namespace with $key=$value."
      else
        log "Failed to annotate namespace $namespace with $key=$value."
      fi
    fi
  done
}

# Function to process a YAML configuration file
process_config_file() {
  local config_file=$1

  # Read verbose and dryRun settings from YAML if not overridden by CLI
  if [ -z "$VERBOSE_CLI" ]; then
    VERBOSE=$(yq eval '.verbose' "$config_file")
  fi
  if [ -z "$DRY_RUN_CLI" ]; then
    DRY_RUN=$(yq eval '.dryRun' "$config_file")
  fi

  namespace_count=$(yq eval '.namespaces | length' "$config_file")
  log "Processing $namespace_count namespaces from config file"
  for (( i=0; i<namespace_count; i++ )); do
    name=$(yq eval ".namespaces[$i].name" "$config_file")
    annotations=$(yq eval ".namespaces[$i].annotations" "$config_file" -o=json)
    log "Processing namespace $name with annotations $annotations"

    annotation_list=()
    for key in $(echo "$annotations" | jq -r 'keys[]'); do
      value=$(echo "$annotations" | jq -r ".\"$key\"")
      annotation_list+=("$key=$value")
      log "Adding annotation $key=$value for namespace $name"
    done

    annotate_namespace "$name" "${annotation_list[@]}"
  done
}

# Parse command-line arguments
NAMESPACES=()
ANNOTATIONS=()
CONFIG_FILE=""
DRY_RUN_CLI=""
VERBOSE_CLI=""

while [[ "$#" -gt 0 ]]; do
  case $1 in
    -f) CONFIG_FILE="$2"; shift ;;
    -n) NAMESPACES+=("$2"); shift ;;
    -a) ANNOTATIONS+=("$2"); shift ;;
    --dry-run) DRY_RUN_CLI=true ;;
    --verbose) VERBOSE_CLI=true ;;
    *) echo "Unknown parameter passed: $1"; usage ;;
  esac
  shift
done

# Override YAML settings with CLI flags if provided
[ -n "$VERBOSE_CLI" ] && VERBOSE=true
[ -n "$DRY_RUN_CLI" ] && DRY_RUN=true

# Validate required tools are installed
validate_tools

# Validate and process input
if [ "${#NAMESPACES[@]}" -gt 0 ] && [ "${#ANNOTATIONS[@]}" -gt 0 ]; then
  for namespace in "${NAMESPACES[@]}"; do
    annotate_namespace "$namespace" "${ANNOTATIONS[@]}"
  done
elif [ -n "$CONFIG_FILE" ]; then
  process_config_file "$CONFIG_FILE"
else
  usage
fi
