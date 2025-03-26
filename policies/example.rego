package demo.terraform

import data.terraform.allowed_resources

# Default deny
default allow = false

# Allow if resource type is in allowed list
allow {
    resource := input.planned_values.root_module.resources[_]
    allowed_resources[resource.type]
}