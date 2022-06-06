output "api_url" {
  description = "URL for changing a machine replication state."
  value = { for k, v in var.microservices : k => trimsuffix("${v.trigger.method} ${aws_apigatewayv2_stage.this.invoke_url}${v.trigger.path}", "/") }
}