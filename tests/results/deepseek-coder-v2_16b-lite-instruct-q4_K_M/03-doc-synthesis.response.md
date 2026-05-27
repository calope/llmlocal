 ## Gestión de Certificados de Autoridad en Contenedores Docker

### Contexto
En un entorno corporativo, la seguridad y la gestión de certificados son aspectos cruciales para el funcionamiento de los sistemas de contenedores Docker. Problemas relacionados con la autenticación y la verificación de certificados pueden surgir cuando las imágenes base no incluyen los certificados necesarios del entorno host.

### Decision
Implementar una solución para gestionar Certificados de Autoridad (CA) corporativos en contenedores Docker, asegurando que estos puedan acceder a recursos seguros como repositorios y servicios externos.

### Como aplicar
Para resolver el problema de certificados desconocidos en la autenticación de contenedores, se recomienda:

- **Debian/Ubuntu**: Montar el archivo `/etc/ssl/certs/ca-certificates.crt` desde el host al contenedor usando `mounts`.
  ```yaml
  services:
    ollama:
      image: ollama
      volumes:
        - /etc/ssl/certs/ca-certificates.crt:/etc/ssl/certs/ca-certificates.crt:ro
  ```

- **Alpine**: Utilizar el path `/etc/ssl/cert.pem` para los certificados, ya que Alpine no utiliza el bundle de Debian.
  ```dockerfile
  RUN apk add --no-cache ca-certificates && \
      update-ca-certificates
  ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
  ```

- **Go Binaries**: Si los binarios Go no usan la variable de entorno `SSL_CERT_FILE` estándar, asegurarse de pasarla explícitamente en el comando del contenedor.
  ```sh
  docker run -e SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt mi_imagen go_programa
  ```

### Referencias
- [Docker Documentation](https://docs.docker.com/)
- [Alpine Linux CA Certificates](https://wiki.alpinelinux.org/wiki/Setting_up_a_container#Use_an_existing_base_image)
- [Debian SSL Configuration](https://www.debian.org/doc/manuals/securing-debian-manual/index.en.html)

### Verificación
Para asegurar que la solución está aplicada correctamente, se puede verificar ejecutando:
```sh
docker exec <container_id> curl -fsS https://registry.ollama.ai/
```
El resultado debe indicar que el certificado fue verificado exitosamente.

## Resumen
Para garantizar la seguridad y funcionalidad de los contenedores Docker en un entorno corporativo, se recomienda montar los Certificados de Autoridad del host al contenedor para evitar problemas de autenticación basados en certificados. Esta práctica asegura que todos los contenedores puedan acceder a recursos seguros sin configuración adicional dentro de cada Dockerfile.
