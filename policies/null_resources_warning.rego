package terraform.null_resources

# Import the Rego v1 API
import rego.v1

# Define the set of resource types we want to check
# Currently only checking for null_resource
resource_types := {"null_resource"}

# Rule to collect all resources of specified types from the Terraform plan
# Input: resource type from resource_types
# Output: Array of resources matching the specified type
resources[resource_type] := is_all if {
    some resource_type
    resource_types[resource_type]
    is_all := [name |
        some name in input.resource_changes
        name.type == resource_type
    ]
}

# Rule to count the number of resources being created for each resource type
# Input: resource type from resource_types
# Output: Number of resources of that type that are being created
num_creates[resource_type] := num if {
    some resource_type
    resource_types[resource_type]
    is_all := resources[resource_type]
    creates := [res | res := is_all[_]; res.change.actions[_] == "create"]
    num := count(creates)
}

# Denial rule that prevents creation of null resources
# Triggers if any null resources are being created (count > 0)
deny contains msg if {
    # Get the count of null resources being created
    num_resources := num_creates.null_resource

    # Check if there are any null resources being created
    num_resources > 0

    # Return denial message
    msg := "null resources cannot be created"
}
