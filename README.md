# HopProof

Network Automation & Operations Lab

*Verify the route. Confirm the signal.*

I built HopProof to make network faults reproducible in a small local lab. A site sends messages through two virtual routers to a receiver. I use it to remove a managed route, inspect the resulting fault, and verify that new messages arrive after a repair.

The Linux/WSL application is free to use through [Releases](https://github.com/DDDYT24/HopProof/releases), under the terms included with the download. I'm keeping the application source private. This repository contains the project introduction and environment setup files.

## Why I built it

I wanted a lab where I could follow a fault from the router settings through to the application. A router can accept a configuration command while messages still fail to arrive. The route may be missing from the forwarding table, or the problem may be a broken link or a stopped receiver.

With just four nodes, I can follow the whole traffic path. The site sends a small heartbeat through both routers, and the receiver replies. That gives me an application-level check to compare with what the routers report.

```text
Site sender  -->  Router 1  -->  Router 2  -->  Central receiver
```

These are the networking terms used in the lab:

| Term | Plain-language meaning |
| --- | --- |
| Route | An instruction telling a router where to send traffic for a destination. |
| Static route | A route set explicitly by an operator or script. |
| Next hop | The neighboring router that should receive the traffic next. |
| Configuration drift | A difference between the intended settings and the current settings. |
| RIB and FIB | The RIB is the routing software's record of routes. The FIB is the operating system's table used to forward packets. HopProof checks both. |
| Heartbeat and ACK | A heartbeat is a small periodic message. An ACK is the receiver's reply, matched to that message's session and sequence number. |

I keep configuration, forwarding and application health separate in the diagnosis. If an observation is missing or too old, the result stays unknown. A repair only counts as successful when new messages receive matching replies after the change.

The other fault scenarios stop the sender or receiver, or bring down the link between the routers. I limited repair to one missing managed route. If the receiver has stopped, adding a route shouldn't count as fixing it. Each scenario can be restored from the CLI. All traffic is synthetic.

## Who it is for

The lab should suit students learning static routing, Linux networking and Ansible, or engineers who want somewhere to practise configuration checks. If you develop applications, you can also use it to see what a network fault looks like at the sending and receiving ends.

You'll need some familiarity with a terminal. I've kept the lab to a fixed IPv4 topology for local practice. I haven't validated it on production networks.

## How to use it

### What is available today

```text
README.md
environment/
  baseline.yaml
  requirements-lock.txt
  setup-wsl.sh
```

I provide the environment files here and the application archive, along with its SHA-256 checksum, in [release v0.2.0](https://github.com/DDDYT24/HopProof/releases/tag/v0.2.0). Download both before starting. The archive includes the Linux x86_64 executable and its lab support files, usage terms and third-party notices. The application is free to use under those terms; it is not open source.

### Prepare the environment

I use a dedicated WSL2 Ubuntu 24.04 distribution on x86_64, with Docker Engine installed inside it. The setup helper expects the distribution to be named `NetOpsLab24`. On Windows, create it from PowerShell if that name is not already in use:

```powershell
wsl --install -d Ubuntu-24.04 --name NetOpsLab24 --no-launch --web-download
wsl -d NetOpsLab24 -u root
```

Download this repository as a ZIP from its GitHub page (the green download button, then **Download ZIP**) and extract it. In the WSL shell, change to the extracted directory. Replace `/mnt/c/path/to/HopProof` with its actual Linux path:

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
sha256sum --check HopProof-0.2.0-linux-x86_64-*.tar.gz.sha256
tar -xzf HopProof-0.2.0-linux-x86_64-*.tar.gz
cd HopProof-0.2.0-linux-x86_64-*/
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

Here is what the main `labctl` commands do:

1. `validate` checks the intended configuration without contacting devices.
2. `doctor` checks the controller environment, permissions and subnet conflicts.
3. `render` prepares the instance files; `up` starts the lab without adding managed static routes.
4. `configure` adds the initial routes, confirms new matching ACKs, then saves and reads back the configuration.
5. `diagnose` writes separate configuration, network and application results. `monitor` repeats read-only checks; Ctrl+C leaves the lab running.
6. `down` removes that instance's containers and network while preserving reports.

### Replay monitoring readings

Version 0.2.0 adds a second question to the lab. After the route is fixed, are fresh, valid readings reaching the receiver again? I replay short synthetic pipeline readings, such as flow and pressure, from the site to the receiver next to the heartbeat. The three sample inputs are in `examples/replay` inside the archive. Each reading slot is sent once, with no retries or catch-up after an outage.

```bash
./labctl --runtime-root "$HOME/netops-lab" --instance example replay start --dataset examples/replay/normal-30.csv
./labctl --runtime-root "$HOME/netops-lab" --instance example replay status
./labctl --runtime-root "$HOME/netops-lab" --instance example replay stop
./labctl --runtime-root "$HOME/netops-lab" --instance example replay report --replay-id <id printed by start>
```

The report command writes JSON, Markdown and a self-contained HTML page from the same data. The page shows when the network recovered and when the data recovered as two separate times. It also keeps every earlier gap visible after recovery. A reading only counts as missing if the receiver never recorded it. I keep a stopped producer, invalid readings and lost acknowledgements apart from network loss. Replay results never trigger a route repair; repair stays an operator decision.

Use `./labctl --help` for the command list and `USAGE.md` in the archive for exit codes and operating notes. The executable package was checked separately from source tests with real lab deployment, faults, repair and cleanup. Packaging does not prevent inspection or reverse engineering.

## Technology stack

I recorded the development environment in [environment/baseline.yaml](environment/baseline.yaml).

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

These versions describe the source development environment. I package the download with Python 3.12.15 for its controller and endpoint processes. Ansible and the router image remain separate, pinned dependencies.

I run the controller on Linux through WSL2 on Windows. The lab uses a terminal and local containers, so you do not need any hosted service account.

## Acknowledgements

I built the virtual network with Containerlab's native FRR integration and FRRouting's lab images. Thanks to their maintainers, and to the maintainers of the other tools used here:

[Containerlab](https://containerlab.dev/), [FRRouting](https://frrouting.org/), [Docker](https://docs.docker.com/engine/), [Ansible](https://docs.ansible.com/), [Python](https://www.python.org/), [PyYAML](https://pyyaml.org/), [Jinja](https://jinja.palletsprojects.com/), [jsonschema](https://python-jsonschema.readthedocs.io/), [pytest](https://docs.pytest.org/), and [PyInstaller](https://pyinstaller.org/).

Third-party tools retain their own licenses.
