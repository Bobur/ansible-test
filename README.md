# Containerized Ansible Training Lab

| Ansible Bootcamp | Ipoteka Tashkent 2026 Fall |
|-----------|------------|
| Purpose | Containerized (single host) full Ansible training lab (lessons and exercises) |
| Audience | Future DevOps engineers new to Ansible |
| Prerequisites | Linux, any scripting experience |
| Control Node | Containerized Ansible execution environment on a host or VM |
| Managed Hosts | Dozens of containerized Linux servers on the same single host |
| Training Lab | Fully automated setup and real playbook exercises |
| Versions | Ansible core 2.18, Python 3.13, Jinja 3.1, Podman 5.4, Git 2.51, Fedora 42, Linux 6.14 |
| Date Created | 2022-06-18 (notes for the first offline and early git versions) |
| Last Modified | 2026-10-20 |
| Contact | csurgay@gmail.com |
| Author | Automation Architect, Father of three, Red Hat Certified Engineer, Red Hat Certified Instructor |

In the first complete zero-to-RHCE-level **Containerized Ansible Training Lab** there are lightweight containers for both the Ansible Control Node, and the dozens of Managed Host Linux servers. This is new compared to earlier Labs, where heavyweight VMs were used and only a few fix hosts were available to be managed by exercises. This containerized approach allows for a **high degree of flexibility**. Both the Control Node and Managed Hosts can be preconfigured for the exercises learning goals. Recontainerization is seamless for participants and all the benefits of containerization contribute to a **faster learning curve**. These benefits are exclusive environments for different exercise subjects, encapsulation of required dependencies, portability on operating systems, isolated exercise testing, easier management.

For the Control Node to run in a container is not uncommon. But for **Ansible to manage containers as Managed Hosts** is a different matter. Exercise Playbooks to be executed on Containerized Managed Hosts have unobvious conditions. These include e.g. the ability to `ssh` into the Managed Host containers. Ansible system and service modules require `systemd` to run inside the Managed Host containers. In order for system hardware related modules like chrony to work properly, special privileges, so called system capabilities are required in containers. 

### Benefits of a Container based Ansible bootcamp

First of all, it can be set up and run in a single host or VM, because the Control Node and Managed Hosts are containerized from pre-built images by a quick and simple command script. So there is no need for a bunch of VMs per participant like in Red Hat training labs. Footprint of HW requirements is minimal, a cheap low capacity laptop is sufficient. 

On the other hand, pre-designed environments for different exercises can also be quickly set up as containers. This further simplifies the bootcamp setup. There is no need for pre-exercise "lab scripts". Participants can also compare or work on multiple lessons at the same time, as they are lightweight Container environments.

### Container based Ansible Training Lab

<img width="677" height="319" alt="image" src="https://github.com/user-attachments/assets/654a78e4-48f4-414a-864e-a051eb9ddc13" />

---
# Usage

### 1. Launch the Training Lab

Log in to any Red Hat based host or VM, then:

```bash
# Install Git and Podman
sudo dnf install -y git podman

# Clone the Git repo on the Host VM
git clone https://github.com/csurgay/ansible.git

# Run the Lab Containers and enter the Control Node (ansible)
cd ansible/labenv/
sudo ./run.sh
```

> [!WARNING]
> `run.sh` **recreates** the lab containers (`ansible`, `host1`..`host3`) from scratch and re-clones this repo
> inside the Control Node from GitHub. Everything participants created inside the containers is lost.
> Only re-run it when you really want a clean lab.

> [!NOTE]
> The lab needs internet access during setup: the container image is pulled from `docker.io`, and the repo is
> cloned from `github.com` inside the Control Node. A few lessons also download packages (`dnf`) or files.
> On restricted corporate networks pre-pull the image (`sudo podman pull docker.io/csurgay/ansible_node`)
> and make sure the dnf mirrors and GitHub are reachable through the proxy.

### 2. Test the Training Lab

In the `labenv` directory of the Ansible Control Node container `ansible`:

```bash
cd /home/devops/ansible/labenv
ansible all -m ping
```

### 3. Read and follow the lessons material

Numbered lesson directories under `ansible/lessons`, see the [schedule](lessons/00_SupportDocs/schedule.md)
for the order they are taught in.

### 4. Hands-on exercises

Enter the Ansible Control Node container (`ansible`) and run the exercise commands and playbooks

```bash
sudo podman exec -it -u devops -w /home/devops/ansible/lessons ansible /bin/bash
```

### "Console" access for hosts

Load the aliases below into your builder VM shell. They provide easy "console" access to the Control Node and
Managed Hosts. E.g. type `r0` for root access to the Control Node, or `d1` for user devops on Managed Host no. 1.

```bash
source ~/ansible/labenv/console_access_aliases.sh
```

which defines:

```bash
alias r0="sudo podman exec -it -u root ansible bash"
alias r1="sudo podman exec -it -u root host1 bash"
alias r2="sudo podman exec -it -u root host2 bash"
alias r3="sudo podman exec -it -u root host3 bash"
alias d0="sudo podman exec -it -u devops -w /home/devops/ansible/lessons ansible bash"
alias d1="sudo podman exec -it -u devops -w /home/devops host1 bash"
alias d2="sudo podman exec -it -u devops -w /home/devops host2 bash"
alias d3="sudo podman exec -it -u devops -w /home/devops host3 bash"
```
