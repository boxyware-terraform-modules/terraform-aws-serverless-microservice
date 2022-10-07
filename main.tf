#-----------------------------------------------------------------------------------
# API Implementation
#-----------------------------------------------------------------------------------
module "api_function" {
  for_each = var.microservices
  source   = "terraform-aws-modules/lambda/aws"
  version  = "4.0.2"

  function_name         = "${var.name}-${each.key}"
  source_path           = each.value.source_path
  description           = each.value.description
  handler               = each.value.handler
  runtime               = each.value.runtime
  environment_variables = each.value.env_vars
  attach_policies       = length(each.value.iam) > 0
  policies              = each.value.iam
  number_of_policies    = length(each.value.iam)

  tags = merge(
    tomap({ Name = "${var.name}-${each.key}" }),
    var.labels
  )
}

#-----------------------------------------------------------------------------------
# HTTP Trigger
#-----------------------------------------------------------------------------------
# API
resource "aws_apigatewayv2_api" "this" {
  count         = length([ for k, v in var.microservices : k if (v.trigger != null && v.trigger.http != null) ]) > 0 ? 1 : 0
  name          = "${var.name}-${var.context}"
  protocol_type = "HTTP"
  cors_configuration {
    allow_origins = ["*"]
    # allow_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST" ,"PUT"]
    allow_methods = ["*"]
    allow_headers = ["Content-Type", "Authorization", "X-Amz-Date", "X-Api-Key", "X-Amz-Security-Token"]
  }
}

resource "aws_apigatewayv2_stage" "this" {
  count       = length([ for k, v in var.microservices : k if (v.trigger != null && v.trigger.http != null) ]) > 0 ? 1 : 0
  api_id      = aws_apigatewayv2_api.this.0.id
  name        = var.context
  auto_deploy = true
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.this.0.arn
    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
    })
  }
}

resource "aws_cloudwatch_log_group" "this" {
  count             = length([ for k, v in var.microservices : k if (v.trigger != null && v.trigger.http != null) ]) > 0 ? 1 : 0
  name              = "/aws/apigw/${aws_apigatewayv2_api.this.0.name}"
  retention_in_days = 30
}

# Routes
resource "aws_apigatewayv2_integration" "this" {
  for_each           = { for k, v in var.microservices : k => v if (v.trigger != null && v.trigger.http != null) }
  api_id             = aws_apigatewayv2_api.this.0.id
  integration_uri    = module.api_function[each.key].lambda_function_invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "this" {
  for_each  = { for k, v in var.microservices : k => v if (v.trigger != null && v.trigger.http != null) }
  api_id    = aws_apigatewayv2_api.this.0.id
  route_key = "${each.value.trigger.http.method} ${each.value.trigger.http.path}"
  target    = "integrations/${aws_apigatewayv2_integration.this[each.key].id}"
}

# resource "aws_apigatewayv2_route" "api_root" {
#   for_each  = { for k, v in var.microservices : k => v if v.trigger.path == "/" }
#   api_id    = aws_apigatewayv2_api.this.id
#   route_key = "$default"
#   target    = "integrations/${aws_apigatewayv2_integration.this[each.key].id}"
# }

resource "aws_lambda_permission" "api" {
  for_each      = { for k, v in var.microservices : k => v if (v.trigger != null && v.trigger.http != null) }
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = module.api_function[each.key].lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.0.execution_arn}/*/*"
}

#-----------------------------------------------------------------------------------
# SNS Trigger
#-----------------------------------------------------------------------------------
resource "aws_sns_topic_subscription" "this" {
  for_each  = { for k, v in var.microservices : k => v if (v.trigger != null && v.trigger.topic != null) }
  topic_arn = each.value.trigger.topic
  protocol  = "lambda"
  endpoint  = module.api_function[each.key].lambda_function_arn
}

resource "aws_lambda_permission" "sns" {
  for_each      = { for k, v in var.microservices : k => v if (v.trigger != null && v.trigger.topic != null) }
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = module.api_function[each.key].lambda_function_name
  principal     = "sns.amazonaws.com"
  source_arn    = each.value.trigger.topic
}