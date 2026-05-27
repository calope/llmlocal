# Gestion de CA corporativo en contenedores Docker

## Contexto
El entorno en el que se presenta este problema es WSL2 + Docker, con un firewall corporativo Fortinet que utiliza MITM TLS. El síntoma observado es que las operaciones `ollama pull`, npm install y pip install dentro de los containers fallan con el mensaje de error "x509: certificate signed by unknown authority".

## Decision
Para solucionar este problema, se ha decidido gestionar adecuadamente los certificados de autoridad de certificación (CA) en los contenedores Docker que se ejecutan en el entorno corporativo.

## Como aplicar

### Diagnóstico del problema
El problema se debe a que los containers traen el bundle CA de su imagen base (Debian/Ubuntu/Alpine), sin incluir el CA Fortinet del host. Aunque el host WSL ya tiene instalado `/usr/local/share/ca-certificates/fortinet-ca.crt` y en `/etc/ssl/certs/ca-certificates.crt`, esta información no se está propagando adecuadamente a los containers.

### Solución para Debian/Ubuntu
Para solucionar este problema en contenedores basados en Debian o Ubuntu, se debe montar el archivo CA del host en el container utilizando el siguiente comando:
```bash
mount /etc/ssl/certs/ca-certificates.crt:/etc/ssl/certs/ca-certificates.crt:ro
```
### Solución para Alpine
En el caso de contenedores basados en Alpine, el path destino es `/etc/ssl/cert.pem`. Por lo tanto, se debe montar el archivo CA del host en este path utilizando el siguiente comando:
```bash
mount /etc/ssl/certs/ca-certificates.crt:/etc/ssl/cert.pem:ro
```
### Solución para Go binaries que no usen SSL\_CERT\_FILE estandar
Algunos binarios de Go no utilizan la variable de entorno `SSL_CERT_FILE` estándar. Para solucionar este problema, se debe pasar la ruta del archivo CA como una variable de entorno en el contenedor utilizando el siguiente comando:
```bash
env SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
```
### Verificación
Para verificar que la solución ha sido aplicada correctamente, se puede ejecutar el siguiente comando dentro del container:
```bash
docker exec <container> curl -fsS https://registry.ollama.ai/
```
Si todo está funcionando correctamente, este comando debería devolver un resultado diferente a "x509".

## Referencias

* TODO: proporcionar referencias específicas si están disponibles.

## Resumen
En resumen, se ha decidido gestionar adecuadamente los certificados de autoridad de certificación en los contenedores Docker para solucionar el problema de fallos en operaciones como `ollama pull`, npm install y pip install dentro de los containers. Se han proporcionado soluciones específicas para Debian/Ubuntu, Alpine y Go binaries que no usen la variable de entorno `SSL_CERT_FILE` estándar. La verificación se puede realizar ejecutando el comando `docker exec <container> curl -fsS https://registry.ollama.ai/`.
