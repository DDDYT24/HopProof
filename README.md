# HopProof

Network Automation & Operations Lab

*Verify the route. Confirm the signal.*

HopProof is a local networking lab for checking whether messages can travel from a remote site to a central receiver. It compares the routes you intended to configure with the routes a router actually has, then checks whether new messages arrive.

This repository contains the project introduction and environment preparation files. The Linux/WSL application is available in [Releases](https://github.com/DDDYT24/HopProof/releases). It is free to use under the terms included with the download. Application source remains private.

## Why HopProof exists

A router can accept a configuration command while communication still fails. A route may be missing from the forwarding table, a link may be down, or the receiving program may have stopped. Checking the settings alone cannot tell you which problem you have.

HopProof uses a small, repeatable experiment: a site sends a short message through two virtual routers to a receiver. You can inspect the route configuration, check the forwarding path, and compare the message sent with the receiver's reply.

```text
Site sender  -->  Router 1  -->  Router 2  -->  Central receiver
```

A few terms used throughout the project:

| Term | Plain-language meaning |
| --- | --- |
| Route | An instruction telling a router where to send traffic for a destination. |
| Static route | A route set explicitly by an operator or script. |
| Next hop | The neighboring router that should receive the traffic next. |
| Configuration drift | A difference between the intended settings and the current settings. |
| RIB and FIB | The RIB is the routing software's record of routes. The FIB is the operating system's table used to forward packets. HopProof checks both. |
| Heartbeat and ACK | A heartbeat is a small periodic message. An ACK is the receiver's reply, matched to that message's session and sequence number. |

The design keeps three questions separate: does the configuration match the intent, can the network carry traffic, and is the receiving application responding? Unknown or stale evidence stays unknown. A previous successful message does not prove that new messages are still arriving.

HopProof supports lab startup and shutdown, initial route configuration, diagnosis, read-only monitoring and operator-triggered repair of one missing managed route. Built-in scenarios let you remove that route, stop either endpoint program or bring down the middle link, then observe and restore the lab. The experiment uses synthetic traffic on a local virtual network.

## Who it is for

- Students learning static routing, Linux networking, and Ansible.
- Developers who want to see how a network fault affects an application.
- Engineers practicing configuration checks and service verification in an isolated environment.

Some familiarity with a terminal is useful. The lab uses a fixed IPv4 topology and is intended for local practice; it has not been validated for production networks.

## How to use it

### What is available today

```text
README.md
environment/
  baseline.yaml
  requirements-lock.txt
  setup-wsl.sh
```

Use these files to prepare the environment, then download the application archive and its SHA-256 checksum from [release v0.1.0](https://github.com/DDDYT24/HopProof/releases/tag/v0.1.0). The archive contains the Linux x86_64 executable, lab support files, usage terms and third-party notices. The application is distributed for free use; it is not released under an open-source license.

### Prepare the environment

The verified x86_64 controller environment is a dedicated WSL2 Ubuntu 24.04 distribution with Docker Engine installed inside it. The setup helper retains the internal distribution name `NetOpsLab24` to match the validated environment. On Windows, use PowerShell to create it if that name is not already in use:

```powershell
wsl --install -d Ubuntu-24.04 --name NetOpsLab24 --no-launch --web-download
wsl -d NetOpsLab24 -u root
```

Download this repository using GitHub's **Code > Download ZIP** option and extract it. In the WSL shell, change to the extracted directory. Replace `/mnt/c/path/to/HopProof` with its actual Linux path:

```bash
cd /mnt/c/path/to/HopProof
bash environment/setup-wsl.sh
```

Run the helper only in a new distribution dedicated to this lab. It installs Docker Engine, Containerlab and Python, creates the `netops` account with passwordless sudo, and writes that distribution's WSL settings. It does not reset or migrate other distributions. If you already have the project's prepared `NetOpsLab24` environment, skip this provisioning step.

Leave the root shell with `exit`, then open the lab account from PowerShell:

```powershell
wsl -d NetOpsLab24 -u netops
```

Return to the extracted repository directory in that shell and install the recorded Python dependencies:

```bash
/opt/netops-lab-venv/bin/python -m pip install -r environment/requirements-lock.txt
/opt/netops-lab-venv/bin/python -m pip check
python3.12 --version
docker version
containerlab version
/opt/netops-lab-venv/bin/ansible --version
```

A successful dependency check prints `No broken requirements found.` The lock file includes development tools as part of the recorded environment. It does not contain the HopProof application. `baseline.yaml` records tested versions, fixed base-image references, and the four subnets reserved for the lab. The helper installs Docker from its Ubuntu repository, so the installed Docker version may be newer than the recorded baseline.

Keep runtime state and SSH keys on the Linux filesystem, where their permissions can be enforced. Keep an interactive WSL shell open while running the lab; ending the distribution stops its containers. Check the reserved subnets for conflicts before deploying an application release.

### Download and run the application

In the `netops` WSL shell, put the release archive and its checksum in a new directory on the Linux filesystem. Verify and extract the archive:

```bash
sha256sum --check HopProof-0.1.0-linux-x86_64-*.tar.gz.sha256
tar -xzf HopProof-0.1.0-linux-x86_64-*.tar.gz
cd HopProof-0.1.0-linux-x86_64-*/
```

Pull the two images pinned in the supplied configuration:

```bash
/opt/netops-lab-venv/bin/python - <<'PY'
from pathlib import Path
import subprocess
import yaml
runtime = yaml.safe_load(Path("config/lab.yaml").read_text())["runtime"]
for name in ("router_image", "workload_base_image"):
    subprocess.run(["docker", "pull", runtime[name]], check=True)
PY
```

Run the commands from the extracted directory. `--runtime-root` keeps SSH keys on Linux storage, and `--instance` gives this experiment its own name:

```bash
./labctl --runtime-root "$HOME/netops-lab" --instance example validate
./labctl --runtime-root "$HOME/netops-lab" --instance example doctor
./labctl --runtime-root "$HOME/netops-lab" --instance example up
./labctl --runtime-root "$HOME/netops-lab" --instance example configure
./labctl --runtime-root "$HOME/netops-lab" --instance example diagnose
./labctl --runtime-root "$HOME/netops-lab" --instance example demo --scenario route-missing --action inject
./labctl --runtime-root "$HOME/netops-lab" --instance example repair
./labctl --runtime-root "$HOME/netops-lab" --instance example down
```

Each operation prints a report path under `artifacts`. Keep reports and runtime state private. If a change cannot be confirmed, inspect its report before retrying. Use the application's `down` command to clean up its own instance.

The `labctl` CLI is a command-line interface operated from a terminal:

1. `validate` checks the intended configuration without contacting devices.
2. `doctor` checks the controller environment, permissions and subnet conflicts.
3. `render` prepares the instance files; `up` starts the lab without adding managed static routes.
4. `configure` adds the initial routes, confirms new matching ACKs, then saves and reads back the configuration.
5. `diagnose` writes separate configuration, network and application results. `monitor` repeats read-only checks; Ctrl+C leaves the lab running.
6. `down` removes that instance's containers and network while preserving reports.

Use `./labctl --help` for the command list and `USAGE.md` in the archive for exit codes and operating notes. The executable package was checked separately from source tests with real lab deployment, faults, repair and cleanup. Packaging does not prevent inspection or reverse engineering.

## Technology stack

The verified development baseline is recorded in [environment/baseline.yaml](environment/baseline.yaml).

| Tool | Role | Verified version |
| --- | --- | --- |
| Python | Controller, heartbeat sender/receiver, and local process supervision | Controller 3.12.3; workload 3.12.16 |
| Containerlab | Creates the virtual nodes and the links between them | 0.80.0 |
| FRRouting (FRR) | Runs the two software routers | Native Containerlab image, 10.7.1 |
| Docker Engine | Runs the lab containers inside the dedicated WSL distribution | 29.9.2 |
| Ansible Core | Reads router state and applies only the intended static-route changes through SSH | 2.21.5 |
| PyYAML, Jinja2 and jsonschema | Configuration loading, template rendering and structural validation | Exact versions in the dependency lock |
| pytest | Unit and real network checks in the private development workspace and CI | 9.2.0 |
| PyInstaller | Builds the downloadable Linux executable | 6.22.3 |

The table records the source development baseline. The downloadable edition embeds Python 3.12.15 for its controller and endpoint processes; it still uses the pinned external Ansible and router dependencies.

The controller runs on Linux. Windows hosts it through WSL2. This setup uses a terminal interface and local containers, with no cloud account required.

## Acknowledgements

Containerlab's native FRR integration and FRRouting's lab images provide the virtual-router foundation. Thanks to the maintainers of these projects and the tools used to build and check the lab:

[Containerlab](https://containerlab.dev/), [FRRouting](https://frrouting.org/), [Docker](https://docs.docker.com/engine/), [Ansible](https://docs.ansible.com/), [Python](https://www.python.org/), [PyYAML](https://pyyaml.org/), [Jinja](https://jinja.palletsprojects.com/), [jsonschema](https://python-jsonschema.readthedocs.io/), [pytest](https://docs.pytest.org/), and [PyInstaller](https://pyinstaller.org/).

Third-party tools retain their own licenses.
