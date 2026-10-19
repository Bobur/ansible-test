# Section 22: Execution Environments and ansible-navigator

### In this section the following subjects will be covered:

1. What an Execution Environment (EE) is, and why Ansible Automation Platform (AAP) is built on it
1. Installing `ansible-navigator` and `ansible-builder`
1. Running Playbooks with `ansible-navigator`: without an EE, then in an EE
1. Project settings file `ansible-navigator.yml`
1. Inspecting an EE: images, collections, documentation, ad-hoc commands
1. Credentials and network for Playbooks that run in a container
1. Building your own EE with `ansible-builder`
1. Playbook artifacts and replay
1. From `ansible-navigator` to AAP: what maps to what

> [!IMPORTANT]
> This lesson runs on the **lab VM** (the host where you started `labenv/run.sh`), **not** in the Control Node
> container: Execution Environments are containers, and the lab VM already has Podman. Work as your normal user
> (rootless Podman), in the clone of the repo on the VM: `cd ~/ansible/lessons/22_Navigator`.

---
## Why Execution Environments

Until now the Control Node was a machine where we installed everything Ansible needs: `ansible-core`, collections
(`ansible-galaxy collection install`), Python libraries, ssh. This works, but every Control Node is a little bit
different, and "it works on my machine" is a real problem in a team.

An **Execution Environment** is a container image that contains everything to run a Playbook:

| In the EE image | Example |
|-----------------|---------|
| A base OS | UBI 9 (RHEL 9 userspace), Fedora, CentOS Stream |
| Python | 3.12 |
| `ansible-core` and `ansible-runner` | 2.18 |
| Collections | `community.general`, `ansible.posix`, `cisco.ios`, ... |
| Python libraries the collections need | `jmespath`, `pywinrm`, `kubernetes`, ... |
| System packages | `openssh-clients`, `git`, ... |

Your **project** (Playbooks, inventory, `ansible.cfg`, roles) is **not** in the image: it is mounted into the
container when the Playbook runs. The same image gives the same result on a laptop, in a CI pipeline and in AAP.

```
 ansible-playbook                         ansible-navigator with an EE
 ----------------                         ----------------------------
 Control Node                             lab VM
   ansible-core   (dnf / pip)               ansible-navigator --- podman run --+
   collections    (~/.ansible)                                                 |
   Python libs    (pip)                     project dir --- mounted ---+       v
   ssh ---------------> Managed Hosts                     +------------ EE container --------------+
                                                          | ansible-core, collections, Python libs |
                                                          | ansible-playbook  -- ssh --> Managed Hosts
                                                          +----------------------------------------+
```

**Why it matters for AAP:** the automation controller of AAP runs **every job in an EE**. You never log in to the
controller to `pip install` or `ansible-galaxy install` anything: what your Playbook needs on the control side has
to be in the EE image (collections can also come from the project, see the last section).
`ansible-navigator` gives you the same execution model on your own machine.

---
## The tools

| Tool | Purpose |
|------|---------|
| `ansible-navigator` | Runs Playbooks (in an EE or without), explores EEs, collections, docs, inventories, configuration. Text user interface (TUI) or plain stdout |
| `ansible-builder` | Builds EE images from a definition file `execution-environment.yml` |
| `ansible-runner` | The library both use to start Ansible and collect its events; AAP uses it as well |
| `podman` | Container engine that pulls and runs the EE images (`docker` also works) |

---
## Installation

`ansible-navigator` needs Python 3.10 or newer (older Pythons get older releases). Install it into a virtual
environment, not into the system Python. `ansible-builder` and `ansible-runner` come with it as dependencies.

```bash
python3 --version                        # 3.10+ ; on Fedora 42: 3.13

python3 -m venv ~/navigator
source ~/navigator/bin/activate
python -m pip install --upgrade pip
python -m pip install ansible-navigator

ansible-navigator --version
ansible-builder --version
podman --version
```

> [!NOTE]
> On **RHEL 9** the system Python is 3.9: install a newer one first (`sudo dnf install python3.12`) and create the
> venv with `python3.12 -m venv ~/navigator`. On **RHEL 8** `python3` is 3.6 with pip 9, far too old: use
> `sudo dnf install python39` and `python3.9 -m venv`, and upgrade pip in the venv **before** installing navigator.
> Error messages like `No matching distribution found for setuptools>=62.4.0` mean the Python or pip is too old.
>
> With a Red Hat AAP subscription `ansible-navigator` and `ansible-builder` are also available as RPMs from the
> AAP repository.

