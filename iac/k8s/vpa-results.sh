#!/bin/sh


# Function to convert bytes to MiB
bytes_to_mib() {
  echo "Recommended Target Memory Request Size: $(( $1 / 1048576 )) MiB"
  return $(( $1 / 1048576 )) 
}

# Function to convert bytes to GiB
bytes_to_gib() {
  echo "Recommended Target Memory Request Size: $(( $1 / 1073741824 )) GiB"
  return $(( $1 / 1073741824 ))
}

double_kubernetes_cpu() {
  local cpu_value="$1"
  # Extract the numerical part using parameter expansion
  local numeric_part="${cpu_value%%[a-zA-Z]*}"
  # Double the numeric part
  local doubled_numeric_part=$((numeric_part * 2))
  # Append the "m" suffix back to the doubled numeric part
  local doubled_cpu_value="${doubled_numeric_part}m"
  echo "$doubled_cpu_value"
}



# Execute kubectl describe vpa <vpa-instance> -n <app-vpa-namespace>
vpa_value=$(kubectl describe vpa hamster-vpa -n hamster-app)
target_recommendations=$(echo "$vpa_value" | sed -n '/Recommendation:/,/Actual:/p')
echo "$target_recommendations"


# Extract the 'Memory' attribute under the 'Target' subsection
memory_value=$(echo "$target_recommendations" | awk '/Target:/ {found=1} found && /Memory:/ {print $2; exit}')
cpu_value=$(echo "$target_recommendations" | awk '/Target:/ {found=1} found && /Cpu:/ {print $2; exit}')


ret=0
size_in_bytes=$memory_value
if [ $size_in_bytes -lt 1073741824 ]; then
  bytes_to_mib $size_in_bytes
  ret=$?
  echo "Recommended Target Memory Limit Size: $((ret * 2)) MiB"
else
  bytes_to_gib $size_in_bytes
  ret=$?
  echo "Recommended Target Memory Limit Size: $((ret * 2)) Gi"
fi

echo "Recommended Target CPU Request Size: $cpu_value"
doubled_cpu_value=$(double_kubernetes_cpu "$cpu_value")
echo "Recommended Target CPU Limit Size: $doubled_cpu_value"





