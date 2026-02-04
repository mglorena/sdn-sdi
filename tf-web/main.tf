# Red Docker para los backends
resource "docker_network" "webnet" {
  name = "webnet"
  ipam_config {
    subnet  = "172.18.0.0/16"
    gateway = "172.18.0.1"
  }
}

# Imagen nginx
resource "docker_image" "nginx" {
  name         = "nginx:alpine"
  keep_locally = true
}

# Helper: tomar la ipam como lista y quedarnos con el primer elemento
locals {
  ipam                 = tolist(docker_network.webnet.ipam_config)[0]
}
# N backends
resource "docker_container" "web" {
  count = var.server_count
  name  = "web${count.index}"
  image = docker_image.nginx.image_id
  networks_advanced {
    name         = docker_network.webnet.name
    ipv4_address = cidrhost(local.ipam.subnet, count.index + 10)
  }

  # Exponer cada backend también en el host (útil para debug rápido)
  ports {
    internal = 80
    external = 8080 + count.index
  }
}
# Lista de backends para HAProxy (nombre, IP, puerto)
locals {
  backend_nodes = [
    for c in docker_container.web :
    {
      name = c.name
      ip   = c.network_data[0].ip_address
      port = 80
    }
  ]
     # Render del haproxy.cfg (contenido en memoria)
  haproxy_cfg_content = templatefile("${path.module}/haproxy.cfg.tftpl", {
    backends = local.backend_nodes
    vip_port = var.vip_port
  })
}
# Escribir haproxy.cfg a disco
resource "local_file" "haproxy_cfg" {
  filename = "${path.module}/haproxy.cfg"
  content  = local.haproxy_cfg_content
}

# Forzar recreación del contenedor haproxy al cambiar la config (usa el hash del contenido renderizado)
resource "random_id" "haproxy_rev" {
  keepers = {
    cfg_hash = sha256(local.haproxy_cfg_content)
  }
  byte_length = 2
}

# Imagen HAProxy
resource "docker_image" "haproxy" {
  name         = "haproxy:alpine"
  keep_locally = true
}

# Contenedor HAProxy (monta el haproxy.cfg generado)
resource "docker_container" "haproxy" {
  name  = "haproxy-${random_id.haproxy_rev.hex}"
  image = docker_image.haproxy.image_id

  ports {
    internal = 80
    external = var.vip_port
  }

  mounts {
    target    = "/usr/local/etc/haproxy/haproxy.cfg"
    source    = "${path.module}/haproxy.cfg"
    type      = "bind"
    read_only = true
  }

  depends_on = [local_file.haproxy_cfg, docker_container.web]
}