Every new terminal needs `source ~/navigator/bin/activate` again.

---
## Files of this lesson

#### ansible.cfg
```ini
[defaults]
inventory = ./host_inventory
remote_user = devops
interpreter_python = /usr/bin/python3
callback_result_format = yaml
# Lab only: the three Managed Hosts share 127.0.0.1 with different ports,
# and a fresh Execution Environment has an empty known_hosts on every run
host_key_checking = False

[privilege_escalation]
become_method = sudo
become_ask_pass = false
```

#### host_inventory
```ini
[myhosts]
host1 ansible_port=2021
host2 ansible_port=2022
host3 ansible_port=2023

[myhosts:vars]
ansible_host=127.0.0.1
```

On the lab VM the Managed Host containers are reached through the ssh ports `run.sh` publishes:
`127.0.0.1:2021` is host1, `2022` host2, `2023` host3 (see `labenv/ansible_node/run_containers.sh`).

#### ansible-navigator.yml
```yaml
---
ansible-navigator:
  execution-environment:
    enabled: true
    image: ghcr.io/ansible-community/community-ee-minimal:latest
    container-engine: podman
    pull:
      policy: missing          # always | missing | never | tag
    container-options:
      - "--net=host"           # the EE uses the network of the lab VM: 127.0.0.1:2021 is host1
  mode: stdout
  playbook-artifact:
    enable: true
    save-as: "{playbook_dir}/artifacts/{playbook_name}-artifact-{time_stamp}.json"
  logging:
    level: warning
    file: ./ansible-navigator.log
```

`ansible-navigator` looks for its settings in this order, the first one found wins:

1. the file in the `ANSIBLE_NAVIGATOR_CONFIG` environment variable
1. `ansible-navigator.yml` (or `.yaml`, `.json`) in the **current directory**: the project settings
1. `~/.ansible-navigator.yml` in your home directory

Command line options override the file. Check what is in effect with `ansible-navigator settings --effective`.

| Setting | Command line | Meaning |
|---------|--------------|---------|
| `execution-environment.enabled` | `--ee true\|false` | Run in an EE container, or with the `ansible-playbook` of the venv |
| `execution-environment.image` | `--eei <image>` | Which EE image to use |
| `execution-environment.pull.policy` | `--pp <policy>` | `always`, `missing`, `never`, or `tag` (the default: always pull a `latest` tag, other tags only if missing) |
| `mode` | `-m stdout\|interactive` | Plain output like `ansible-playbook`, or the TUI |
| `playbook-artifact.enable` | `--pae true\|false` | Save a JSON record of every run |

---
## Running Playbooks

### Without an EE

`--ee false` runs the `ansible-playbook` found in the venv, like before. Useful to start with, but it is **not**
what AAP does.

```bash
ansible-navigator run whereami.yml --ee false
```

### In an EE

Without `--ee false` the settings file applies: navigator pulls the image (first time only, with policy `missing`),
starts a container from it, mounts the project directory, and runs `ansible-playbook` **inside the container**.

```bash
ansible-navigator run whereami.yml
podman ps -a          # the EE container is removed after the run
podman images         # the image stays
```

#### whereami.yml
```yaml
---
- name: Where does the Playbook run?
  hosts: localhost
  connection: local
  gather_facts: true
  vars:
    # localhost uses the Python that runs ansible-playbook itself
    ansible_python_interpreter: "{{ ansible_playbook_python }}"

  tasks:
    - name: Show who and where localhost is
      ansible.builtin.debug:
        msg:
          - "Hostname:      {{ ansible_facts['hostname'] }}"
          - "OS:            {{ ansible_facts['distribution'] }} {{ ansible_facts['distribution_version'] }}"
          - "User:          {{ ansible_facts['user_id'] }}"
          - "Python:        {{ ansible_facts['python_version'] }}"
          - "ansible-core:  {{ ansible_version['full'] }}"
          - "In container:  {{ ansible_facts['env']['container'] | default('no') }}"
          - "Project dir:   {{ playbook_dir }}"

    - name: Leave a file behind on localhost
      ansible.builtin.copy:
        content: "Written by whereami.yml on {{ ansible_facts['hostname'] }}\n"
        dest: /tmp/whereami.txt
        mode: "0644"
```

> [!IMPORTANT]
> In an EE **`localhost` is the EE container**, not your machine, and the container is thrown away after the run.
> A file written to `localhost` is gone, a package installed on `localhost` is gone. The same is true in AAP:
> `localhost` in a job is the EE, not the controller server. Results that must survive belong on a Managed Host,
> in a Git repo, an artifact store, or in the job output.

