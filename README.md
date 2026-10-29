# HopProof

Network Automation & Operations Lab

*Verify the route. Confirm the signal.*

HopProof is a local networking lab for checking whether messages can travel from a remote site to a central receiver. It compares the routes you intended to configure with the routes a router actually has, then checks whether new messages arrive.

This public repository shares the project introduction and environment preparation files. Application source remains private. A downloadable edition is planned to be free to use, with its usage terms published alongside the release.

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

The private development build supports lab startup and shutdown, initial route configuration, diagnosis, and read-only monitoring. Operator-triggered repair and a public demo interface are planned. The experiment uses synthetic traffic on a local virtual network.

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

Use the environment files to prepare prerequisites. They do not include or install HopProof, so the `labctl` commands described below are unavailable from this checkout. An application download has not been published yet. The private application is not being released under an open-source license.

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

Keep runtime state and SSH keys on the Linux filesystem, where their permissions can be enforced. Keep an interactive WSL shell open while running the future lab; ending the distribution stops its containers. Check the reserved subnets for conflicts before deploying an application release.

### Application workflow once access is available

The current development build uses the `labctl` CLI, a command-line interface operated from a terminal:

1. `validate` checks the intended configuration without contacting devices.
2. `doctor` checks the controller environment, permissions and subnet conflicts.
3. `render` prepares the instance files; `up` starts the lab without adding managed static routes.
4. `configure` adds the initial routes, confirms new matching ACKs, then saves and reads back the configuration.
5. `diagnose` writes separate configuration, network and application results. `monitor` repeats read-only checks; Ctrl+C leaves the lab running.
6. `down` removes that instance's containers and network while preserving reports.

These commands describe the implemented private build. Package installation and download instructions will be added with its release.

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
| pytest | Unit and opt-in local network checks in the private development workspace | 9.2.0 |

The controller runs on Linux. Windows hosts it through WSL2. This setup uses a terminal interface and local containers, with no cloud account required.

## Acknowledgements

Containerlab's native FRR integration and FRRouting's lab images provide the virtual-router foundation. Thanks to the maintainers of these projects and the tools used to build and check the lab:

[Containerlab](https://containerlab.dev/), [FRRouting](https://frrouting.org/), [Docker](https://docs.docker.com/engine/), [Ansible](https://docs.ansible.com/), [Python](https://www.python.org/), [PyYAML](https://pyyaml.org/), [Jinja](https://jinja.palletsprojects.com/), [jsonschema](https://python-jsonschema.readthedocs.io/), and [pytest](https://docs.pytest.org/).

Third-party tools retain their own licenses.
