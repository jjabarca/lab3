# Laboratorio 3: Mi despliegue CI/CD en Kubernetes

Proyecto de Juan Abarca: aplicación NestJS con imágenes publicadas mediante Jenkins en Docker Hub y GitHub Container Registry (GHCR), y despliegue en un cluster local MicroK8s.

## Configuración

La aplicación se despliega en `ns-juan-abarca`, con dos réplicas del Deployment `app-juan-abarca` y acceso mediante el Service `svc-juan-abarca`. Utiliza la imagen `jjabarca/repo-lab3:juan-abarca`.

El ConfigMap `config-juan-abarca` proporciona `AMBIENTE` y el Secret `secret-juan-abarca` proporciona `API_KEY`. El endpoint `/lab` devuelve ambas variables como JSON.

## Archivos principales

- `Dockerfile` y `.dockerignore`: construcción de la imagen y exclusiones del contexto.
- `entrega.yaml`: Namespace, Deployment, Service, ConfigMap y Secret.
- `agent.yaml`: configuración del agente Kubernetes de Jenkins.
- `Jenkinsfile.juan-abarca`: pipeline con stages `install`, `test`, `build`, `push` y `deploy`.
- `src/` y `test/`: código fuente y pruebas.

## Instrucciones generales

1. Disponer de MicroK8s operativo y Jenkins con los plugins Kubernetes y Kubernetes CLI, conectado al cluster y al repositorio Git.
2. Preparar los Secrets `regcred-dh` y `regcred-gh` en el namespace de los agentes Jenkins, y `regcred-dh` en `ns-juan-abarca` para la descarga de la imagen.
3. Registrar el kubeconfig en Jenkins con el ID de credencial `kubernetes-config-juan-abarca`.
4. Publicar la imagen inicial y aplicar `entrega.yaml` para crear los recursos de la aplicación.
5. Configurar un job Multibranch Pipeline con `Jenkinsfile.juan-abarca` como ruta del script y ejecutarlo en la rama `main` o `test`.
6. Verificar las dos réplicas disponibles y consultar `/lab` mediante un port-forward del Service al puerto local `8080`.

El pipeline instala dependencias, ejecuta lint y pruebas unitarias, construye con BuildKit y publica en ambos registries. Docker Hub recibe los tags `juan-abarca` y `3.0.0`; GHCR recibe `latest` y el número de build de Jenkins.

El despliegue inicial es manual. Como el pipeline reutiliza el tag `juan-abarca`, la renovación de los pods después de publicar una nueva imagen todavía requiere intervención manual.

## Evidencias y entrega

Adjuntar en `evidencias/` las capturas o salidas del cluster, nodos, pods, Deployment, Service, logs, variables de entorno, ConfigMap y Secret. Incluir también la prueba de port-forward y consulta a `/lab`, la publicación en ambos registries, el pipeline exitoso y su log completo.

Comprimir el proyecto con sus archivos de configuración, código fuente, README y evidencias. Excluir dependencias instaladas, `.git`, kubeconfigs y credenciales de los registries.
