# Decision: Gestión de CA corporativo en contenedores Docker

## Contexto

En un entorno empresarial con firewall corporativo Fortinet que utiliza MITM TLS, se han observado problemas con la ejecución de comandos como `ollama pull`, `npm install` y `pip install` dentro de contenedores Docker. Estos comandos fallan debido a un error de certificado "x509: certificate signed by unknown authority". La causa radica en que el contenedor trae su propio bundle CA de imagen base (Debian/Ubuntu/Alpine), sin incluir el CA Fortinet del host.

## Decision

La solución consiste en asegurar que los contenedores Docker utilicen los certificados CA del host, evitando así problemas de autenticación SSL/TLS. Esto se logra montando el archivo de certificado CA del host dentro del contenedor o configurando las variables de entorno correspondientes.

## Como Aplicar

### Debian/Ubuntu

Para sistemas basados en Debian/Ubuntu, es necesario montar el archivo de certificado CA del host dentro del contenedor. Esto se puede hacer mediante la siguiente línea en el `docker-compose.yml`:

```yaml
volumes:
  - /etc/ssl/certs/ca-certificates.crt:/etc/ssl/certs/ca-certificates.crt:ro
```

### Alpine

Para sistemas basados en Alpine, el archivo de certificado CA del host debe montarse en la siguiente ruta dentro del contenedor:

```yaml
volumes:
  - /etc/ssl/certs/ca-certificates.crt:/etc/ssl/cert.pem:ro
```

### Go binaries que no usen SSL_CERT_FILE estándar

Para ejecutar comandos Go que no utilizan la variable de entorno `SSL_CERT_FILE` estándar, se puede configurar la variable de entorno dentro del contenedor:

```yaml
environment:
  - SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
```

## Referencias

- [Docker documentation on volumes](https://docs.docker.com/compose/volumes/)
- [Go documentation on environment variables](https://golang.org/pkg/os/#Getenv)

## Resumen

Para resolver problemas de autenticación SSL/TLS en contenedores Docker cuando se utiliza un firewall corporativo con MITM TLS, es necesario montar el archivo de certificado CA del host dentro del contenedor o configurar las variables de entorno correspondientes. Esto asegura que los contenedores utilicen los certificados CA del host, evitando problemas de autenticación SSL/TLS.
