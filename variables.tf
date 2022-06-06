variable "name" {
  type        = string
  description = "Name of the microservice API"
}

variable "context" {
  type        = string
  description = "HTTP context of the microservice API. It's only taken if apigateway_id input param is null"
}

variable "microservices" {
  type = map(object({
    description = string
    source_path = string
    handler     = string
    runtime     = string
    iam         = string
    # env_vars = any
    trigger = object({
      method = string
      path   = string
    })
  }))
  description = "Microservice information."
}

variable "labels" {
  type        = any
  default     = {}
  description = "Tags of the microservice API"
}