variable "server_count" {
  description = "Cantidad de backends nginx"
  type        = number
  default     = 2
}
variable "vip_port" {
  description = "Puerto host para el VIP de HAProxy"
  type        = number
  default     = 8090
}
