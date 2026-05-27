# Decision: Gestión de CA corporativo en contenedores Docker

## Contexto

En un entorno de desarrollo con WSL2 + Docker, se enfrenta un problema de certificados SSL al ejecutar comandos como `ollama pull`, `npm install` o `pip install` dentro de contenedores. El error reportado es:

```
x509: certificate signed by unknown authority
```

Este problema ocurre porque el firewall corporativo Fortinet utiliza un certificado intermedio (MITM TLS) que no es reconocido por los contenedores, los cuales solo poseen los certificados CA del sistema base de la imagen (Debian, Ubuntu o Alpine).

El host WSL ya tiene instalado el certificado CA de Fortinet en:

```
/usr/local/share/ca-certificates/fortinet-ca.crt
```

Y este certificado está incluido en el bundle de certificados del sistema:

```
/etc/ssl/certs/ca-certificates.crt
```

## Decisión

La solución consiste en montar el bundle de certificados del host dentro del contenedor, de forma que los procesos dentro del contenedor puedan validar los certificados TLS usando el CA corporativo.

- Para imágenes basadas en **Debian/Ubuntu**, se debe montar:
  ```
  /etc/ssl/certs/ca-certificates.crt:/etc/ssl/certs/ca-certificates.crt:ro
  ```

- Para imágenes basadas en **Alpine**, se debe montar:
  ```
  /etc/ssl/certs/ca-certificates.crt:/etc/ssl/cert.pem:ro
  ```

Además, para binarios Go que no respetan la variable de entorno `SSL_CERT_FILE`, se debe pasar explícitamente:

```
SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
```

## Cómo aplicar

### 1. Montar certificados en `docker-compose.yml`

En el archivo `~/Workspace/llmlocal/compose/docker-compose.yml`, se debe añadir el volumen de certificados a los servicios que requieren acceso a Internet:

```yaml
services:
  ollama:
    image: ollama/ollama
    volumes:
      - /etc/ssl/certs/ca-certificates.crt:/etc/ssl/certs/ca-certificates.crt:ro
    environment:
      - SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
```

### 2. Para Alpine

Si se usa Alpine, el destino del certificado es diferente:

```yaml
volumes:
  - /etc/ssl/certs/ca-certificates.crt:/etc/ssl/cert.pem:ro
```

### 3. Verificación

Para verificar que el fix funciona, ejecutar dentro del contenedor:

```bash
docker exec <container> curl -fsS https://registry.ollama.ai/
```

Este comando debe devolver una respuesta válida, sin errores de certificado.

## Referencias

- [Docker Compose Volumes](https://docs.docker.com/compose/compose-file/compose-file-v3/#volumes)
- [Alpine Linux Certificates](https://wiki.alpinelinux.org/wiki/Working_with_certificates)
- [Go SSL Certificates](https://pkg.go.dev/crypto/x509#hdr-System_certificates)

## Resumen

- Monta el bundle de certificados del host en los contenedores para resolver errores de certificado.
- Asegúrate de usar el path correcto según la imagen base (Debian/Ubuntu vs Alpine).
- Verifica que los comandos como `curl` funcionen correctamente después del fix.
