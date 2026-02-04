#!/usr/bin/env bash
# Detecta microcortes y degradaciones de red con ICMP, TCP connect y HTTP.
# Logs en: /var/log/net-microcut/raw.log (detalle) y /var/log/net-microcut/events.csv (eventos)

set -euo pipefail

# ---------- CONFIG ----------
INTERVAL_HINT="30s"                       # solo informativo en logs
LOG_DIR="/var/log/net-microcut"
RAW_LOG="$LOG_DIR/raw.log"
EVT_LOG="$LOG_DIR/events.csv"

# Umbrales (ajustá a tu realidad)
PING_COUNT=5
LOSS_WARN=1           # % de pérdida para marcar evento (>=1% sobre ventana corta ya es sospechoso)
RTT_P95_WARN=50       # ms: si el P95 del ping pasa esto, marcamos latencia alta
TCP_TIMEOUT=2         # s: timeout para connect TCP
HTTP_URL="https://www.tu-universidad.edu.ar/"   # URL a testear
HTTP_TIMEOUT=3        # s
HTTP_TTFB_WARN=0.500  # s: TTFB alto (posible congestión)
HTTP_CODE_OK="200 301 302"  # Códigos aceptables

# Objetivos a testear (ICMP + TCP). Usá IPs de gestión si querés aislar capa 2.
TARGETS_ICMP=(
  "Gateway|192.168.0.1"
  "CoreSwitch|10.0.0.2"
  "RectoradoDell|10.0.0.10"
  "WebServer|AA.BB.CC.DD"   # reemplazar por IP real del servidor web
  "DNS1|8.8.8.8"
)
TARGETS_TCP=(
  "Web443|AA.BB.CC.DD:443"
  "Web80|AA.BB.CC.DD:80"
)

# ---------- FUNCIONES ----------
ts() { date +"%Y-%m-%d %H:%M:%S%z"; }

ensure_dirs() {
  mkdir -p "$LOG_DIR"
  [[ -f "$EVT_LOG" ]] || echo "timestamp,type,target,metric,value,extra" > "$EVT_LOG"
}

log_raw() { echo "$(ts) | $*" >> "$RAW_LOG"; }
log_evt() { echo "$(ts),$1,$2,$3,$4,$5" >> "$EVT_LOG"; }

have_cmd() { command -v "$1" >/dev/null 2>&1; }

