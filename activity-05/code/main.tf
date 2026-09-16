# Activity 5 - Infrastructure as Code
# Run the todo service (version 3.0) and its redis database with Terraform.

terraform {
  required_version = ">= 1.5"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

# Talks to the local Docker daemon. The host is left at the provider default so
# it follows DOCKER_HOST / unix:///var/run/docker.sock, which keeps the file
# portable between Docker Desktop and a plain dockerd.
provider "docker" {}

variable "todo_image" {
  description = "Docker image of the todo service (version 3.0)."
  type        = string
  default     = "natawut/todo-service:release-3"
}

variable "redis_image" {
  description = "Docker image of the redis database."
  type        = string
  default     = "redis:7-alpine"
}

# todo 3.0 POSTs a notification to NOTIFICATION_HOST:NOTIFICATION_PORT on every
# created todo and never checks the response, but a refused connection raises
# out of the request handler and turns POST / into a 500. This activity has no
# notification service to point it at, so a plain nginx stands in as the
# endpoint: it answers 405 to the notification POST, todo discards the response,
# and creating a todo succeeds. Swap this for the real notification service and
# nothing else in this file has to change.
variable "notification_image" {
  description = "Docker image standing in for the notification endpoint."
  type        = string
  default     = "nginx:alpine"
}

variable "todo_port" {
  description = "Host port the todo service is published on."
  type        = number
  default     = 8000
}

# ---------------------------------------------------------------------------
# Network
# ---------------------------------------------------------------------------

# A user-defined bridge network gives both containers Docker's embedded DNS, so
# todo can reach redis by container name (REDIS_HOST=redis below).
resource "docker_network" "todo_net" {
  name   = "todo-net"
  driver = "bridge"
}

# ---------------------------------------------------------------------------
# Images
# ---------------------------------------------------------------------------

resource "docker_image" "redis" {
  name         = var.redis_image
  keep_locally = true
}

resource "docker_image" "todo" {
  name         = var.todo_image
  keep_locally = true
}

resource "docker_image" "notification" {
  name         = var.notification_image
  keep_locally = true
}

# ---------------------------------------------------------------------------
# Containers
# ---------------------------------------------------------------------------

# Not published to the host: only the todo service needs to reach it, and it
# does so over todo-net.
resource "docker_container" "redis" {
  name    = "redis"
  image   = docker_image.redis.image_id
  restart = "unless-stopped"

  networks_advanced {
    name = docker_network.todo_net.name
  }
}

# Answers the notification POST described by var.notification_image. Like redis,
# it is internal to todo-net only.
resource "docker_container" "notification" {
  name    = "notification-service"
  image   = docker_image.notification.image_id
  restart = "unless-stopped"

  networks_advanced {
    name = docker_network.todo_net.name
  }
}

resource "docker_container" "todo" {
  name    = "todo-service"
  image   = docker_image.todo.image_id
  restart = "unless-stopped"

  env = [
    "REDIS_HOST=${docker_container.redis.name}",
    "REDIS_PORT=6379",
    "NOTIFICATION_HOST=${docker_container.notification.name}",
    "NOTIFICATION_PORT=80",
  ]

  ports {
    internal = 8000
    external = var.todo_port
  }

  networks_advanced {
    name = docker_network.todo_net.name
  }

  # Terraform already infers these from the REDIS_HOST / NOTIFICATION_HOST
  # references above; stated explicitly so the ordering survives any edit to
  # those lines.
  depends_on = [
    docker_container.redis,
    docker_container.notification,
  ]
}

# ---------------------------------------------------------------------------
# Outputs
# ---------------------------------------------------------------------------

output "todo_url" {
  description = "Where the todo service is reachable from the host."
  value       = "http://localhost:${var.todo_port}"
}

output "container_names" {
  description = "Containers created by this configuration."
  value = [
    docker_container.todo.name,
    docker_container.redis.name,
    docker_container.notification.name,
  ]
}
