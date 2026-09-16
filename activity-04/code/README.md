# Activity 4 — Kubernetes with multiple containers

Files:

| file | what it is |
|---|---|
| `todo-deployment.yaml` | Deployment: one pod, two containers (`todo` + `redis`), `REDIS_HOST=localhost` |
| `todo-service.yaml` | ClusterIP Service in front of the todo container (port 8000) |
| `todo-ingress.yaml` | Ingress `todo-ingress` routing `http://localhost/` → `todo:8000` |
| `activity4-CEDT_linux_amd64` | the grader (git-ignored; re-download from the release if missing) |

## Prerequisites (one time)

`kubectl` and `k3d` are installed in `~/.local/bin`. If missing:

```bash
curl -fSL -o ~/.local/bin/kubectl "https://dl.k8s.io/release/v1.37.0/bin/linux/amd64/kubectl"
curl -fSL -o ~/.local/bin/k3d "https://github.com/k3d-io/k3d/releases/download/v5.9.0/k3d-linux-amd64"
chmod +x ~/.local/bin/kubectl ~/.local/bin/k3d
```

The Docker daemon must be running (`sudo service docker start`).

## Bring everything up

```bash
cd activity-04/code

# 1. cluster (host :80 -> ingress). Skip if `k3d cluster list` already shows "sds".
k3d cluster create sds --port "80:80@loadbalancer" --wait

# 2. the todo image isn't always pullable from inside the k3d node — preload it
docker pull natawut/todo-service:release-2.1
k3d image import natawut/todo-service:release-2.1 -c sds

# 3. Step 3 — test the cluster with the example nginx
kubectl apply -f https://k8s.io/examples/application/deployment.yaml
kubectl describe deployment nginx-deployment          # <-- screenshot (Problem 1)

# 4. Step 4 — todo + redis
kubectl apply -f todo-deployment.yaml -f todo-service.yaml
kubectl apply -f todo-ingress.yaml
kubectl rollout status deployment/todo

kubectl get deployment,svc,pods -l app=todo           # <-- screenshot (Problem 3)
kubectl get ingress
kubectl describe ingress todo-ingress

# 5. Step 4.e — exercise it through the ingress
curl -w '\n' -X POST \
  -d '{"title":"todo-1","detail":"the first todo","duedate":"2022-10-24 11:00:00","tags":[],"completed":false}' \
  http://localhost
curl -w '\n' http://localhost                          # <-- screenshot (Problem 3)

# 6. grader  (interactive: press Enter twice for the defaults, then type your ID + name)
./activity4-CEDT_linux_amd64                           # <-- screenshot (Problem 4)
```

## Notes

- **`REDIS_HOST=localhost`** because both containers are in the same pod and share a
  network namespace — this is the point of Step 4.a.
- The Service is **ClusterIP only**. The grader checks that `localhost:8000` (todo) and
  `localhost:6379` (redis) are *not* reachable from the host — only the ingress is.
- The Ingress **must** be named with "ingress" in it (`todo-ingress`). The grader runs
  `kubectl get ingress -n <ns>` and only passes when the word "ingress" appears in that
  output — the resource name in the `NAME` column is the only place it can.
- The grader loops forever on `Invalid StudentID` if it gets EOF on stdin — always run it
  in a real terminal, never piped or backgrounded.

## Tear down

```bash
k3d cluster delete sds
```
