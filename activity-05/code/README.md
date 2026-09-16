# Activity 5 — DevOps and Infrastructure as Code

Files:

| file | what it is |
|---|---|
| `main.tf` | the whole configuration: network, three images, three containers, outputs |
| `.terraform.lock.hcl` | provider lock file (`kreuzwerker/docker` v3.9.0) — commit it |
| `activity5-CEDT_linux_amd64` | the grader (re-download from the release if missing) |

`main.tf` creates seven resources: the `todo-net` bridge network, the
`natawut/todo-service:release-3`, `redis:7-alpine` and `nginx:alpine` images, and
the `todo-service`, `redis` and `notification-service` containers. Only
`todo-service` is published to the host (`8000:8000`); the other two are reachable
from it by container name over `todo-net`, which is what `REDIS_HOST=redis` and
`NOTIFICATION_HOST=notification-service` rely on.

`.terraform/` and `terraform.tfstate` are git-ignored (see the repo `.gitignore`);
the lock file is not.

## Prerequisites (one time)

`terraform` is installed in `~/.local/bin`. If missing:

```bash
curl -fSL -o /tmp/terraform.zip \
  "https://releases.hashicorp.com/terraform/1.13.3/terraform_1.13.3_linux_amd64.zip"
unzip -o /tmp/terraform.zip -d ~/.local/bin
```

The Docker daemon must be running (`sudo service docker start`).

## Bring everything up

```bash
cd activity-05/code

# 1. download the provider plugin into .terraform/ (once per clone)
terraform init                                   # <-- transcript (Problem 2, step 1)

# 2. see what will be created — 7 to add, 0 to change, 0 to destroy
terraform plan                                   # <-- transcript (Problem 2, step 2)

# 3. create the network, pull the images, start the containers
terraform apply -auto-approve                    # <-- transcript (Problem 2, step 3)

# 4. verify
terraform output
docker ps
curl -w '\n' -X POST \
  -d '{"title":"todo-1","detail":"the first todo","duedate":"2022-10-24 11:00:00","tags":[],"completed":false}' \
  http://localhost:8000                          # -> {"id":0}
curl -w '\n' http://localhost:8000               # <-- transcript (Problem 2, step 4)

# 5. grader — press Enter at the path prompt (defaults to main.tf), then your ID + name
./activity5-CEDT_linux_amd64                     # <-- screenshot (Problem 3)
```

## Notes

- **The container must be named `todo-service`.** The grader checks containers by
  name (`todo-service` and `redis`); with the container named `todo` it reports
  `container todo-service does not exist` and fails the whole run.
- **Why there is a third container.** todo 3.0 (`release-3`) POSTs a notification to
  `NOTIFICATION_HOST:NOTIFICATION_PORT` (default `localhost:9000`) on every created
  todo. It ignores the reply, but a *refused connection* raises `ConnectionError`
  out of the request handler, so with only todo + redis every `POST /` returns 500
  and the grader's POST check fails. `notification-service` (plain `nginx:alpine`)
  is there to answer that call — it returns 405, todo discards it, the create
  succeeds. Point `var.notification_image` at the real notification service and
  nothing else in `main.tf` changes.
- **The grader needs the `.tf` path**, not just running containers: it checks that
  terraform is installed, that the file exists, that the directory is initialized
  (`.terraform/`) and that `terraform plan` succeeds, then POSTs and GETs against
  `http://localhost:8000`.
- **`keep_locally = true`** on the `docker_image` resources means `terraform destroy`
  removes the containers and network but leaves the pulled images in the local
  cache, so a re-apply doesn't re-download them.
- The grader loops forever on `Invalid StudentID` if it gets EOF on stdin — always run
  it in a real terminal, never piped or backgrounded.

## Tear down

```bash
terraform destroy -auto-approve
```
