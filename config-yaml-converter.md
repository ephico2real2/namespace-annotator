### Script to Convert YAML Format

Here is the `convert_yaml.sh` script to convert the existing YAML format to the new format:

```bash
#!/bin/bash

# Function to display usage
usage() {
  echo "Usage: $0 <input_config_file> <output_config_file>"
  echo "  <input_config_file>  Path to the existing YAML configuration file"
  echo "  <output_config_file> Path to the new YAML configuration file"
  exit 1
}

# Validate input arguments
if [ "$#" -ne 2 ]; then
  usage
fi

INPUT_FILE=$1
OUTPUT_FILE=$2

# Check if yq is installed
if ! command -v yq &> /dev/null; then
  echo "yq is not installed. Please install it and try again."
  exit 1
fi

# Convert the existing YAML format to the new format
yq eval '{
  verbose: .verbose,
  dryRun: .dryRun,
  namespaces: .namespaces | map({
    name: .name,
    annotations: {
      "linkerd.io/inject": .annotation
    }
  })
}' "$INPUT_FILE" > "$OUTPUT_FILE"

echo "Conversion complete. New configuration saved to $OUTPUT_FILE"
```

### Usage

1. Save the script above as `convert_yaml.sh`.
2. Make the script executable:
   ```bash
   chmod +x convert_yaml.sh
   ```
3. Run the script with your existing configuration file as input and specify the output file:
   ```bash
   ./convert_yaml.sh old_config.yaml new_config.yaml
   ```

### Example

Given the existing `old_config.yaml`:
```yaml
verbose: true
dryRun: true
namespaces:
  - name: namespace1
    annotation: enabled
  - name: namespace2
    annotation: disabled
  - name: namespace3
    annotation: enabled
  - name: namespace4
    annotation: disabled
```

Running the conversion script:
```bash
./convert_yaml.sh old_config.yaml new_config.yaml
```

Will produce `new_config.yaml`:
```yaml
verbose: true
dryRun: true
namespaces:
  - name: namespace1
    annotations:
      linkerd.io/inject: enabled
  - name: namespace2
    annotations:
      linkerd.io/inject: disabled
  - name: namespace3
    annotations:
      linkerd.io/inject: enabled
  - name: namespace4
    annotations:
      linkerd.io/inject: disabled
```

This new format will be compatible with the enhanced `generic_namespace_annotator.sh` script.

```
#!/bin/bash

# Function to display usage
usage() {
  echo "Usage: $0 <input_config_file> <output_config_file>"
  echo "  <input_config_file>  Path to the existing YAML configuration file"
  echo "  <output_config_file> Path to the new YAML configuration file"
  exit 1
}

# Validate input arguments
if [ "$#" -ne 2 ]; then
  usage
fi

INPUT_FILE=$1
OUTPUT_FILE=$2

# Check if yq is installed
if ! command -v yq &> /dev/null; then
  echo "yq is not installed. Please install it and try again."
  exit 1
fi

# Convert the existing YAML format to the new format
yq eval '{
  verbose: .verbose,
  dryRun: .dryRun,
  namespaces: .namespaces | map({
    name: .name,
    annotations: {
      "linkerd.io/inject": .annotation
    }
  })
}' "$INPUT_FILE" > "$OUTPUT_FILE"

echo "Conversion complete. New configuration saved to $OUTPUT_FILE"

```
