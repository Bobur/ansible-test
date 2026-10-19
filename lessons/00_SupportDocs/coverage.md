# Course coverage vs. docs.ansible.com

How deeply this bootcamp covers each chapter of the official
[Ansible Community Documentation](https://docs.ansible.com/ansible/latest/) (ansible-core 2.18 era).
Use it to find where a topic is taught, and what to read on docs.ansible.com after the course.

**Coverage levels**

| Mark | Meaning |
|------|---------|
| ●●● | **Thorough:** explained, with runnable examples or a lab |
| ●●○ | **Partial:** explained with examples, but not every aspect of the docs chapter |
| ●○○ | **Mentioned:** reference, cheat sheet or a single example only |
| ○○○ | **Not covered** |

**Scope:** *Core* = expected from a beginner after this bootcamp, *Advanced* = useful next step,
*Out of scope* = deliberately left out of a 5-day beginner course.

## Summary

| docs.ansible.com guide | Core topics | Core coverage | All in-scope topics | Coverage |
|---|---|---|---|---|
| [Getting started](https://docs.ansible.com/ansible/latest/getting_started/index.html) | 2 | 100 % | 3 | `█████████░` 89 % |
| [Installation, configuration](https://docs.ansible.com/ansible/latest/installation_guide/index.html) | 3 | 67 % | 3 | `███████░░░` 67 % |
| [Building Ansible inventories](https://docs.ansible.com/ansible/latest/inventory_guide/index.html) | 5 | 73 % | 6 | `███████░░░` 67 % |
| [Using Ansible command line tools](https://docs.ansible.com/ansible/latest/command_guide/index.html) | 3 | 78 % | 3 | `████████░░` 78 % |
| [Playbooks: Ansible playbooks](https://docs.ansible.com/ansible/latest/playbook_guide/index.html) | 3 | 78 % | 4 | `███████░░░` 67 % |
| [Playbooks: Working with playbooks](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_templating.html) | 16 | 83 % | 20 | `███████░░░` 70 % |
| [Playbooks: Executing playbooks](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_checkmode.html) | 5 | 80 % | 7 | `███████░░░` 67 % |
| [Playbooks: Search paths, advanced syntax, manipulating data](https://docs.ansible.com/ansible/latest/playbook_guide/playbook_pathing.html) | 0 | – | 3 | `██░░░░░░░░` 22 % |
| [Protecting sensitive data with Ansible Vault](https://docs.ansible.com/ansible/latest/vault_guide/index.html) | 3 | 89 % | 3 | `█████████░` 89 % |
| [Using modules and plugins](https://docs.ansible.com/ansible/latest/plugins/plugins.html) | 1 | 100 % | 2 | `███████░░░` 67 % |
| [Using collections](https://docs.ansible.com/ansible/latest/collections_guide/index.html) | 2 | 67 % | 4 | `██████░░░░` 58 % |
| [Ansible Galaxy](https://docs.ansible.com/ansible/latest/galaxy/user_guide.html) | 1 | 67 % | 2 | `█████░░░░░` 50 % |
| [Ansible tips and tricks](https://docs.ansible.com/ansible/latest/tips_tricks/index.html) | 2 | 83 % | 2 | `████████░░` 83 % |
| [Reference & appendices](https://docs.ansible.com/ansible/latest/reference_appendices/playbooks_keywords.html) | 9 | 67 % | 11 | `██████░░░░` 61 % |
| [Other guides](https://docs.ansible.com/ansible/latest/index.html) | 0 | – | 2 | `███████░░░` 67 % |
| **Total** | **55** | **78 %** | **75** | **67 %** |

The percentage is the average of the coverage marks (●●● = 100 %, ●●○ = 67 %, ●○○ = 33 %, ○○○ = 0 %).

## Details

### [Getting started](https://docs.ansible.com/ansible/latest/getting_started/index.html)

| Topic on docs.ansible.com | Coverage | Scope | Where in the course |
|---|---|---|---|
| Introduction to Ansible, Ansible concepts | ●●● | Core | [Intro](../README.md), [06](../06_Playbooks/README.md) |
| Start automating, Building an inventory, Creating a playbook | ●●● | Core | [01](../01_InstallAndConfig/README.md), [04](../04_Inventory/README.md), [06](../06_Playbooks/README.md) |
| Getting started with Execution Environments | ●●○ | Advanced | [22](../22_Navigator/README.md) (`ansible-navigator`, `ansible-builder`, on the lab VM) |

### [Installation, configuration](https://docs.ansible.com/ansible/latest/installation_guide/index.html)

| Topic on docs.ansible.com | Coverage | Scope | Where in the course |
|---|---|---|---|
| Installing Ansible (dnf, pip) | ●●○ | Core | [01](../01_InstallAndConfig/README.md), [02/install.md](../02_TroubleshootConfig/install.md) (RHEL 8 era) |
| Installing on specific operating systems | ●○○ | Core | Fedora / RHEL only |
| Configuring Ansible (ansible.cfg, locations, precedence) | ●●● | Core | [05](../05_Configuration/README.md), [01](../01_InstallAndConfig/README.md) |
| Porting guides | ○○○ | Out of scope | — |

### [Building Ansible inventories](https://docs.ansible.com/ansible/latest/inventory_guide/index.html)

| Topic on docs.ansible.com | Coverage | Scope | Where in the course |
|---|---|---|---|
| How to build your inventory (groups, nested groups, ranges, variables, multiple inventories) | ●●● | Core | [04](../04_Inventory/README.md), [08](../08_Variables/README.md) |
| group_vars / host_vars directories | ●●● | Core | [08 precedence](../08_Variables/README.md#precedence-exercise), [09](../09_DirectoryLayout/README.md) |
| Patterns: targeting hosts and groups | ●●○ | Core | [04](../04_Inventory/README.md), [03 --limit](../03_AdHocCommands/README.md) |
| Working with dynamic inventory | ●○○ | Advanced | [04](../04_Inventory/README.md) (mentioned only) |
| Implicit 'localhost' | ●○○ | Core | used in many Plays, not explained |
| Connection methods and details (ansible_host, ansible_user, SSH keys) | ●●○ | Core | [01](../01_InstallAndConfig/README.md), [02](../02_TroubleshootConfig/README.md), [08](../08_Variables/README.md#connection-variables) |

### [Using Ansible command line tools](https://docs.ansible.com/ansible/latest/command_guide/index.html)

| Topic on docs.ansible.com | Coverage | Scope | Where in the course |
|---|---|---|---|
| Introduction to ad hoc commands | ●●● | Core | [03](../03_AdHocCommands/README.md) |
| Working with command line tools (ansible-config, -doc, -inventory, -vault, -galaxy, -console, -pull) | ●●○ | Core | [cli-tools.md](cli-tools.md), [05](../05_Configuration/README.md), [07](../07_AnsibleDocumentation/README.md) |
| Ansible CLI cheatsheet | ●●○ | Core | [cheatsheet.md](cheatsheet.md) |

### [Playbooks: Ansible playbooks](https://docs.ansible.com/ansible/latest/playbook_guide/index.html)

| Topic on docs.ansible.com | Coverage | Scope | Where in the course |
|---|---|---|---|
| Playbook syntax | ●●● | Core | [06](../06_Playbooks/README.md) |
| Playbook execution (order of Plays and tasks, linear strategy) | ●●○ | Core | [06](../06_Playbooks/README.md), [12 rolling updates](../12_ControlFlow/README.md#rolling-updates-and-failure-thresholds) |
| Ansible-Pull | ●○○ | Advanced | [cli-tools.md](cli-tools.md) |
| Verifying playbooks (--syntax-check, --check, --list-*, ansible-lint) | ●●○ | Core | [06](../06_Playbooks/README.md), [14/10-troubleshoot](../14_LinuxAdminLabs/10-troubleshoot/README.md), [16](../16_BestPractice/README.md) |

### [Playbooks: Working with playbooks](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_templating.html)

| Topic on docs.ansible.com | Coverage | Scope | Where in the course |
|---|---|---|---|
| Templating (Jinja2) | ●●● | Core | [13](../13_Templates/README.md) |
| Using filters to manipulate data | ●●○ | Core | [13](../13_Templates/README.md), [14](../14_LinuxAdminLabs/README.md) (password_hash, difference), [19](../19_Git/README.md) (selectattr) |
| Tests (is defined, is failed, is changed ...) | ●●○ | Core | [12](../12_ControlFlow/README.md#conditions) |
| Lookups | ●○○ | Core | [14/06-users](../14_LinuxAdminLabs/06-users/README.md) (file lookup) |
| Python3 in templates, now(), undef() | ○○○ | Advanced | — |
| Loops (loop, loop_control, register with loops) | ●●● | Core | [12](../12_ControlFlow/README.md#loops), [14](../14_LinuxAdminLabs/README.md) |
| Delegation and local actions (delegate_to, run_once) | ●●○ | Core | [12](../12_ControlFlow/README.md#delegation), [14/07-backup](../14_LinuxAdminLabs/07-backup/README.md) |
| Conditionals | ●●● | Core | [12](../12_ControlFlow/README.md#conditions) |
| Blocks (block / rescue / always) | ●●● | Core | [12](../12_ControlFlow/README.md#blocks) |
| Handlers | ●●● | Core | [12](../12_ControlFlow/README.md#handlers), [14/04](../14_LinuxAdminLabs/04-config-ssh/README.md), [14/09](../14_LinuxAdminLabs/09-chrony/README.md) |
| Error handling (failed_when, changed_when, ignore_errors, any_errors_fatal, max_fail_percentage) | ●●● | Core | [12](../12_ControlFlow/README.md#error-handling) |
| Setting the remote environment (environment keyword) | ●○○ | Advanced | [keywords.md](keywords.md) |
| Re-using artifacts (include_* / import_*) | ●●○ | Core | [15](../15_Roles/README.md#importing-roles), [14/02](../14_LinuxAdminLabs/02-services-states/README.md), [15/vsftpd](../15_Roles/vsftpd/README.md) |
| Roles | ●●● | Core | [15](../15_Roles/README.md), [15/vsftpd-role](../15_Roles/vsftpd-role/README.md) |
| Module defaults | ●○○ | Advanced | [keywords.md](keywords.md) |
| Interactive input: prompts | ●●○ | Core | [08](../08_Variables/README.md#prompt-variables), [14/04](../14_LinuxAdminLabs/04-config-ssh/README.md) |
| Using variables (incl. precedence) | ●●● | Core | [08](../08_Variables/README.md) |
| Discovering variables: facts and magic variables | ●●● | Core | [10](../10_Facts/README.md), [08](../08_Variables/README.md#magic-variables) |
| Play argument validation | ○○○ | Advanced | — |
| Example: Continuous delivery and rolling upgrades | ●●○ | Core | [12 rolling.yml](../12_ControlFlow/rolling.yml) |

### [Playbooks: Executing playbooks](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_checkmode.html)

| Topic on docs.ansible.com | Coverage | Scope | Where in the course |
|---|---|---|---|
| Check mode and diff mode | ●●○ | Core | [06](../06_Playbooks/README.md), [06/02-raw](../06_Playbooks/02-raw/README.md), [14/03-sshd](../14_LinuxAdminLabs/03-sshd/README.md) |
| Privilege escalation: become | ●●● | Core | [03](../03_AdHocCommands/README.md), [05](../05_Configuration/README.md) |
| Tags | ●●● | Core | [18](../18_Tags/README.md) |
| Executing playbooks for troubleshooting (--start-at-task, --step) | ●●○ | Core | [16](../16_BestPractice/README.md), [14/10-troubleshoot](../14_LinuxAdminLabs/10-troubleshoot/README.md) |
| Debugging tasks (debugger) | ●○○ | Advanced | [keywords.md](keywords.md) |
| Asynchronous actions and polling | ●○○ | Advanced | [12 errors.yml](../12_ControlFlow/errors.yml), [keywords.md](keywords.md) |
| Strategies, forks, serial, throttle, run_once | ●●○ | Core | [12](../12_ControlFlow/README.md#rolling-updates-and-failure-thresholds), [03 --forks](../03_AdHocCommands/README.md) |

### [Playbooks: Search paths, advanced syntax, manipulating data](https://docs.ansible.com/ansible/latest/playbook_guide/playbook_pathing.html)

| Topic on docs.ansible.com | Coverage | Scope | Where in the course |
|---|---|---|---|
| Search paths (config paths, task paths, role files/templates) | ●○○ | Advanced | [15](../15_Roles/vsftpd-role/README.md) (template lookup in roles) |
| Unsafe strings, YAML anchors and aliases | ○○○ | Advanced | — |
| Manipulating data (list comprehensions, complex transformations) | ●○○ | Advanced | [19](../19_Git/README.md), [13](../13_Templates/README.md) |

### [Protecting sensitive data with Ansible Vault](https://docs.ansible.com/ansible/latest/vault_guide/index.html)

| Topic on docs.ansible.com | Coverage | Scope | Where in the course |
|---|---|---|---|
| Ansible Vault, encrypting content (files, encrypt_string) | ●●● | Core | [11](../11_Vault/README.md) |
| Managing vault passwords (prompt, password file, vault IDs with labels) | ●●○ | Core | [11](../11_Vault/README.md) (no multi-ID labels) |
| Using encrypted variables and files in playbooks | ●●● | Core | [11](../11_Vault/README.md), [14/06-users](../14_LinuxAdminLabs/06-users/README.md) |

### [Using modules and plugins](https://docs.ansible.com/ansible/latest/plugins/plugins.html)

| Topic on docs.ansible.com | Coverage | Scope | Where in the course |
|---|---|---|---|
| Introduction to modules, FQCN, ansible-doc | ●●● | Core | [07](../07_AnsibleDocumentation/README.md), [modules.md](modules.md) |
| Working with plugins (callback, connection, become, lookup, filter, inventory) | ●○○ | Advanced | [05](../05_Configuration/README.md) (callback_result_format), [07](../07_AnsibleDocumentation/README.md) (ansible-doc -t) |
| Module maintenance and support, rejecting modules | ○○○ | Out of scope | — |

### [Using collections](https://docs.ansible.com/ansible/latest/collections_guide/index.html)

| Topic on docs.ansible.com | Coverage | Scope | Where in the course |
|---|---|---|---|
| Installing collections, requirements.yml | ●●○ | Core | [15](../15_Roles/README.md#ansible-galaxy), [17](../17_Kubernetes/README.md) |
| Downloading, listing, verifying collections | ●○○ | Advanced | [cli-tools.md](cli-tools.md) (collection list) |
| Using collections in a playbook (FQCN, collections keyword) | ●●○ | Core | all lessons use FQCN, [keywords.md](keywords.md) |
| Collection example: kubernetes.core | ●●○ | Advanced | [17](../17_Kubernetes/README.md) (demonstration, no cluster in the lab) |

### [Ansible Galaxy](https://docs.ansible.com/ansible/latest/galaxy/user_guide.html)

| Topic on docs.ansible.com | Coverage | Scope | Where in the course |
|---|---|---|---|
| Finding and installing roles and collections | ●●○ | Core | [15](../15_Roles/README.md#ansible-galaxy) |
| Creating roles / collections for Galaxy | ●○○ | Advanced | [15](../15_Roles/README.md) (ansible-galaxy role init, meta/main.yml) |

### [Ansible tips and tricks](https://docs.ansible.com/ansible/latest/tips_tricks/index.html)

| Topic on docs.ansible.com | Coverage | Scope | Where in the course |
|---|---|---|---|
| General, playbook, inventory tips, execution tricks | ●●○ | Core | [16](../16_BestPractice/README.md) |
| Sample Ansible setup (directory layout) | ●●● | Core | [09](../09_DirectoryLayout/README.md), [16](../16_BestPractice/README.md) |

### [Reference & appendices](https://docs.ansible.com/ansible/latest/reference_appendices/playbooks_keywords.html)

| Topic on docs.ansible.com | Coverage | Scope | Where in the course |
|---|---|---|---|
| Playbook keywords | ●●● | Core | [keywords.md](keywords.md) |
| Return values (rc, stdout, changed, results ...) | ●●○ | Core | [08](../08_Variables/README.md#registered-variables), [14/02](../14_LinuxAdminLabs/02-services-states/README.md) |
| Ansible configuration settings | ●●○ | Core | [05](../05_Configuration/README.md) |
| Precedence rules (config, variables, command line) | ●●● | Core | [05](../05_Configuration/README.md), [08](../08_Variables/README.md) |
| YAML syntax | ●●○ | Core | [06](../06_Playbooks/README.md#yaml-format), [prerequisites.md](prerequisites.md) |
| Special variables | ●●○ | Core | [08](../08_Variables/README.md#magic-variables), [10](../10_Facts/README.md) |
| Interpreter discovery | ●○○ | Core | interpreter_python in every ansible.cfg, [05](../05_Configuration/README.md) |
| Logging Ansible output | ●●○ | Core | [05](../05_Configuration/README.md#ansible-log) |
| Testing strategies (assert, ansible-lint, molecule) | ●○○ | Advanced | [12](../12_ControlFlow/README.md#error-handling) (assert), [16](../16_BestPractice/README.md) |
| Glossary, FAQ | ●○○ | Core | [Intro](../README.md) (concepts table) |
| Red Hat Ansible Automation Platform, Automation Hub | ●○○ | Advanced | [04](../04_Inventory/README.md), [15](../15_Roles/README.md#ansible-galaxy) (mentioned) |

### [Other guides](https://docs.ansible.com/ansible/latest/index.html)

| Topic on docs.ansible.com | Coverage | Scope | Where in the course |
|---|---|---|---|
| Managing Windows hosts (WinRM, SSH, win_ modules) | ●●○ | Advanced | [20](../20_Windows/README.md) (no Windows host in the lab: own VM or demo) |
| BSD and z/OS hosts | ○○○ | Out of scope | — |
| Network automation: getting started, network_cli, resource modules | ●●○ | Advanced | [21](../21_Network/README.md) (no devices in the lab: sandbox or demo) |
| Network automation: advanced and developer guides | ○○○ | Out of scope | — |
| Developer guide (custom modules and plugins) | ○○○ | Out of scope | [09](../09_DirectoryLayout/README.md), [16](../16_BestPractice/README.md) (library/ mentioned) |
| Legacy public cloud guides | ○○○ | Out of scope | — |
| Contributing, roadmaps, porting guides | ○○○ | Out of scope | — |

## Main gaps

Core topics that are only mentioned (●○○) or not covered — candidates to extend the course:

- **Installing on specific operating systems** (Installation, configuration) — currently ●○○: Fedora / RHEL only
- **Implicit 'localhost'** (Building Ansible inventories) — currently ●○○: used in many Plays, not explained
- **Lookups** (Playbooks: Working with playbooks) — currently ●○○: [14/06-users](../14_LinuxAdminLabs/06-users/README.md) (file lookup)
- **Interpreter discovery** (Reference & appendices) — currently ●○○: interpreter_python in every ansible.cfg, [05](../05_Configuration/README.md)
- **Glossary, FAQ** (Reference & appendices) — currently ●○○: [Intro](../README.md) (concepts table)

Advanced topics that are natural next steps after the bootcamp: Ansible Automation Platform (prepared by
[22](../22_Navigator/README.md), Execution Environments), dynamic inventory plugins, `async`/`poll`, the task debugger, Play argument validation, writing custom modules.
