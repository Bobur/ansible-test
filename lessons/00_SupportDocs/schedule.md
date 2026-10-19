## Schedule of the week

5 days, 2 sessions of 2 hours per day.

| Day | Session | Topics | Lessons |
|-----|---------|--------|---------|
| 1 | 1 | Why automate, what is Ansible, architecture, infrastructure as code, installing Ansible and ssh keys, ad-hoc commands | [Intro](../README.md), [01](../01_InstallAndConfig), [02](../02_TroubleshootConfig), [03](../03_AdHocCommands) |
|   | 2 | Static inventories, hosts, host groups, nested groups, host ranges, host patterns, Ansible config, first playbooks, multiple plays | [04](../04_Inventory), [05](../05_Configuration), [06](../06_Playbooks) |
| 2 | 3 | YAML syntax, finding modules, variables, variable precedence, inventory host and group variables, vars directories, facts, custom facts | [07](../07_AnsibleDocumentation), [08](../08_Variables), [09](../09_DirectoryLayout), [10](../10_Facts) |
|   | 4 | Secrets with Ansible Vault, create and edit encrypted files, secrets in playbooks; running parts of playbooks with tags | [11](../11_Vault), [18](../18_Tags) |
| 3 | 5 | Task control: conditionals, loops, combining loops and conditions, handlers, blocks, error handling | [12](../12_ControlFlow) |
|   | 6 | Files and templates with Jinja2, file modules, Jinja2 loops and conditionals | [13](../13_Templates) |
| 4 | 7 | Importing and including in large playbooks, Roles, Role structure, using and creating roles, best practices | [15](../15_Roles), [16](../16_BestPractice) |
|   | 8 | Ansible Galaxy, collections, requirements file, system roles, playbooks and vars from Git | [15](../15_Roles#ansible-galaxy), [19](../19_Git) |
| 5 | 9 | Linux admin tasks with Ansible: users, packages, services, sshd, backup, time sync; check mode, troubleshooting | [14](../14_LinuxAdminLabs) |
|   | 10 | Ansible in the broader toolchain (Kubernetes); Execution Environments and `ansible-navigator`, the bridge to AAP; optional: Windows hosts, network devices (demo); summary and Q&A | [17](../17_Kubernetes), [22](../22_Navigator), [20](../20_Windows), [21](../21_Network) |

> [!NOTE]
> Lesson numbers follow the topics, not strictly the calendar: `14_LinuxAdminLabs` builds on everything up to
> Templates and is done on Day 5, `18_Tags` fits right after Vault on Day 2.

See [coverage.md](coverage.md) for how far each lesson covers the chapters of docs.ansible.com.

---
## Day 1 Session 1 – Introduction to Automation and Ansible

- Understand why to automate Linux administration tasks with Ansible
- Learn what Ansible is, how Ansible works
- Install and configure Ansible on a Control Node
- Purpose of Ansible ad-hoc commands and the Ansible CLI toolset
- Run single automation tasks with Ansible ad-hoc commands

## Day 1 Session 2 – Inventories, configuration, first Playbooks

- Create a list (inventory) of the systems you manage, write a simple playbook, and run it to automate tasks
- Learn how Ansible inventories work and how to manage a simple static inventory file
- Inventory Hosts, Host groups, Nested groups, Host ranges, Host patterns
- Find out where Ansible configuration files are located and how Ansible decides which one to use
- Edit configuration files to change default settings
- Write and run a basic playbook with the ansible-playbook command
- Write a playbook with several plays, including privilege escalation

## Day 2 Session 3 – Modules, variables, facts

- YAML vs JSON syntax and semantics
- How to find modules and their documentation with `ansible-doc`
- Use variables and facts in playbooks to make them easier to manage and reuse
- Create and use variables that apply to specific hosts, groups, plays, or globally
- How Ansible decides which variable takes priority (Variable precedence)
- Magic variables (`hostvars`, `groups`, `inventory_hostname`, ...)
- Use Ansible facts to get system information from managed hosts
- Create your own custom facts

## Day 2 Session 4 – Vault, Tags

- Protect sensitive variables with Ansible Vault
- Create and edit vault secret files
- Run playbooks that use encrypted variable files
- Run or skip parts of a playbook with tags

## Day 3 Session 5 – Task control

- Conditions to decide when tasks should run
- Loops to repeat tasks efficiently
- Create tasks that only run when another task changes something on a host (handlers)
- Group tasks with blocks
- Control what happens if a task fails, and decide when a task should be marked as failed or changed

## Day 3 Session 6 – Templates

- Deploy files that are automatically customized with Jinja2 templates
- Jinja2 variables, filters, loops and conditionals
- Copy, fetch, create and edit files on Managed Hosts
- Control permissions and ownership of files

## Day 4 Session 7 – Roles

- Organize and simplify complex automation projects
- Difference between `include_*` and `import_*`
- Split large playbooks into smaller pieces by including or importing other files
- What roles are, how they are organized, and how to use them in Playbooks
- Create your own role inside a project and run it in a Playbook
- Best practices

## Day 4 Session 8 – Galaxy, Git

- Download and use roles and collections from Ansible Galaxy or Git repositories
- `requirements.yml`
- Use Linux System Roles to perform common system tasks
- Use configuration data (CMDB) from a Git repository in a playbook

## Day 5 Session 9 – Linux admin labs, troubleshooting

- Use Ansible to handle everyday Linux administration jobs: users, packages, services, sshd, backup, time sync
- Check mode and dry runs
- Find and fix problems with playbooks or managed hosts

## Day 5 Session 10 – Further topics, Summary, Q&A

- Ansible with Kubernetes
- Execution Environments: run Playbooks with `ansible-navigator`, build an EE with `ansible-builder`, and how this maps to Ansible Automation Platform
- Optional, as a demo (no Windows hosts or network devices in the lab):
  - Managing Windows hosts: WinRM / SSH connection, `ansible.windows` modules, IIS, users, updates
  - Network automation: `network_cli`, `ansible_network_os`, Cisco IOS facts, show commands, backup, config, resource modules
- Summary of the week, Q&A
