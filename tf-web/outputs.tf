output "vip_url" {
  value = "http://localhost:${var.vip_port}/"
}

# Como sabemos que los expusimos en 8080 + index, generamos la lista sin leer el set de ports
output "backend_urls" {
  value = [
    for idx in range(var.server_count) :
    "http://localhost:${8080 + idx}/"
  ]
}

output "backend_ips" {
  value = [
    for c in docker_container.web :
    "${c.name} -> ${c.network_data[0].ip_address}:80"
  ]
}
