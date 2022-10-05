output "api_url" {
  description = "URL for changing a machine replication state."
  value = { for k, v in var.microservices : k => "${v.trigger.http.method} ${aws_apigatewayv2_stage.this.0.invoke_url}${v.trigger.http.path}" if (v.trigger != null && v.trigger.http != null) }
}