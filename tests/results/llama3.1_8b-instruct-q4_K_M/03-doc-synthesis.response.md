**Decision: Gestion de Certificados Corporativos en Contenedores Docker**
===========================================================

### Contexto
-----------------

* Entorno: WSL2 + Docker, firewall corporativo Fortinet con MITM TLS.

### Sintoma
--------------

Al intentar realizar `ollama pull`, `npm install` y `pip install` dentro de contenedores se produce el siguiente error:
```
x509: certificate signed by unknown authority
```

### Causa
---------

La causa del problema es que el contenedor trae el bundle CA de su imagen base (Debian/Ubuntu/Alpine), sin incluir el CA Fortinet del host.

### Solución
-------------

#### Fix Debian/Ubuntu
----------------------

* Montar `/etc/ssl/certs/ca-certificates.crt:/etc/ssl/certs/ca-certificates.crt:ro` en el contenedor.

#### Fix Alpine
---------------

* El path destino es `/etc/ssl/cert.pem` (Alpine no utiliza el bundle Debian).

#### Fix Go Binarios
-------------------

* Pasar `SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt` como variable de entorno.

### Aplicación
--------------

La solución se ha aplicado en `~/Workspace/llamalocal/compose/docker-compose.yml` (Ollama, 2026-05-11) y resolvió el problema del pull de modelos.

**Nota:** No aplica a `docker pull <imagen>` ya que el daemon utiliza los CAs del host.

### Anti-patron
----------------

* Evitar instalar CA dentro de cada Dockerfile (no reproducible entre equipos con CAs distintos).

### Verificación
-----------------

* Realizar la siguiente prueba: `docker exec <container> curl -fsS https://registry.ollama.ai/` debe devolver un resultado diferente a x509.

## Resumen
----------

Para resolver el problema de certificados en contenedores Docker, es necesario incluir el CA Fortinet del host en el bundle CA del contenedor. Esto se puede lograr montando `/etc/ssl/certs/ca-certificates.crt:/etc/ssl/certs/ca-certificates.crt:ro` en el contenedor para Debian/Ubuntu o utilizando `/etc/ssl/cert.pem` para Alpine. Además, es importante evitar instalar CA dentro de cada Dockerfile y utilizar variables de entorno como `SSL_CERT_FILE` para Go binarios que no utilicen SSL_CERT_FILE estandar.
