# Software-Defined Infrastructure (SDI) for Automated Load Balancing

## Descripción

Este repositorio contiene el código fuente desarrollado para el Trabajo Final de Especialización:

**"Balanceo de Carga utilizando Infraestrutura definida por Software"**

El proyecto presenta una prueba de concepto (Proof of Concept - PoC) que integra tecnologías de Redes Definidas por Software (SDN) e Infraestructura como Código (IaC) para automatizar el escalado horizontal de servidores web en función de la carga de la red.

La solución combina un controlador SDN basado en **Ryu**, una red emulada mediante **Mininet/Open vSwitch**, el aprovisionamiento automático mediante **Terraform** y un balanceador de carga **HAProxy**.

---

## Objetivos

El objetivo principal es demostrar la factibilidad de automatizar el balanceo de carga mediante una arquitectura SDI capaz de:

- Detectar incrementos de carga sobre la infraestructura.
- Aprovisionar nuevos servidores automáticamente.
- Incorporar los nuevos servidores al balanceador de carga.
- Eliminar servidores cuando la demanda disminuye.
- Reducir la intervención manual durante el proceso de escalado.

---

## Tecnologías utilizadas

- Python 3
- Ryu SDN Framework
- OpenFlow 1.3
- Open vSwitch
- Mininet
- Terraform
- HAProxy
- Linux

---

## Estructura del repositorio

```
.
├── tf-web/                # Configuración Terraform para el aprovisionamiento
├── autoescalado.py        # Primera implementación del mecanismo de autoescalado
├── autoescale.py          # Implementación principal del autoescalado
├── ovs-ryu.py             # Aplicación del controlador SDN (Ryu)
└── README.md
```

---

## Funcionamiento

La arquitectura implementa el siguiente flujo:

1. Mininet genera la topología SDN.
2. Open vSwitch envía los eventos al controlador Ryu.
3. El controlador monitorea el tráfico de la red.
4. Cuando la carga supera el umbral configurado mediante un script de python se realizará el autoescalado, luego:
   - se ejecuta Terraform;
   - se crea un nuevo servidor web;
   - HAProxy incorpora automáticamente el nuevo backend.
5. Cuando la carga disminuye con el script se solicitara que :
   - Terraform elimina los recursos excedentes;
   - HAProxy actualiza nuevamente la configuración.

---

## Estado del proyecto

Este proyecto corresponde a una **prueba de concepto desarrollada con fines académicos**.

La implementación valida el funcionamiento del mecanismo de autoescalado y la integración entre SDN e IaC, pero no constituye una solución orientada a producción ni incluye una evaluación cuantitativa de rendimiento frente a soluciones comerciales.

---

## Trabajo futuro

Entre las posibles líneas de evolución del proyecto se encuentran:

- Comparación de rendimiento con balanceadores tradicionales.
- Incorporación de métricas de QoS.
- Implementación de las Rutas B y C propuestas en la tesis.
- Integración completa de la lógica de escalado dentro del controlador SDN.
- Soporte para múltiples servicios y balanceadores.

---

## Autor

**Lorena Garcia**

Trabajo Final de Especialización.

Universidad Nacional de La Plata

---


Este proyecto se distribuye con fines académicos y de investigación.