### Passing options to ansible-playbook

Options navigator does not know are passed on to `ansible-playbook`:

```bash
ansible-navigator run ping.yml --limit host1
ansible-navigator run ping.yml --check -v
```

### The text user interface

```bash
ansible-navigator run ping.yml -m interactive
```

| Key | Action |
|-----|--------|
| `0` - `9` | Open the line with that number (Play, then task, then host result) |
| `:12` | Open line 12 (numbers above 9) |
| `Esc` | One level back (on the top level: quit) |
| `:help` | Help, all commands |
| `:q` | Quit |

`ansible-navigator -m interactive` without a subcommand shows a welcome page with all subcommands.

---
## Credentials and network in the EE

The EE is a separate container, so two things have to reach it from the lab VM:

**Network.** The `--net=host` container option lets the EE use the network of the lab VM, so `127.0.0.1:2021`
is host1 inside the EE as well. Without it the EE has its own network namespace and `127.0.0.1` is the container.

**The ssh key.** Your key is not in the image (and must never be). The simplest way is the **ssh-agent**:
navigator hands the agent socket to the EE, and also mounts `~/.ssh`. Prepare a key for your user on the lab VM
once, and copy it to the Managed Hosts (password of `devops` in the lab: `devops`):

```bash
ssh-keygen -t ed25519 -N '' -f ~/.ssh/id_ed25519
for port in 2021 2022 2023; do ssh-copy-id -p $port devops@127.0.0.1; done

eval $(ssh-agent)        # once per terminal
ssh-add                  # loads ~/.ssh/id_ed25519
ssh-add -l
```

#### ping.yml
```yaml
---
- name: Reach the Managed Hosts
  hosts: myhosts
  gather_facts: false

  tasks:
    - name: Ping the host (ssh login and Python check)
      ansible.builtin.ping:

    - name: Ask the host for its name
      ansible.builtin.command: hostname
      register: result_hostname
      changed_when: false

    - name: Show which host answered
      ansible.builtin.debug:
        msg: "{{ inventory_hostname }} (port {{ ansible_port }}) says: {{ result_hostname.stdout }}"
```

```bash
ansible-navigator run ping.yml
```

If the EE image has no ssh client, every host fails with an ssh error: then this image is not good for remote
hosts, and our own EE below (with `openssh-clients`) is the fix.

> [!NOTE]
> This is exactly how AAP handles keys: you store the private key once in a **Machine credential**, and at job
> start the controller loads it into an ssh-agent for the EE. The key is in neither the image nor the Git repo.

---
## Inspecting an EE

Before you use an EE, find out what is in it:

```bash
ansible-navigator images -m interactive          # images, then: OS, ansible version, Python packages, collections
ansible-navigator collections -m interactive     # collections in the EE of the settings file
ansible-navigator config -m interactive          # ansible-config: settings and where they come from
ansible-navigator doc ansible.builtin.copy       # ansible-doc, from inside the EE
ansible-navigator inventory -i host_inventory --graph   # ansible-inventory, from inside the EE
ansible-navigator exec "ansible --version"       # any command inside the EE
ansible-navigator exec "cat /etc/os-release"
```

In the TUI open a line with its number and go back with `Esc`. With `-m stdout` (our default) `images` and
`collections` print the same information as YAML.

---
## Building your own EE

`report.yml` uses the `community.general.json_query` filter. Filters run on the **control side**, that is in the
EE, so the EE needs the collection **and** the Python library `jmespath` that the filter uses.

#### report.yml
```yaml
---
- name: Collect facts from the Managed Hosts
  hosts: myhosts
  gather_facts: true

  tasks:
    - name: Show the OS and size of each host
      ansible.builtin.debug:
        msg: >-
          {{ ansible_facts['distribution'] }} {{ ansible_facts['distribution_version'] }},
          {{ ansible_facts['processor_vcpus'] }} vCPU, {{ ansible_facts['memtotal_mb'] }} MB

- name: Summarize on the controller
  hosts: localhost
  connection: local
  gather_facts: false
  vars:
    ansible_python_interpreter: "{{ ansible_playbook_python }}"

  tasks:
    - name: Build one record per host
      ansible.builtin.set_fact:
        host_records: "{{ host_records | default([]) + [record] }}"
      loop: "{{ groups['myhosts'] }}"
      vars:
        record:
          name: "{{ item }}"
          os: "{{ hostvars[item]['ansible_facts']['distribution'] }}"
          memory_mb: "{{ hostvars[item]['ansible_facts']['memtotal_mb'] }}"

    - name: Names of the Fedora hosts (JMESPath query)
      ansible.builtin.debug:
        msg: "{{ host_records | community.general.json_query(\"[?os=='Fedora'].name\") }}"

    - name: Save the report on localhost
      ansible.builtin.copy:
        content: "{{ host_records | to_nice_yaml }}"
        dest: /tmp/lab-report.yml
        mode: "0644"
```

