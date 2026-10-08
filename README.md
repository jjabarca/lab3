# Laboratorio 3: Mi despliegue CI/CD en Kubernetes

Proyecto de Juan Abarca: aplicación NestJS con imagen Docker propia, publicación en Docker Hub y GitHub Container Registry (GHCR), y despliegue en un cluster local MicroK8s mediante Jenkins y agentes Kubernetes.

Estas instrucciones describen la configuración actual. Las respuestas esperadas son ejemplos; las ejecuciones reales deben adjuntarse en la carpeta `evidencias/`.

## Recursos y archivos

| Recurso | Nombre o valor |
|---|---|
| Namespace | `ns-juan-abarca` |
| Deployment | `app-juan-abarca` |
| Service | `svc-juan-abarca` |
| ConfigMap | `config-juan-abarca` |
| Secret de aplicación | `secret-juan-abarca` |
| Imagen desplegada | `jjabarca/repo-lab3:juan-abarca` |
| Repositorio GHCR | `ghcr.io/jjabarca/repo-lab3` |
| APP_VERSION | `3.0.0` |
| Réplicas | `2` |
| Puertos | Aplicación: `3000`; Service: `80` |

- `Dockerfile`: construcción por etapas con Node.js 24 y pnpm 10.11.0.
- `.dockerignore`: exclusiones del contexto de construcción.
- `Jenkinsfile.juan-abarca`: pipeline CI/CD.
- `agent.yaml`: pod de herramientas utilizado por Jenkins.
- `entrega.yaml`: Namespace, ConfigMap, Secret, Deployment y Service.
- `src/` y `test/`: aplicación, pruebas unitarias y pruebas HTTP de integración.

## Requisitos previos

MicroK8s instalado y accesible para el usuario actual; Docker para la validación manual; Node.js 24 y pnpm 10.11.0 para ejecución local; cuentas con permisos sobre ambos registries; Jenkins con los plugins Kubernetes y Kubernetes CLI.

Jenkins debe acceder al repositorio Git y al API de MicroK8s. Los agentes deben poder conectarse al controlador Jenkins y a los registries. El cluster necesita recursos para las dos réplicas y el pod definido en `agent.yaml`.