ping_stats() {
  local host="$1"
  if have_cmd fping; then
    # fping es muy bueno para sondeos cortos
    # -q: quiet, -C: N pings, -p 200ms spacing
    local out; out=$(fping -C "$PING_COUNT" -p 200 -q "$host" 2>&1 || true)
    # out ej: "host : 0.24 0.22 - 0.25 0.21"
    local losses=0; local rtts=()
    for tok in $out; do
      if [[ "$tok" == "-" ]]; then
        ((losses++))
      elif [[ "$tok" =~ ^[0-9]+\.[0-9]+$ ]]; then
        rtts+=("$tok")
      fi
    done
    local loss_pct=$(( 100*losses / PING_COUNT ))
    # P95
    local p95="0"
    if (( ${#rtts[@]} > 0 )); then
      IFS=$'\n' rtts_sorted=($(sort -n <<<"${rtts[*]}")); unset IFS
      local idx=$(( (95*${#rtts_sorted[@]} + 99)/100 -1 ))
      (( idx < 0 )) && idx=0
      (( idx >= ${#rtts_sorted[@]} )) && idx=$(( ${#rtts_sorted[@]} -1 ))
      p95="${rtts_sorted[$idx]}"
    fi
    echo "$loss_pct" "$p95"
  else
    # ping estándar
    local out; out=$(ping -c "$PING_COUNT" -i 0.2 -n "$host" 2>&1 || true)
    # pérdida
    local loss_pct; loss_pct=$(grep -Eo '[0-9]+% packet loss' <<<"$out" | grep -Eo '^[0-9]+')
    [[ -z "$loss_pct" ]] && loss_pct=100
    # RTT P95 aproximado: usamos max como proxy si no hay percentiles
    local max_rtt; max_rtt=$(grep -Eo 'rtt min/avg/max/[a-z]+ = [0-9\.]*/[0-9\.]*/[0-9\.]*/' <<<"$out" | awk -F'/' '{print $6}' | tr -d '/')
    [[ -z "$max_rtt" ]] && max_rtt=0
    echo "$loss_pct" "$max_rtt"
  fi
}

tcp_connect() {
  local hostport="$1"
  # Usamos curl para medir tiempo de conexión TCP/TLS sin descargar nada
  local host=${hostport%:*}
  local port=${hostport#*:}
  local proto_opt=()
  [[ "$port" == "443" ]] && proto_opt=(--ssl-reqd)
  curl -sS -o /dev/null --max-time "$TCP_TIMEOUT" "${proto_opt[@]}" \
       -w "%{time_connect};%{time_appconnect};%{errormsg}" \
       "http://$host:$port/" 2>/dev/null || true
}

http_check() {
  # Devuelve: code;ttfb;total;err
  curl -sS -o /dev/null --max-time "$HTTP_TIMEOUT" -w "%{http_code};%{time_starttransfer};%{time_total};%{errormsg}" \
       "$HTTP_URL" 2>/dev/null || true
}

in_list() {
  local needle="$1"; shift
  for x in $*; do [[ "$x" == "$needle" ]] && return 0; done
  return 1
}

# ---------- MAIN ----------
ensure_dirs
log_raw "=== run interval=$INTERVAL_HINT ==="

# ICMP
for pair in "${TARGETS_ICMP[@]}"; do
  name="${pair%%|*}"; host="${pair##*|}"
  read -r loss p95 <<<"$(ping_stats "$host")"
  log_raw "ICMP $name $host loss=${loss}% p95=${p95}ms"
  if (( loss >= LOSS_WARN )); then
    log_evt "icmp-loss" "$name" "loss_pct" "$loss" "host=$host"
  fi
  awk -v p="$p95" -v thr="$RTT_P95_WARN" 'BEGIN{exit !(p+0>=thr)}'
  if (( $? == 0 )); then
    log_evt "icmp-latency" "$name" "p95_ms" "$p95" "host=$host"
  fi
done

# TCP CONNECT
for tp in "${TARGETS_TCP[@]}"; do
  name="${tp%%|*}"; hostp="${tp##*|}"
  res="$(tcp_connect "$hostp")"  # time_connect;time_appconnect;err
  t_conn="$(cut -d';' -f1 <<<"$res")"
  t_tls="$(cut -d';' -f2 <<<"$res")"
  err="$(cut -d';' -f3 <<<"$res")"
  log_raw "TCP $name $hostp connect=${t_conn}s tls=${t_tls}s err=${err:-none}"
  if [[ -n "$err" ]]; then
    log_evt "tcp-fail" "$name" "error" "1" "hostp=$hostp;msg=$err"
  elif awk -v t="$t_conn" -v to="$TCP_TIMEOUT" 'BEGIN{exit !(t+0>=to)}'; then
    log_evt "tcp-slow" "$name" "time_connect_s" "$t_conn" "hostp=$hostp"
  fi
done

# HTTP GET
hres="$(http_check)" # code;ttfb;total;err
code="$(cut -d';' -f1 <<<"$hres")"
ttfb="$(cut -d';' -f2 <<<"$hres")"
ttot="$(cut -d';' -f3 <<<"$hres")"
herr="$(cut -d';' -f4 <<<"$hres")"
log_raw "HTTP $HTTP_URL code=$code ttfb=${ttfb}s total=${ttot}s err=${herr:-none}"

if [[ -n "$herr" || "$code" == "000" ]]; then
  log_evt "http-fail" "HTTP" "error" "1" "url=$HTTP_URL;msg=${herr:-timeout}"
elif ! in_list "$code" $HTTP_CODE_OK; then
  log_evt "http-badcode" "HTTP" "code" "$code" "url=$HTTP_URL"
fi

awk -v t="$ttfb" -v thr="$HTTP_TTFB_WARN" 'BEGIN{exit !(t+0>=thr)}'
if (( $? == 0 )); then
  log_evt "http-ttfb-high" "HTTP" "ttfb_s" "$ttfb" "url=$HTTP_URL"
fi