The minimal community EE has only `ansible-core`, so this Playbook fails there. We build an EE that has
everything it needs. The definition is in the [ee](ee/) directory:

#### ee/execution-environment.yml
```yaml
---
version: 3

images:
  base_image:
    # UBI 9: the freely redistributable RHEL 9 userspace. The Red Hat supported EEs
    # of Ansible Automation Platform are built on it as well.
    name: registry.access.redhat.com/ubi9/ubi:latest

dependencies:
  python_interpreter:
    package_system: python3.12
    python_path: /usr/bin/python3.12
  ansible_core:
    package_pip: ansible-core==2.18.*    # the same ansible-core as the lab Control Node
  ansible_runner:
    package_pip: ansible-runner
  galaxy: requirements.yml               # collections
  python: requirements.txt               # Python libraries
  system: bindep.txt                     # RPM packages

options:
  package_manager_path: /usr/bin/dnf
```

#### ee/requirements.yml
```yaml
---
collections:
  - name: community.general
  - name: ansible.posix
```

#### ee/requirements.txt
```
jmespath
```

#### ee/bindep.txt
```
openssh-clients [platform:rpm]
```

| Key | Meaning |
|-----|---------|
| `version: 3` | Schema of ansible-builder 3.x |
| `images.base_image.name` | The image to start from. Must be RPM based (dnf / microdnf) |
| `dependencies.python_interpreter` | Python package to install and the path of its interpreter |
| `dependencies.ansible_core`, `ansible_runner` | What pip installs, version pins allowed |
| `dependencies.galaxy` | Collections: a `requirements.yml`, the same format as for `ansible-galaxy install -r` |
| `dependencies.python` | Python libraries in pip format. Collections can declare their own, they are added automatically |
| `dependencies.system` | RPM packages in [bindep](https://docs.opendev.org/opendev/bindep/latest/readme.html) format |
| `additional_build_steps` | Extra Containerfile lines (e.g. a company CA certificate, proxy settings) |

### Build

```bash
cd ee
ansible-builder build -t lab-ee:1.0 -v 3
cd ..
podman images | grep lab-ee                 # localhost/lab-ee   1.0
```

`ansible-builder` writes a `context/` directory with a generated `Containerfile`, and runs `podman build` on it.
Read `context/Containerfile`: there is nothing magic in an EE, it is an ordinary multi-stage container build.

> [!NOTE]
> The build pulls the base image from `registry.access.redhat.com`, Python packages from PyPI and collections from
> `galaxy.ansible.com`. In a company network these must be reachable through the proxy, or replaced by internal
> mirrors (an internal registry, a PyPI mirror, Private Automation Hub).

### Run with your EE

```bash
ansible-navigator run report.yml --eei localhost/lab-ee:1.0 --pp never
```

`--pp never`: a local image only exists on this machine, there is nothing to pull.

---
## Playbook artifacts and replay

Every run is saved as a JSON file in `artifacts/` (see `save-as` in the settings): all Plays, tasks, host results,
the stdout, the EE image and the settings used. A failed run can be opened later, or by a colleague, in the TUI:

```bash
ls artifacts/
ansible-navigator replay artifacts/report-artifact-<timestamp>.json
```

This is the local equivalent of the **job output** that AAP keeps for every job.

---
## From ansible-navigator to AAP

| On your machine with ansible-navigator | In Ansible Automation Platform |
|----------------------------------------|--------------------------------|
| EE image in `ansible-navigator.yml` / `--eei` | **Execution Environment** resource (image + pull policy), set on the job template, the project, or the organization |
| `ansible-builder build` | The same tool. The image is pushed to **Private Automation Hub** (or another registry) and AAP pulls it from there |
| `pull.policy: always / missing / never` | The same three pull options on the Execution Environment resource |
| Project directory mounted into the EE | **Project**: synced from Git into the job's EE |
| `collections/requirements.yml` in the project | Installed by the project sync (if the EE doesn't already have them) |
| `host_inventory`, `ansible-navigator inventory` | **Inventory** (static or synced from sources, e.g. a CMDB or a cloud) |
| ssh-agent, `~/.ssh` | **Machine credential**, injected at job start |
| `--vault-password-file` | **Vault credential** |
| `ansible-navigator run report.yml --limit host1` | **Job template** (Playbook + inventory + credentials + EE + options), launched by click, API, or schedule |
| `artifacts/*.json`, `replay` | **Job output** and job details, kept by the controller |
| `localhost` = the EE container | Same in AAP: `localhost` is the EE, not the controller |
| `community-ee-minimal`, `lab-ee` | Red Hat supported EEs from `registry.redhat.io`: `ee-minimal-rhel9` (only ansible-core), `ee-supported-rhel9` (with the Red Hat certified collections) |

Habits from this lesson that make the move to AAP easy:

1. Write Playbooks that run in an EE, not only on your own Control Node.
1. Keep the dependencies of a project in files (`requirements.yml`, `requirements.txt`, `bindep.txt`), not in your
   shell history.
1. Pin versions: base image, `ansible-core`, collections.
1. Never put secrets in a Playbook, an EE image, or a Git repo: they come in at run time.
1. Don't rely on anything on `localhost` surviving the run.

The upstream project of AAP's controller is **AWX**, its default EE is `quay.io/ansible/awx-ee`.

---
## Exercises

1. Install `ansible-navigator` on the lab VM in a venv, and check the versions of `ansible-navigator`,
   `ansible-builder` and `ansible-core`. Which Python does the venv use?
1. Run `whereami.yml --ee false`, then `whereami.yml` in the EE. Compare the hostname, OS, user, Python and
   ansible-core versions. Look for `/tmp/whereami.txt` on the lab VM after each run: when is it there, and why?
1. Open the EE image with `ansible-navigator images -m interactive`. What is the base OS of `community-ee-minimal`? Which
   collections are in it? Check the same with `ansible-navigator exec "ansible-galaxy collection list"`.
1. Run `ping.yml -m interactive`. Open the Play, a task, and the result of host2. Leave the TUI with `Esc`.
1. Kill the ssh-agent (`ssh-agent -k`, or open a new terminal) and run `ping.yml` again. What is the error? Then
   comment out the `--net=host` line in `ansible-navigator.yml` (with the agent running again). What is the error
   now? Restore the line. Which AAP object solves the first problem?
1. Run `report.yml` in `community-ee-minimal`. Which task fails, and why does the error talk about the filter and
   not about the Managed Hosts?
1. Build `lab-ee:1.0`. Read `ee/context/Containerfile`: in which stage are the collections installed? Open
   `localhost/lab-ee:1.0` in `ansible-navigator images -m interactive` and find `jmespath` among the Python packages.
1. Run `report.yml` with `--eei localhost/lab-ee:1.0 --pp never`. Then make `lab-ee:1.0` the default image in
   `ansible-navigator.yml` (don't forget the pull policy) and run it without `--eei`.
1. Look up the filter documentation from inside your EE:
   `ansible-navigator doc community.general.json_query -t filter --eei localhost/lab-ee:1.0 --pp never`.
1. Replay the failed `report.yml` run from exercise 6 from its artifact. Where do you see the error message?
1. **Bonus:** run a Playbook of an earlier lesson in `lab-ee` (you need a copy of this lesson's `ansible.cfg` and
   `host_inventory`). If it uses a collection or a Python library that is missing, add it to the `ee/` files,
   build `lab-ee:1.1`, and run again.
1. **Bonus:** AAP pulls EEs from a registry. Start a local one and push your EE to it:
   ```bash
   podman run -d --name registry -p 5000:5000 docker.io/library/registry:2
   podman tag localhost/lab-ee:1.0 localhost:5000/lab-ee:1.0
   podman push --tls-verify=false localhost:5000/lab-ee:1.0
   podman rmi localhost/lab-ee:1.0 localhost:5000/lab-ee:1.0
   ansible-navigator run report.yml --eei localhost:5000/lab-ee:1.0 --pp always \
       --pull-arguments=--tls-verify=false
   ```

---
#### Further reading
- [ansible-navigator documentation](https://docs.ansible.com/projects/navigator/)
- [ansible-builder: execution environment definition](https://docs.ansible.com/projects/builder/en/latest/definition/)
- [Getting started with Execution Environments](https://docs.ansible.com/ansible/latest/getting_started_ee/index.html)
- [Red Hat Ansible Automation Platform documentation](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/)
