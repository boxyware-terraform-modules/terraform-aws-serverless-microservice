# AWS Serverless Microservices

This module allows you to create serverless microservices using AWS Lambda as backend and expose them as REST services using the AWS API Gateway.

## Compatibility

This module is meant for use with Terraform 1.1.9+ and tested using Terraform 1.2+. If you find incompatibilities using Terraform >=1.1.9, please open an issue.

## Usage

There are multiple examples included in the [examples](./examples/) folder but simple usage is as follows:

```hcl
module "microservices" {
  source = "boxyware-terraform-modules/terraform-aws-serverless-microservice"
  version = "~> 0.0.1"

  name    = "my-micro"
  context = "api"

  labels = {
    name        = "my-micro"
    environment = "dev"
  }

  microservices = {
    health = {
      description = "Return the health status."
      source_path = "src/health"
      handler     = "index.health"
      runtime     = "python3.8"
      iam         = null
      
      trigger = {
        method = "GET"
        path   = "/health"
      }
    },  
  }
}
```

## Features

The AWS Serverless Microservices module will take the following actions:

1. Create an AWS Lambda function concatenating `name` and `microservice key` as name and using `source_path` as source code and `handler` as entrypoint.
2. Create an AWS API Gateway API to group all the microservices passed as part of the `microservices` map.
3. Create an AWS API Gateway Stage using `context` as name.
4. Configure the access logs.
5. Create as many AWS API Gateway Routes as different microservices objects have been passed in `microservices`.
6. Assign the IAM permission to the API Gateway API to invoke the different Lambda functions.

The roles granted are specifically:

- `AllowExecutionFromAPIGateway` on the API Gateway API created for this project

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| name | Name of the whole API. This variable will be used to give a name to the API Gateway API. | `string` | n/a | yes |
| context | HTTP context of the API. All the microservices will be created as REST resources under this context. E.g.: /{context}/{resource_name} | `string` | n/a | yes |
| microservices | Map to group all the microservices configuration. The map key represent the name of the microservice and the value contains all the parameters needed for the deployment as a REST resource. | <pre>map(object({<br>    description = string<br>    source_path = string<br>    handler     = string<br>    runtime     = string<br>    iam         = string<br>    trigger = object({<br>      method = string<br>      path   = string<br>  }))</pre> | n/a | yes |
| labels | The tags for the AWS Lambda and AWS API Gateway resources | `any` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| api_url | The method and the endpoint of every microservice deployed |


## Requirements

### Software

-   [Terraform](https://www.terraform.io/downloads.html) >= 1.1.9
-   [terraform-provider-aws] plugin ~> 4.13.0


### Permissions

In order to execute this module you must have a Role with the
following policies:

- `AWSLambda_FullAccess`
- `AmazonS3ObjectLambdaExecutionRolePolicy`
- `AmazonAPIGatewayAdministrator`