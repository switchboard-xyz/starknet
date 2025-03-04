#!/bin/bash

# Build the output abi.ts file 
# Input JSON file
input_file="./target/dev/btc_feed_example_contract.contract_class.json"

# Output TypeScript file
output_file="./scripts/abi.ts"

# Extract the "abi" field from the JSON file, format it for TypeScript, and write to the output file
echo -n "export const ABI = " > "$output_file"
jq -r '.abi' "$input_file" >> "$output_file"
sed -i '' -e '$ s/$/\ as const;/' "$output_file"

# Check if the operation was successful
if [ $? -eq 0 ]; then
    echo "ABI successfully extracted and written to $output_file"
else
    echo "An error occurred while processing the file"
fi
