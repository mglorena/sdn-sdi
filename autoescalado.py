#!/usr/bin/env python3
import subprocess, time, re, os, json, math
from pathlib import Path

#!/usr/bin/env python3
import subprocess, time, re, os, json, math
from pathlib import Path

# === Parametros para la configuración ===
S1_NAME      = "s1"            # bridge OVS en Mininet
PORT_NAME    = [1,2,3]         # puertos que voy a vigilar.
INTERVAL_S   = 2.0             # segundos entre muestras
EMA_ALPHA    = 0.3             # suavizado exponencial para Mbps

THRESH_UP    = 60.0            # Mbps para escalar hacia arriba
THRESH_DOWN  = 20.0            # Mbps para escalar hacia abajo
UP_STREAK    = 3               # # de intervalos consecutivos por encima para escalar up
DOWN_STREAK  = 5               # # de intervalos consecutivos por debajo para escalar down

MIN_COUNT    = 1               # límites de autoscaling
MAX_COUNT    = 8

TF_DIR       = str(Path.home() / "tf-web")  # carpeta con tu main.tf de HAProxy+Nginx
TF_BIN       = "terraform"     # asume terraform en PATH; si no, pon ruta absoluta

# === final ===

def dump_ports(bridge):
    out = subprocess.check_output(["sudo", "ovs-ofctl","-O","OpenFlow13","dump-ports", bridge], text=True, stderr=subprocess.STDOUT)
    return out
def read_port_bytes(bridge, port_ids):
    out = dump_ports(bridge)
    # divide cada bloque que empieza con 'port'
    port_blocks = re.split(r"\n(?=\s*port\s+)", out, flags=re.IGNORECASE)
    # convierte a lista si se pasó un único puerto
    if isinstance(port_ids, int):
        port_ids = [port_ids]
    rx_total = tx_total = 0
    encontrados = []
    for blk in port_blocks:
        # detectar líneas como 'port 1:' o 'port  1:'
        m = re.match(r"\s*port\s+(\d+)\s*:", blk)
        if m:
            pid = int(m.group(1))
            if pid in port_ids:
                rx = re.search(r"rx\s+.*?bytes[:=]\s*(\d+)", blk, re.IGNORECASE)
                tx = re.search(r"tx\s+.*?bytes[:=]\s*(\d+)", blk, re.IGNORECASE)
                if rx and tx:
                    rx_total += int(rx.group(1))
                    tx_total += int(tx.group(1))
                    encontrados.append(pid)

    if not encontrados:
        raise RuntimeError(
            f"No se encontró ninguno de los puertos {port_ids }.\nSalida ovs-ofctl:\n{out}"
        )

    return rx_total, tx_total
def get_current_server_count():
    # intenta leer de terraform el server_count actual desde outputs o desde backend_urls
    try:
        out = subprocess.check_output([TF_BIN,"-chdir="+TF_DIR,"output","-json"], text=True)
        j = json.loads(out)
        if "backend_urls" in j and j["backend_urls"]["value"]:
            return len(j["backend_urls"]["value"])
    except Exception:
        pass
    # fallback: intenta tfstate
    state = Path(TF_DIR) / "terraform.tfstate"
    if state.exists():
        try:
            j = json.loads(state.read_text())
            # no es trivial; si falla, devuelve un valor por defecto razonable
        except Exception:
            pass
    return 2  # por defecto, como en tu variables.tf

def apply_server_count(n):
    n = max(MIN_COUNT, min(MAX_COUNT, int(n)))
    print(f"=============================== Escalando/Descenso en  Terraform =============================")
    print(f"Aplicando server_count={n}")
    subprocess.check_call([TF_BIN,"-chdir="+TF_DIR,"apply","-auto-approve",f"-var=server_count={n}"])

def main():
    # Estado
    rx_prev, tx_prev = read_port_bytes(S1_NAME, PORT_NAME)
    last_time = time.time()
    ema_mbps = None
    up_run = down_run = 0
    cur = get_current_server_count()
    print(f"Iniciado")
    print(f"Server count actual en terraform: {cur}. Monitoreando {S1_NAME}:{PORT_NAME}")

    while True:
        time.sleep(INTERVAL_S)
        now = time.time()
        dt = max(1e-6, now - last_time)
        last_time = now

        try:
            rx, tx = read_port_bytes(S1_NAME, PORT_NAME)
        except Exception as e:
            print(f"ERROR leyendo puerto: {e}")
            continue

        drx = rx - rx_prev
        dtx = tx - tx_prev
        rx_prev, tx_prev = rx, tx

        # bits a Mbps
        mbps = (drx + dtx) * 8.0 / dt / 1e6
        ema_mbps = mbps if ema_mbps is None else (EMA_ALPHA * mbps + (1-EMA_ALPHA) * ema_mbps)
        print(f"Inst: {mbps:7.2f} Mbps | EMA: {ema_mbps:7.2f} Mbps | cur={cur}")

        # Histéresis
        if ema_mbps >= THRESH_UP and cur < MAX_COUNT:
            up_run += 1; down_run = 0
            if up_run >= UP_STREAK:
                cur += 1
                apply_server_count(cur)
                up_run = down_run = 0
        elif ema_mbps <= THRESH_DOWN and cur > MIN_COUNT:
            down_run += 1; up_run = 0
            if down_run >= DOWN_STREAK:
                cur -= 1
                apply_server_count(cur)
                up_run = down_run = 0
        else:
            up_run = down_run = 0

if __name__ == "__main__":
    main()
