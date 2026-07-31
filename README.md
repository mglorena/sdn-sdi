# Software-Defined Infrastructure (SDI) for Automated Load Balancing

## Descripción

Este repositorio contiene el código fuente desarrollado como parte del Trabajo Final de Especialización, cuyo objetivo es implementar y validar una arquitectura de **Balanceo de carga utilizando Infraestructura Definida por Software (Software-Defined Infrastructure - SDI)** en entornos virtualizados.

La propuesta integra tecnologías de **Redes Definidas por Software (SDN)** e **Infraestructura como Código (IaC)** para demostrar un mecanismo de autoescalado capaz de aprovisionar y eliminar servidores de manera automática según la carga detectada en la infraestructura.

La implementación corresponde a una **prueba de concepto (Proof of Concept - PoC)** orientada a validar el funcionamiento de la arquitectura propuesta, sin pretender reemplazar soluciones comerciales de producción.

---

# Objetivos

El proyecto tiene como objetivo principal desarrollar una arquitectura capaz de:

* Centralizar el control de la red mediante un controlador SDN.
* Monitorear el estado del tráfico de red.
* Detectar condiciones de carga predefinidas.
* Aprovisionar automáticamente nuevos servidores utilizando Infraestructura como Código.
* Actualizar dinámicamente la configuración del balanceador de carga.
* Liberar recursos cuando la demanda disminuye.

---

# Arquitectura

La solución está compuesta por los siguientes componentes:

* **Ryu SDN Controller**

  * Implementa la lógica de monitoreo y control de la red.
  * Detecta eventos asociados a la carga de tráfico.
  * Coordina el proceso de escalado.

* **Mininet**

  * Emula la infraestructura de red utilizada durante las pruebas.
  * Implementa la topología SDN compatible con OpenFlow.

* **Open vSwitch (OVS)**

  * Actúa como switch OpenFlow administrado por Ryu.

* **Terraform**

  * Automatiza el aprovisionamiento y eliminación de servidores.
  * Implementa el enfoque de Infraestructura como Código (IaC).

* **HAProxy**

  * Funciona como balanceador de carga.
  * Actualiza automáticamente los servidores backend disponibles.

* **Servidores Web**

  * Recursos que son incorporados o retirados dinámicamente durante el proceso de autoescalado.

---

# Flujo de funcionamiento

1. Se genera tráfico sobre la red emulada.
2. El controlador Ryu monitorea las condiciones de carga.
3. Cuando se supera el umbral configurado mediante un script de autoescalado se:

   * se ejecuta Terraform;
   * se aprovisiona un nuevo servidor;
   * se actualiza automáticamente la configuración de HAProxy.
4. Cuando la carga disminuye por debajo del umbral inferior:

   * se elimina la capacidad excedente;
   * HAProxy actualiza nuevamente la lista de servidores disponibles.

---

# Tecnologías utilizadas

* Python
* Ryu SDN Framework
* OpenFlow
* Open vSwitch
* Mininet
* Terraform
* HAProxy
* Linux

---

# Estructura general del proyecto

```text
/
├── ryu/                # Aplicaciones del controlador SDN
├── terraform/          # Infraestructura como Código
├── mininet/            # Topologías de prueba
├── haproxy/            # Configuración del balanceador
├── scripts/            # Automatización y utilidades
├── docs/               # Documentación adicional
└── README.md
```

*(La estructura puede variar según la organización final del repositorio.)*

---

# Requisitos

* Linux
* Python 3
* Ryu
* Mininet
* Open vSwitch
* Terraform
* HAProxy

---

# Estado del proyecto

Este proyecto constituye una **prueba de concepto desarrollada con fines académicos** para validar la integración entre tecnologías SDN e IaC en un escenario de balanceo de carga automatizado.

La implementación verifica el correcto funcionamiento del mecanismo de autoescalado, aunque no incluye una evaluación comparativa de rendimiento frente a soluciones tradicionales ni está orientada a entornos productivos.

---

# Trabajo académico asociado

Este repositorio acompaña el Trabajo Final de Especialización titulado:

**"Infraestructura Definida por Software para el Balanceo de Carga Automatizado mediante la Integración de SDN e Infraestructura como Código"**

---

# Licencia

Este proyecto se distribuye únicamente con fines académicos y de investigación.

Consulte el archivo `LICENSE` para obtener información sobre los términos de uso.
