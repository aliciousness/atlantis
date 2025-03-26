package terraform.providers

# Import the Rego v1 API
import rego.v1

# Grouping of allowed providers by full path
allowed_providers := {
	"registry.terraform.io/hashicorp/aws",
	"registry.terraform.io/hashicorp/github",
	"registry.terraform.io/hashicorp/random",
	"registry.terraform.io/hashicorp/time",
	"registry.terraform.io/hashicorp/local",
	"registry.terraform.io/hashicorp/kubernetes",
}

# Deny policy that prevents the use of disallowed providers
deny contains msg if {
  # Iterate over all providers in the configuration
	some list_providers in input.configuration.provider_config
  # Check if the provider is not in the allowed_providers list
	not allowed_providers[list_providers.full_name]
  # Return denial message with providers not allowed
	msg = sprintf("Provider `%v` not allowed", [list_providers.full_name])
}
