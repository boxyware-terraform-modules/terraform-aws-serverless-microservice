#-----------------------------------------------------------------------------------
# API Implementation
#-----------------------------------------------------------------------------------
module "api_function" {
  for_each = var.microservices
  source   = "terraform-aws-modules/lambda/aws"
  version  = "3.2.0"

  function_name = "${var.name}-${each.key}"
  source_path   = each.value.source_path
  description   = each.value.description
  handler       = each.value.handler
  runtime       = each.value.runtime

  #   environment_variables = {
  #     KEY = "value"
  #   }

  attach_policy = each.value.iam != null
  policy        = each.value.iam

  tags = merge(
    tomap({ Name = "${var.name}-${each.key}" }),
    var.labels
  )
}

#-----------------------------------------------------------------------------------
# API Route
#-----------------------------------------------------------------------------------
# API
resource "aws_apigatewayv2_api" "this" {
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
  api_id      = aws_apigatewayv2_api.this.id
  name        = var.context
  auto_deploy = true
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.this.arn
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
  name              = "/aws/apigw/${aws_apigatewayv2_api.this.name}"
  retention_in_days = 30
}

# Routes
resource "aws_apigatewayv2_integration" "this" {
  for_each           = var.microservices
  api_id             = aws_apigatewayv2_api.this.id
  integration_uri    = module.api_function[each.key].lambda_function_invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "this" {
  for_each  = var.microservices
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "${each.value.trigger.method} ${each.value.trigger.path}"
  target    = "integrations/${aws_apigatewayv2_integration.this[each.key].id}"
}

resource "aws_apigatewayv2_route" "api_root" {
  for_each  = { for k, v in var.microservices : k => v if v.trigger.path == "/" }
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.this[each.key].id}"
}

resource "aws_lambda_permission" "api" {
  for_each      = var.microservices
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = module.api_function[each.key].lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}
