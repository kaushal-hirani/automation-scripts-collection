#!/bin/bash

bucket_name="test"
output_file="test_object_list.txt"
marker=""
batch_number=1
batch_size=1000
listed_objects=0

# Get the total number of objects in the bucket dynamically
max_objects=$(radosgw-admin bucket stats --bucket=$bucket_name | jq -r '.["usage"]["rgw.main"].num_objects')

# Empty the output file
> "$output_file"

# Create a temporary file to track listed object names
temp_file="temp_object_list.txt"
> "$temp_file"

# Fetch objects in batches of 1000 until no more objects are found or the max_objects limit is reached
while [ "$listed_objects" -lt "$max_objects" ]; do
  if [ -z "$marker" ]; then
    # First batch without a marker
    object_names=$(radosgw-admin bucket list --bucket=$bucket_name --max-entries=$batch_size | jq -r '.[].name')
  else
    # Subsequent batches using the marker
    object_names=$(radosgw-admin bucket list --bucket=$bucket_name --marker="$marker" --max-entries=$batch_size | jq -r '.[].name')
  fi

  # Check if any objects were returned
  if [ -z "$object_names" ]; then
    break
  fi

  # Append the new object names to the temporary file
  echo "$object_names" >> "$temp_file"

  # Remove any duplicate object names between batches
  sort -u "$temp_file" > "$output_file"
  mv "$output_file" "$temp_file"

  # Get the number of unique objects listed so far
  listed_objects=$(wc -l < "$temp_file")

  # If we have listed all objects, stop
  if [ "$listed_objects" -ge "$max_objects" ]; then
    break
  fi

  # Get the name of the last object to use as the marker for the next batch
  marker=$(echo "$object_names" | tail -n 1)

  # Increment batch number
  batch_number=$((batch_number + 1))
done

# Move final list to the output file
mv "$temp_file" "$output_file"

echo "All object names are listed in $output_file"
echo "Total unique objects listed: $listed_objects"