Ejecutar los comandos desde la raíz del proyecto. MicroK8s incluye `microk8s kubectl`, como explica la [documentación de Canonical](https://canonical.com/microk8s/docs/working-with-kubectl).

## Ejecución local

```bash
npm install --global pnpm@10.11.0
pnpm install --frozen-lockfile
pnpm test
pnpm test:e2e
pnpm build
AMBIENTE=desarrollo API_KEY=api-key-local pnpm start:dev
```

En otra terminal:

```bash
curl http://localhost:3000/lab
```

`GET /` devuelve `Hello World!`. `GET /lab` devuelve `AMBIENTE` y `API_KEY` como JSON. Si alguna variable está ausente o vacía al iniciar, se asigna `SIN COMPLETAR` y se registra una advertencia.

El comando `pnpm lint` utilizado por Jenkins ejecuta ESLint con `--fix` y puede modificar archivos en el workspace del agente.

## Construcción y publicación manual

Autenticarse en ambos registries. Para GHCR, usar un token con permiso de publicación cuando Docker solicite la contraseña.

```bash
docker login --username jjabarca
docker login ghcr.io --username jjabarca
docker build -t jjabarca/repo-lab3:juan-abarca .
docker tag jjabarca/repo-lab3:juan-abarca jjabarca/repo-lab3:3.0.0
docker push jjabarca/repo-lab3:juan-abarca
docker push jjabarca/repo-lab3:3.0.0
docker tag jjabarca/repo-lab3:juan-abarca ghcr.io/jjabarca/repo-lab3:latest
docker push ghcr.io/jjabarca/repo-lab3:latest
```

Prueba manual del contenedor:

```bash
docker run --rm -p 3000:3000 \
  -e AMBIENTE=desarrollo -e API_KEY=api-key-local \
  jjabarca/repo-lab3:juan-abarca
```

Consultar `/lab` en el puerto 3000 desde otra terminal. Detener el contenedor con `Ctrl+C` al terminar.

## MicroK8s y credenciales de los registries

```bash
microk8s status --wait-ready
microk8s kubectl cluster-info
microk8s kubectl get nodes
microk8s kubectl create namespace ns-juan-abarca \
  --dry-run=client -o yaml | microk8s kubectl apply -f -
```

Los nodos deben aparecer como `Ready`. Verificar resolución DNS y conectividad hacia los registries.

El Deployment referencia `regcred-dh`. El agente Jenkins monta `regcred-dh` y `regcred-gh`. Son Secrets de tipo `kubernetes.io/dockerconfigjson`, distintos de `secret-juan-abarca`, que contiene `API_KEY`. Cada Secret debe existir en el namespace del pod que lo utiliza; consultar la [documentación de Kubernetes para registries privados](https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/).

Para crear archivos de autenticación separados, ejecutar en Bash:

```bash
LAB_DH_CONFIG=$(mktemp -d)
LAB_GH_CONFIG=$(mktemp -d)
docker --config "$LAB_DH_CONFIG" login --username jjabarca
docker --config "$LAB_GH_CONFIG" login ghcr.io --username jjabarca

microk8s kubectl create secret generic regcred-dh \
  -n ns-juan-abarca --type=kubernetes.io/dockerconfigjson \
  --from-file=.dockerconfigjson="$LAB_DH_CONFIG/config.json" \
  --dry-run=client -o yaml | microk8s kubectl apply -f -
```

Crear ambos Secrets también en el namespace configurado para los agentes en el Kubernetes Cloud de Jenkins. Sustituir el valor siguiente por el namespace real, que debe existir previamente:

```bash
LAB_AGENT_NAMESPACE=namespace-real-de-los-agentes

microk8s kubectl create secret generic regcred-dh \
  -n "$LAB_AGENT_NAMESPACE" --type=kubernetes.io/dockerconfigjson \
  --from-file=.dockerconfigjson="$LAB_DH_CONFIG/config.json" \
  --dry-run=client -o yaml | microk8s kubectl apply -f -

microk8s kubectl create secret generic regcred-gh \
  -n "$LAB_AGENT_NAMESPACE" --type=kubernetes.io/dockerconfigjson \
  --from-file=.dockerconfigjson="$LAB_GH_CONFIG/config.json" \
  --dry-run=client -o yaml | microk8s kubectl apply -f -
```

Los archivos de autenticación no forman parte de la entrega. Tras crear los Secrets:

```bash
rm -- "$LAB_DH_CONFIG/config.json" "$LAB_GH_CONFIG/config.json"
rmdir -- "$LAB_DH_CONFIG" "$LAB_GH_CONFIG"
```

## Despliegue inicial y consulta

Publicar la imagen y preparar las credenciales antes de aplicar los manifiestos:

```bash
microk8s kubectl apply -f entrega.yaml
microk8s kubectl rollout status deployment/app-juan-abarca \
  -n ns-juan-abarca --timeout=180s
microk8s kubectl get deployment app-juan-abarca -n ns-juan-abarca
microk8s kubectl get pods -n ns-juan-abarca
```

El Deployment debe mostrar dos réplicas disponibles. `AMBIENTE=produccion` se obtiene del ConfigMap; `API_KEY` se obtiene del Secret con un valor de demostración.

Mantener este comando activo en una terminal:

```bash
microk8s kubectl port-forward svc/svc-juan-abarca 8080:80 -n ns-juan-abarca
```

En otra terminal:

```bash
curl --fail --show-error http://localhost:8080/lab
```

Respuesta esperada con los valores actuales de `entrega.yaml`:

```json
{"AMBIENTE":"produccion","API_KEY":"api-key-juan-abarca"}
```

## Configuración y ejecución de Jenkins

1. Configurar un Kubernetes Cloud conectado a MicroK8s, con el namespace de agentes y permisos para crear sus pods.
2. Crear `regcred-dh` y `regcred-gh` en ese namespace.
3. Registrar un kubeconfig como credencial de tipo archivo secreto con ID `kubernetes-config-juan-abarca`. Debe permitir actualizar el Deployment en `ns-juan-abarca` y usar una dirección del API accesible desde el agente. MicroK8s permite exportarlo con `microk8s config`; no incluir ese archivo en la entrega.
4. Configurar un job Multibranch Pipeline para el repositorio, usando `Jenkinsfile.juan-abarca` como **Script Path**.
5. Aplicar previamente `entrega.yaml` y ejecutar el pipeline en la rama `main` o `test`.

La condición `when { branch ... }` de `deploy` corresponde a Multibranch Pipeline, según la [documentación de Jenkins](https://www.jenkins.io/doc/book/pipeline/syntax/). En otras ramas el despliegue queda omitido.

| Stage | Comportamiento actual |
|---|---|
| `install` | Habilita Corepack e instala dependencias con pnpm y lockfile congelado. |
| `test` | Ejecuta lint y pruebas unitarias. Las pruebas e2e se ejecutan manualmente. |
| `build` | Construye con BuildKit y exporta una caché local. |
| `push` | Publica Docker Hub con tags `juan-abarca` y `3.0.0`; GHCR con `latest` y el número de build Jenkins. |
| `deploy` | Asigna la imagen de Docker Hub con tag `juan-abarca` y espera el estado del rollout. |

`agent.yaml` define los contenedores `node-tool`, `buildkit`, `kubectl-tool` y `herramientas`. Las credenciales de registries se montan desde Secrets; el kubeconfig se obtiene mediante `withKubeConfig`.

### Alcance actual de la automatización

El stage `deploy` no aplica los manifiestos: requiere el despliegue inicial manual.

El tag desplegado es fijo. Si se publica otra imagen bajo `juan-abarca` y el Deployment ya tiene ese tag, `set image` puede dejar su plantilla sin cambios. Los pods existentes no se renuevan. Después de un push exitoso, renovar manualmente los pods:

```bash
microk8s kubectl rollout restart deployment/app-juan-abarca -n ns-juan-abarca
microk8s kubectl rollout status deployment/app-juan-abarca \
  -n ns-juan-abarca --timeout=180s
```

Esta renovación todavía no está automatizada en el Jenkinsfile. `imagePullPolicy: Always` se aplica cuando los contenedores arrancan.

## Evidencias obligatorias

Guardar las salidas reales de los comandos:

```bash
mkdir -p evidencias
microk8s kubectl cluster-info | tee evidencias/01-cluster-info.txt
microk8s kubectl get nodes | tee evidencias/02-nodes.txt
microk8s kubectl get pods -n ns-juan-abarca | tee evidencias/03-pods.txt
microk8s kubectl get deployment app-juan-abarca -n ns-juan-abarca | tee evidencias/04-deployment.txt
microk8s kubectl get svc svc-juan-abarca -n ns-juan-abarca | tee evidencias/05-service.txt
microk8s kubectl logs deployment/app-juan-abarca -n ns-juan-abarca | tee evidencias/06-logs.txt
microk8s kubectl exec deployment/app-juan-abarca -n ns-juan-abarca -- printenv | tee evidencias/07-printenv.txt
microk8s kubectl get configmap config-juan-abarca -n ns-juan-abarca | tee evidencias/08-configmap.txt
microk8s kubectl get secret secret-juan-abarca -n ns-juan-abarca | tee evidencias/09-secret.txt
```

Guardar también una captura o salida del `port-forward`. Mientras esté activo, ejecutar en otra terminal:

```bash
curl --fail --show-error http://localhost:8080/lab | tee evidencias/10-curl-lab.txt
```

Adjuntar capturas de los tags en ambos registries, del pipeline exitoso con los cinco stages ejecutados y el log completo de **Console Output** de Jenkins. Guardar este último como `evidencias/11-jenkins-console.txt`; `.gitignore` excluye archivos `.log`.

En todas las consultas, el namespace es `ns-juan-abarca`, incluido para Deployment, Service, ConfigMap y Secret.

## Diagnóstico

```bash
microk8s kubectl describe deployment app-juan-abarca -n ns-juan-abarca
microk8s kubectl describe pods -n ns-juan-abarca
microk8s kubectl logs deployment/app-juan-abarca -n ns-juan-abarca
microk8s kubectl get events -n ns-juan-abarca --sort-by=.metadata.creationTimestamp
```

Ante `ImagePullBackOff`, revisar el tag y `regcred-dh`. Si el agente Jenkins no inicia, revisar los eventos y Secrets de su namespace, las imágenes de herramientas y los recursos disponibles. Si `/lab` devuelve valores inesperados, revisar ConfigMap, Secret y las variables del pod.

## Carpeta comprimida para la entrega

Incluir código fuente, archivos de dependencias y configuración, `Dockerfile`, `.dockerignore`, `Jenkinsfile.juan-abarca`, `agent.yaml`, `entrega.yaml`, este README y `evidencias/` con el log Jenkins y las pruebas solicitadas. Excluir `node_modules/`, `.git/`, kubeconfigs y archivos de autenticación de registries.
