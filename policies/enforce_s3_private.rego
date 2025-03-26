# Check S3 bucket is not public
# This rego was stolen from some sample policies that can be found here https://github.com/Scalr/sample-tf-opa-policies/tree/master/aws

package aws.tf.s3.private
# Import the Rego v1 API
import rego.v1
import input.tfplan as tfplan

deny[reason] if {
	some r in tfplan.resource_changes
	r.mode == "managed"
	r.type == "aws_s3_bucket"
	r.change.after.acl == "public"

	reason := sprintf("%-40s :: S3 buckets must not be PUBLIC", [r.address])
}