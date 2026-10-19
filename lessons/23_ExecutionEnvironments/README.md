# Section 23: Execution Environments

### In this section the following subjects will be covered:

1. Why the classic Control Node stopped working: the dependency problem
1. Encapsulation: what an Execution Environment (EE) is, and what it is not
1. The layers of an EE and who is responsible for each
1. Where EEs come from: supported, community and your own images
1. The EE definition file in depth: base image, ansible-core, collections, Python and system dependencies
1. Building: the stages of an EE build, caching, why it takes time
1. Company networks: proxy, CA certificates, Automation Hub
1. Versioning, testing, distributing and maintaining EEs
1. Two teams, two EEs, one machine

> [!NOTE]
> The exercises of [Part 1](#exercise-1-dependency-trouble-on-the-control-node) run in the Control Node
> container. Building and running EEs needs Podman and `ansible-navigator`, so those parts run on the **lab VM**,
> set up as in [22_Navigator](../22_Navigator/README.md#installation).

---
## Part 1: The dependency problem

### One Ansible for everything (until ~2020)

Up to Ansible 2.9 there was one package: `ansible`. It contained the engine **and** thousands of modules, for
Linux, Windows, network devices, clouds, all released together. You installed it on the Control Node with `dnf` or
`pip`, and every Playbook on that machine used the same, tested set. Simple, but every fix to any module had to wait
for the next release of everything.

### The split: ansible-core and collections

From Ansible 2.10 the engine and the content were separated:

| Part | Released by | Release cycle |
|------|-------------|---------------|
| `ansible-core`: the engine, `ansible.builtin` modules, CLI tools | Ansible core team | about every 6 months, each line supported ~18 months |
| **Collections**: `community.general`, `ansible.posix`, `cisco.ios`, `amazon.aws`, ... | Hundreds of teams and vendors | Each one on its own schedule, with its own major versions and breaking changes |
| The `ansible` "community package" | Ansible community | A tested bundle of one `ansible-core` line plus ~100 collections |

This is good for content: a fix in `cisco.ios` ships when it is ready. But from now on **you** assemble the
working combination, and each piece has requirements of its own.

### What one Playbook really depends on

| Layer | Example | Requirement it brings |
|-------|---------|-----------------------|
| Operating system | RHEL 8, RHEL 9, Fedora 42 | Which Python versions and system libraries exist |
| Python of the controller | 3.6 ... 3.13 | Each `ansible-core` line supports only a few: 2.16 runs on 3.10–3.12, 2.18 on 3.11–3.13 |
| `ansible-core` | 2.16, 2.18 | Each line supports only certain **target** Pythons: 2.17 dropped Python 2.7 and 3.6 on the Managed Hosts (default Python of RHEL 8 / RHEL 7) |
| Collections | `community.general` 8 vs 10 | `requires_ansible` (minimum ansible-core), removed or renamed modules and options between major versions |
| Python libraries | `jmespath`, `pywinrm`, `kubernetes`, `boto3`, `netaddr` | Needed on the **controller** by modules and filters, each with its own version constraints |
| System packages | `openssh-clients`, `sshpass`, `git`, `krb5` | Needed by connection plugins and modules |

### Why one Control Node can't serve everyone

Put a few teams on one Control Node, or on one Ansible Tower server, and the combinations collide:

- **Only one version per place.** One Python environment holds one `ansible-core` and one version of each Python
  library. One collections path holds one version of each collection. Team A needs `community.general` 8 for its
  old Playbooks, team B needs 10: they can't both be in `~/.ansible/collections`.
- **Silent shadowing.** Ansible searches several collection paths and uses the **first** match. The same Playbook
  uses a different collection version for `devops`, for `root`, and in the CI pipeline: green for one,
  red for another.
- **Upgrades break somebody.** Upgrading `ansible-core` for team B's new feature drops Python 3.6 targets: team A's
  RHEL 8 hosts become unmanageable overnight.
- **pip vs dnf.** `pip install` as root into the system Python (we saw this in the installation of
  ansible-navigator) overwrites libraries that `dnf` and other system tools depend on.
- **Not reproducible.** "Which versions did the job use last March?" Nobody knows: the machine has changed since.
- **Works on my laptop.** The developer's laptop, the test server and production all have different stacks.

Ansible Tower (the predecessor of AAP) tried to solve this with several **custom Python virtualenvs** on the
Tower servers. They had to be created by hand on every node, kept in sync, and could still not isolate system
packages. With dozens of teams and hundreds of collections it became unmanageable. AAP 2 (2021) replaced them with
**Execution Environments**.

---
## Exercise 1: Dependency trouble on the Control Node

In the Control Node container, as `devops` (`d0` alias), in `~/ansible/lessons/23_ExecutionEnvironments`.

#### versions.yml
```yaml
---
- name: Which versions does this Ansible use?
  hosts: localhost
  connection: local
  gather_facts: true
  vars:
    ansible_python_interpreter: "{{ ansible_playbook_python }}"

  tasks:
    - name: List every community.general collection this Ansible can see
      ansible.builtin.command: ansible-galaxy collection list community.general
      register: result_collections
      changed_when: false
      failed_when: false

    - name: Show the versions
      ansible.builtin.debug:
        msg:
          - "OS:            {{ ansible_facts['distribution'] }} {{ ansible_facts['distribution_version'] }}"
          - "User:          {{ ansible_facts['user_id'] }}"
          - "Python:        {{ ansible_facts['python_version'] }} ({{ ansible_playbook_python }})"
          - "ansible-core:  {{ ansible_version['full'] }}"
          - "Collections:   {{ result_collections.stdout_lines | select('search', '^community.general') | list }}"
```

1. Check what is installed: the Fedora `ansible` package brings `ansible-core` **and** the collections of the
   community package.
   ```bash
   ansible --version
   ansible-galaxy collection list community.general
   ansible-config dump | grep -i COLLECTIONS_PATHS
   ansible-playbook versions.yml
   ```
1. Team A "needs" an older `community.general`. Install it the usual way:
   ```bash
   ansible-galaxy collection install 'community.general:>=8.0.0,<9.0.0'
   ansible-galaxy collection list community.general
   ansible-playbook versions.yml
   ```
   How many versions are on the machine now? In which directories? Which one does a Playbook of `devops` use, and
   why (look at the order of `COLLECTIONS_PATHS`)?
1. Run the same Playbook as root: `sudo ansible-playbook versions.yml`. Which version does root use?
   What would this mean for a cron job or a CI pipeline running as another user?
1. Now team B asks for `community.general` 10 for **its** Playbooks, at the same time. Can you install both
   into `~/.ansible/collections`? What could you do instead (think of `collections_path` per project,
   virtualenvs), and what would you still not be able to separate?
1. Clean up, so the other lessons use the packaged version again:
   ```bash
   rm -rf ~/.ansible/collections/ansible_collections/community/general
   ```

---
## Part 2: Encapsulation

The solution is the one software development found for the same problem: **package the application with all
its dependencies into a container image**.

An **Execution Environment** is a container image that is a complete, minimal Ansible control node:

```
+---------------------------- EE image  (e.g. team-b-ee:1.0) ----------------------------+
|  collections            community.general 10.x, ansible.posix ...       <- automation team |
|  Python libraries       jmespath, ansible-runner ...                     <- automation team |
|  ansible-core           2.18.x                                           <- automation team |
|  Python                 3.12                                             <- base image      |
|  system packages        openssh-clients, dnf, libraries ...              <- base image      |
|  OS userspace           UBI 9 (RHEL 9)                                   <- base image      |
+---------------------------------------------------------------------------------------------+
        ^ mounted at run time, NOT in the image:  project (Playbooks, roles, inventory,
          ansible.cfg), credentials (ssh keys, vault passwords, tokens)
```

What encapsulation gives you:

| Problem on a shared Control Node | With EEs |
|----------------------------------|----------|
| One version per place | Every team, even every project, has its own image; any number of them side by side |
| Silent shadowing | The image contains exactly one, known set; nothing from the host leaks in |
| Upgrades break somebody | Build `team-b-ee:2.0`, team A stays on `team-a-ee:1.0` until it is ready |
| pip vs dnf on the host | Nothing is installed on the host except Podman (and navigator) |
| Not reproducible | The tag `team-a-ee:1.0` is the same bytes today and in a year (keep it in a registry) |
| Works on my laptop | Laptop, CI and AAP run the very same image |

What an EE is **not**:

- **Not where your Playbooks live.** The project is mounted at run time, so changing a Playbook needs no rebuild.
- **Not a Managed Host.** The EE is the *controller* side: modules are still copied to the Managed Hosts and run
  with *their* Python. The target Python support of the `ansible-core` in the EE still matters.
- **Not a place for secrets.** Anyone who can pull the image can read every file in it.
- **Not persistent.** A new container is started for every run and removed after it; `localhost` is this container.

---
## Where EEs come from

| Source | Examples | Use it when |
|--------|----------|-------------|
| **Red Hat supported** (AAP subscription, `registry.redhat.io`) | `ansible-automation-platform-25/ee-minimal-rhel9` (ansible-core only), `ee-supported-rhel9` (with the Red Hat certified collections) | Production with AAP: supported, security updates, the base for your own EEs |
| **Community** (`ghcr.io`, `quay.io`) | `ansible-community/community-ee-minimal`, `community-ee-base`, `quay.io/ansible/awx-ee` (the default EE of AWX) | Learning, testing, community projects |
| **Your own**, built with `ansible-builder` | `team-a-ee`, `team-b-ee`, `lab-ee` | Almost always in real life: a supported base plus the collections and libraries your Playbooks need |

---
## Part 3: The definition file

`ansible-builder` builds an image from `execution-environment.yml`. The two team EEs of this lesson:

#### team-a-ee/execution-environment.yml
```yaml
---
version: 3

images:
  base_image:
    name: registry.access.redhat.com/ubi9/ubi:9.6     # pinned, not :latest

dependencies:
  python_interpreter:
    package_system: python3.12
    python_path: /usr/bin/python3.12
  ansible_core:
    package_pip: ansible-core==2.16.*                  # last release line for Python 3.6 targets
  ansible_runner:
    package_pip: ansible-runner
  galaxy:
    collections:
      - name: community.general
        version: ">=8.0.0,<9.0.0"
  system:
    - openssh-clients [platform:rpm]

options:
  package_manager_path: /usr/bin/dnf
```

#### team-b-ee/execution-environment.yml
```yaml
---
version: 3

images:
  base_image:
    name: registry.access.redhat.com/ubi9/ubi:9.6     # same base as team A: shared, cached layers

dependencies:
  python_interpreter:
    package_system: python3.12
    python_path: /usr/bin/python3.12
  ansible_core:
    package_pip: ansible-core==2.18.*
  ansible_runner:
    package_pip: ansible-runner
  galaxy:
    collections:
      - name: community.general
        version: ">=10.0.0,<11.0.0"
  python:
    - jmespath
  system:
    - openssh-clients [platform:rpm]

options:
  package_manager_path: /usr/bin/dnf
```

### The keys

| Key | Meaning |
|-----|---------|
| `version: 3` | Schema of ansible-builder 3.x. Without it builder assumes the old version 1 format |
| `images.base_image.name` | The image to start from. Must be RPM based (dnf or microdnf). Use the full `registry/namespace/name:tag` |
| `dependencies.python_interpreter` | `package_system`: the RPM to install; `python_path`: the interpreter to use. Leave it out if the base image already has the right Python |
| `dependencies.ansible_core` | `package_pip`: anything pip accepts (`ansible-core==2.18.*`, a URL). Leave it out if the base already has ansible-core |
| `dependencies.ansible_runner` | Same for `ansible-runner`, which navigator and AAP use to start Ansible in the EE |
| `dependencies.galaxy` | Collections (and roles), in the `requirements.yml` format: a file name, or inline as above |
| `dependencies.python` | Python libraries in pip format: a `requirements.txt` file name, or an inline list |
| `dependencies.system` | RPM packages in [bindep](https://docs.opendev.org/opendev/bindep/latest/readme.html) format: a `bindep.txt` file name, or an inline list |
| `additional_build_files` | Files copied into the build context (CA certificates, `ansible.cfg`) |
| `additional_build_steps` | Extra Containerfile lines, at `prepend_base`, `append_base`, `prepend_galaxy`, `append_galaxy`, `prepend_builder`, `append_builder`, `prepend_final`, `append_final` |
| `options.package_manager_path` | `/usr/bin/dnf` (default) or `/usr/bin/microdnf` for minimal images |
| `options.tags` | Image name(s), instead of `-t` on the command line |

Inline lists (as in the team EEs) keep everything in one file. Separate `requirements.yml`, `requirements.txt` and
`bindep.txt` files (as in [22_Navigator/ee](../22_Navigator/ee/)) are easier to diff and review when the lists get
long. Both are fine.

### Collections bring their own dependencies

A collection can declare the Python libraries and RPMs it needs in its own `requirements.txt` and `bindep.txt`.
`ansible-builder` reads them from every collection (**introspection**) and adds them to yours automatically.
What you list yourself is what is **optional** in a collection, like `jmespath` for the `json_query` filter of
`community.general`: the collection works without it, until a Playbook uses that filter.

### Choosing the base image

| Base image | Then in the definition |
|------------|------------------------|
| `registry.access.redhat.com/ubi9/ubi` (free RHEL 9 userspace) | `python_interpreter`, `ansible_core`, `ansible_runner`, `package_manager_path: /usr/bin/dnf` |
| `registry.redhat.io/ansible-automation-platform-25/ee-minimal-rhel9` (needs `podman login registry.redhat.io`) | **No** `python_interpreter`, `ansible_core`, `ansible_runner`: already inside. `package_manager_path: /usr/bin/microdnf` |
| `ghcr.io/ansible-community/community-ee-minimal` | ansible-core already inside; check its package manager before adding system packages |

In a company with AAP, start from `ee-minimal-rhel9` (or `ee-supported-rhel9`): it is supported and gets security
updates from Red Hat. This lesson uses UBI only because it needs no Red Hat login.

---
## Part 4: Building

```bash
source ~/navigator/bin/activate
cd ~/ansible/lessons/23_ExecutionEnvironments/team-b-ee
ansible-builder create          # optional: only writes context/Containerfile, read it first
ansible-builder build -t team-b-ee:1.0 -v 3
podman images
```

The generated `context/Containerfile` is a **multi-stage build**:

| Stage | What it does |
|-------|--------------|
| `base` | Base image + Python + pip + ansible-core + ansible-runner: the common foundation of the other stages |
| `galaxy` | `ansible-galaxy collection install` of the collections |
| `builder` | Introspects the collections, collects all Python and system requirements, builds Python wheels |
| `final` | Starts again from `base`, installs the RPMs, the wheels and the collections: only the results, no build tools |

### Why it takes time

The first build of an EE typically takes 5–15 minutes: several `dnf` runs (each downloading repository metadata),
`pip` downloads and wheel builds, big collections (`community.general` has thousands of files), and writing
hundreds of MB of layers. Behind a proxy, or on a slow disk, it takes longer.

- **Layer cache:** build the same definition again and Podman reuses the cached layers: seconds instead of minutes.
  Team A and team B use the same base image and Python, so the second team's build reuses the `base` layers too.
  `--no-cache` forces a full rebuild (e.g. to get the latest security updates of the base).
- **Storage driver:** `podman info --format '{{.Store.GraphDriverName}}'` must say `overlay`. With `vfs` every layer
  is a full copy, and builds are many times slower.
- **Start higher:** a base image that already contains Python and ansible-core (`ee-minimal-rhel9`) skips the most
  expensive part.
- **Only what you need:** every collection and library adds time and size. One EE per purpose (Linux, Windows,
  network, cloud) instead of one huge image.
- **Build once, share many times:** a team builds the EE in a CI pipeline and pushes it to a registry; everybody
  else just pulls it.

---
## Company networks

The build downloads the base image, RPMs, Python packages and collections. In a company network:

```yaml
additional_build_files:
  - src: files/company-ca.crt            # relative to the directory of execution-environment.yml
    dest: certs
  - src: files/ansible.cfg               # [galaxy] server_list pointing to Automation Hub / a Galaxy mirror
    dest: configs

additional_build_steps:
  prepend_base:
    - COPY _build/certs/company-ca.crt /etc/pki/ca-trust/source/anchors/
    - RUN update-ca-trust
  prepend_galaxy:
    - COPY _build/configs/ansible.cfg /etc/ansible/ansible.cfg
```

- **Proxy:** `podman build` passes the `HTTP_PROXY` / `HTTPS_PROXY` / `NO_PROXY` variables of your shell into the
  build automatically.
- **CA certificate:** if the proxy re-signs TLS, `dnf`, `pip` and `ansible-galaxy` inside the build need the company
  CA, added as above.
- **Content sources:** an internal registry for the base image, a PyPI mirror (`pip.conf`, or `PIP_INDEX_URL`),
  and Private Automation Hub or a Galaxy mirror for collections.
- **Tokens:** an Automation Hub token is needed at build time only. Pass it as a build argument
  (`--build-arg`), never write it into a file that ends up in the image.

---
## Part 5: Versioning, testing, distributing

### Tags are versions

- Tag every build: `team-b-ee:1.0`, `1.1`, `2.0`. **Never** rebuild and overwrite a tag that Playbooks use: the
  whole point is that a tag always means the same content.
- Keep `execution-environment.yml` in Git next to the Playbooks (or in its own repo), and build from CI.
- Pin inside the definition too: base image tag, `ansible-core==2.18.*`, collection version ranges.
- Rebuild regularly (e.g. monthly, as a new tag) to get the security updates of the base image.

### Test an EE before you use it

An EE is just a container image: you can look into it with Podman alone.

```bash
podman run --rm localhost/team-b-ee:1.0 ansible --version
podman run --rm localhost/team-b-ee:1.0 ansible-galaxy collection list
podman run --rm localhost/team-b-ee:1.0 pip list
podman run --rm localhost/team-b-ee:1.0 cat /etc/os-release
```

or with navigator: `ansible-navigator images -m interactive`, `ansible-navigator collections`, and a smoke-test
Playbook like `versions.yml`.

### Distribute it

| Way | Commands |
|-----|----------|
| Registry (normal way, needed for AAP) | `podman tag localhost/team-b-ee:1.0 registry.example.com/automation/team-b-ee:1.0`, then `podman push ...` |
| File (offline, classroom) | `podman save -o team-b-ee-1.0.tar localhost/team-b-ee:1.0`, copy, `podman load -i team-b-ee-1.0.tar` |

In AAP the image is pushed to **Private Automation Hub** (which is also a container registry), registered as an
**Execution Environment** resource with its pull policy, and selected on job templates, projects or organizations.

---
## Exercise 2: Two teams, two EEs, one machine

On the lab VM, in `~/ansible/lessons/23_ExecutionEnvironments`, with the navigator venv activated.

1. Read both definition files. Write down which ansible-core and `community.general` versions you expect in each
   EE, and why team A can't simply upgrade.
1. Build team B's EE with `ansible-builder build -t team-b-ee:1.0 -v 3` in `team-b-ee/`. While it runs, read
   `team-b-ee/context/Containerfile` and find the four stages.
1. Build team A's EE in `team-a-ee/`. Which steps are much faster than for team B, and why?
1. Compare the images: `podman images`, then `podman run --rm localhost/team-a-ee:1.0 ansible --version` and the
   same for team B. How big are they?
1. Run the same Playbook in both EEs:
   ```bash
   ansible-navigator run versions.yml --eei localhost/team-a-ee:1.0
   ansible-navigator run versions.yml --eei localhost/team-b-ee:1.0
   ```
   Compare with Exercise 1: how many `community.general` versions does each EE see? Did anything get installed on
   the lab VM itself?
1. Team B wants `ansible.posix` as well. Add it to `team-b-ee/execution-environment.yml`, build `team-b-ee:1.1`,
   and check that `team-b-ee:1.0` still exists, unchanged. Which stages were rebuilt?
1. Replace the `9.6` tag of the base image with `latest` in one of the definitions. Why is this a bad idea for
   an EE that a team relies on?
1. Save team A's EE to a file with `podman save`, remove it with `podman rmi`, load it back with `podman load`, and
   run `versions.yml` with it again. This is how an EE could be handed to an offline lab.
1. **Discussion:** your bank has RHEL 7, 8 and 9 Managed Hosts, Windows servers and Cisco switches, and five
   automation teams. How many EEs would you build, from which base, and who would own them?

---
#### Further reading
- [Getting started with Execution Environments](https://docs.ansible.com/ansible/latest/getting_started_ee/index.html)
- [ansible-builder: execution environment definition](https://docs.ansible.com/projects/builder/en/latest/definition/)
- [ansible-core support matrix](https://docs.ansible.com/ansible/latest/reference_appendices/release_and_maintenance.html)
- [Red Hat AAP: Creating and using execution environments](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/)
- Running and using EEs with `ansible-navigator`: [22_Navigator](../22_Navigator/README.md)
