# AWS Private Storage with a Dedicated Application Identity

This is a Terraform configuration that deploys a S3 bucket and an IAM role the application uses to reach it, so the app never runs as a developer's personal account. It is the AWS equivalent of an Azure resource group, storage account, blob container, service principal, and RBAC.

### Azure to AWS mapping

| Azure | AWS |
|---|---|
| Resource group | AWS Resource Group (tag-based) |
| Storage account and private container | S3 bucket with a container prefix |
| Anonymous access disabled | S3 Block Public Access |
| HTTPS-only | Bucket policy denying non-TLS requests |
| App registration and service principal | IAM role |
| Storage Blob Data Contributor | Custom IAM policy (list, get, put) |
| Role assignment | Policy attachment on the role |
| Tenant ID | AWS account ID |
| Application (client) ID | Role ARN |
| Service principal object ID | Role unique ID |

## Resources

| Resource | Purpose |
|---|---|
| `aws_resourcegroups_group.main` | group that holds resources with the same tag |
| `aws_s3_bucket.main` | storage bucket |
| `aws_s3_bucket_public_access_block.main` | blocks all public access |
| `aws_s3_bucket_policy.https_only` | blocks any requests that aren't HTTPS |
| `aws_iam_role.app` | app identity |
| `aws_iam_group.bucket_users` | users allowed to assume the role |
| `aws_iam_group_policy.assume_app_role` | gives `sts:AssumeRole` on the app role |
| `aws_iam_policy.blob_data_contributor` | allows read, write, and list under the container |
| `aws_iam_role_policy_attachment.app` | attaches the policy to the role |

## Authentication model

The role has no credentials of its own. A trusted identity calls AWS STS `AssumeRole`, and AWS returns temporary credentials (access key ID, secret key, session token) that expire automatically. The role's trust policy accepts identities from this AWS account, and each identity must also be allowed to call `sts:AssumeRole` through the `bucket-users` group.

## Security

- Public and anonymous access blocked at the bucket
- HTTPS required for all requests
- Role has no delete or bucket-management permissions
- No long-lived keys for the application identity

## Prerequisites

- Terraform 1.x
- AWS CLI v2
- An AWS account and credentials able to create S3 and IAM resources. Use an IAM user or SSO login for Terraform, not the root user.


## Deployment

```
terraform init
terraform fmt
terraform validate
terraform plan
terraform apply
```

Expected plan: 9 resources to add.

#### To Delete

```
terraform destroy
```

If the bucket isn't empty, delete its objects first.
If users isn't empty, delete all users as well.

### Outputs

| Output | Meaning |
|---|---|
| `account_id` | The equivalent of the tenant ID |
| `role_arn` | The equivalent of the application (client) ID |
| `role_id` | The equivalent of the service principal object ID |
| `bucket_name`, `bucket_arn` | Bucket identifiers |
| `resource_group_name`, `resource_group_arn` | Resource group identifiers |


