#!/bin/bash
# =============================================================================
#  test_all_playbooks.sh - End-to-end test of the Ansible training lab
#
#  1. Pre-flight checks (OS, systemd/cgroup v2, podman, network)
#  2. Starts the lab with labenv/run.sh exactly as a participant would
#  3. Runs every lesson Playbook in course order, the way the README says
#  4. Runs --syntax-check on every Playbook found (coverage check)
#  5. Writes a summary + per-test logs, packed into one .tar.gz
#
#  Usage (inside WSL Fedora 42, or any Fedora/RHEL host):
#     sudo bash test_all_playbooks.sh [options]
#
#  Options:
#     --skip-setup     do not (re)start the lab, use the running containers
#     --local          test THIS checkout (copied into the Control Node)
#                      instead of the fresh GitHub clone made by run.sh
#     --idempotence    run every successful Playbook a 2nd time, expect changed=0
#     --only REGEX     run only test cases whose ID/dir matches REGEX
#     --timeout SEC    per-test timeout (default 900)
#
#  Result: ~/lab-test-<timestamp>/ (summary.md, summary.tsv, logs/)
#          and lab-test-<timestamp>.tar.gz (also copied to Windows Downloads
#          when running under WSL)
# =============================================================================

set -u

# ---------------------------------------------------------------- options ---
SKIP_SETUP=0; LOCAL=0; IDEMP=0; ONLY=""; TMO=900
while [ $# -gt 0 ]; do
    case "$1" in
        --skip-setup)  SKIP_SETUP=1 ;;
        --local)       LOCAL=1 ;;
        --idempotence) IDEMP=1 ;;
        --only)        ONLY="$2"; shift ;;
        --timeout)     TMO="$2"; shift ;;
        -h|--help)     sed -n '2,27p' "$0"; exit 0 ;;
        *) echo "Unknown option: $1"; exit 2 ;;
    esac
    shift
done

if [ "$(id -u)" -ne 0 ]; then
    echo "Please run with sudo:  sudo bash $0 $*"
    exit 1
fi

# The lab is rootful podman; results go to the invoking user's home
REAL_USER="${SUDO_USER:-root}"
REAL_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="$REAL_HOME/lab-test-$STAMP"
LOGS="$OUT/logs"
mkdir -p "$LOGS"
TSV="$OUT/summary.tsv"
MD="$OUT/summary.md"
printf "id\tdir\tcommand\texpect\tstatus\trc\tseconds\tidempotent\tnote\n" > "$TSV"

C_OK=$'\e[32m'; C_BAD=$'\e[31m'; C_WARN=$'\e[33m'; C_DIM=$'\e[2m'; C_0=$'\e[0m'
say()  { printf "%s\n" "$*" | tee -a "$OUT/console.log"; }
hdr()  { say ""; say "=== $* ==="; }

# ------------------------------------------------------ locate the repo ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/run.sh" ] && [ -d "$SCRIPT_DIR/ansible_node" ]; then
    REPO="$(dirname "$SCRIPT_DIR")"
else
    REPO="$REAL_HOME/ansible"
    if [ ! -d "$REPO/labenv" ]; then
        say "Cloning https://github.com/csurgay/ansible.git into $REPO"
        sudo -u "$REAL_USER" git clone -q https://github.com/csurgay/ansible.git "$REPO" || { say "git clone failed"; exit 1; }
    fi
fi
LABENV="$REPO/labenv"

# ------------------------------------------------------------ pre-flight ---
hdr "1. Pre-flight checks"
{
    echo "date:        $(date -Is)"
    echo "repo:        $REPO ($(git -C "$REPO" rev-parse --short HEAD 2>/dev/null) $(git -C "$REPO" log -1 --format=%cs 2>/dev/null))"
    echo "os:          $(. /etc/os-release; echo "$PRETTY_NAME")"
    echo "kernel:      $(uname -r)"
    echo "wsl:         $(grep -qi microsoft /proc/version && echo yes || echo no)"
    echo "pid1:        $(ps -p 1 -o comm=)"
    echo "cgroup:      $(stat -fc %T /sys/fs/cgroup)"
    echo "cpus/mem:    $(nproc) CPU, $(free -g | awk '/Mem:/{print $2}') GB RAM"
    echo "disk free:   $(df -h --output=avail / | tail -1 | tr -d ' ')"
    echo "podman:      $(podman --version 2>/dev/null || echo MISSING)"
    echo "git:         $(git --version 2>/dev/null || echo MISSING)"
} | tee "$OUT/env.txt" | tee -a "$OUT/console.log"

PREFLIGHT_FAIL=0
if ! command -v podman >/dev/null || ! command -v git >/dev/null || ! command -v awk >/dev/null \
   || ! command -v tar >/dev/null || ! command -v curl >/dev/null; then
    say "Installing podman, git, gawk, tar, curl ..."
    dnf install -y podman git gawk tar curl >>"$LOGS/00_dnf.log" 2>&1 || { say "${C_BAD}dnf install failed, see logs/00_dnf.log${C_0}"; PREFLIGHT_FAIL=1; }
fi
command -v script >/dev/null || dnf install -y util-linux-script >>"$LOGS/00_dnf.log" 2>&1

if [ "$(ps -p 1 -o comm=)" != "systemd" ]; then
    say "${C_WARN}WARNING: systemd is not PID 1. In WSL add '[boot] systemd=true' to /etc/wsl.conf, then 'wsl --shutdown'.${C_0}"
fi
if [ "$(stat -fc %T /sys/fs/cgroup)" != "cgroup2fs" ]; then
    say "${C_BAD}ERROR: cgroup v2 is required for the systemd-based lab containers.${C_0}"
    PREFLIGHT_FAIL=1
fi

say "Network reachability (HTTP status, 000 = blocked):"
for url in https://github.com https://registry-1.docker.io/v2/ https://mirrors.fedoraproject.org \
           https://galaxy.ansible.com https://raw.githubusercontent.com https://pypi.org; do
    code=$(curl -s -o /dev/null -m 10 -w '%{http_code}' "$url")
    printf "   %-40s %s\n" "$url" "$code" | tee -a "$OUT/console.log" "$OUT/env.txt" >/dev/null
    printf "   %-40s %s\n" "$url" "$code"
done
[ "$PREFLIGHT_FAIL" -eq 1 ] && { say "Pre-flight failed, stopping."; exit 1; }

# ---------------------------------------------------------- start the lab ---
CT="ansible"
cexec() {   # run a command in the Control Node as devops
    local dir="$1"; shift
    podman exec -i -u devops -w "$dir" \
        -e ANSIBLE_NOCOLOR=1 -e ANSIBLE_FORCE_COLOR=0 -e PY_COLORS=0 \
        "$CT" bash -c "$*" </dev/null
}

if [ "$SKIP_SETUP" -eq 0 ]; then
    hdr "2. Starting the lab with labenv/run.sh"
    say "(first run pulls docker.io/csurgay/ansible_node, this can take several minutes)"
    t0=$(date +%s)
    # run.sh ends in an interactive shell in the Control Node: give it a
    # pseudo-terminal with 'script' and answer every prompt with 'exit'.
    ( cd "$LABENV" && while sleep 5; do echo exit; done | script -qec "./run.sh" /dev/null ) > "$LOGS/00_run_sh.log" 2>&1
    rc=$?
    secs=$(( $(date +%s) - t0 ))
    if grep -q "^ERROR:" "$LOGS/00_run_sh.log"; then
        say "${C_BAD}run.sh FAILED after ${secs}s:${C_0} $(grep -m1 '^ERROR:' "$LOGS/00_run_sh.log")"
        say "See $LOGS/00_run_sh.log"
        printf "00_run_sh\tlabenv\t./run.sh\tok\tFAIL\t%s\t%s\t-\trun.sh reported an error\n" "$rc" "$secs" >> "$TSV"
        exit 1
    fi
    say "${C_OK}run.sh finished in ${secs}s${C_0}"
    printf "00_run_sh\tlabenv\t./run.sh\tok\tPASS\t%s\t%s\t-\t\n" "$rc" "$secs" >> "$TSV"
else
    hdr "2. Using the running lab (--skip-setup)"
fi

for c in ansible host1 host2 host3; do
    st=$(podman inspect -f '{{.State.Status}}' "$c" 2>/dev/null || echo missing)
    say "   container $c: $st"
    [ "$st" = "running" ] || { say "${C_BAD}Lab container $c is not running, stopping.${C_0}"; exit 1; }
done

if [ "$LOCAL" -eq 1 ]; then
    say "Copying local checkout into the Control Node (--local)"
    podman exec "$CT" rm -rf /home/devops/ansible
    podman cp "$REPO" "$CT":/home/devops/ansible
    podman cp "$LABENV/ansible_node/setup_ssh/ansible.cfg"    "$CT":/home/devops/ansible/labenv/
    podman cp "$LABENV/ansible_node/setup_ssh/host_inventory" "$CT":/home/devops/ansible/labenv/
    podman exec "$CT" chown -R devops:devops /home/devops/ansible
fi

L=/home/devops/ansible/lessons
{
    echo "--- Control Node versions"
    cexec /home/devops "ansible --version; python3 --version; cat /etc/fedora-release"
    echo "--- collections"
    cexec /home/devops "ansible-galaxy collection list 2>/dev/null | grep -E 'ansible.posix|community.general|ansible.windows|cisco.ios|kubernetes.core' || echo '(none of the checked collections found)'"
    echo "--- repo in Control Node"
    cexec /home/devops/ansible "git log -1 --format='%h %cs %s' 2>/dev/null || echo '(not a git checkout)'"
} >> "$OUT/env.txt" 2>&1
grep -E "^ansible \[core|^Python" "$OUT/env.txt" | sed 's/^/   /'

# ------------------------------------------------------------ test runner ---
N_PASS=0; N_FAIL=0; N_WARN=0; N_XFAIL=0; N_SKIP=0; N_INFO=0
RAN_FILES=""

run_case() {    # id | dir (relative to lessons) | expect (ok|fail|info|skip) | command | note
    local id="$1" dir="$2" expect="$3" cmd="$4" note="${5:-}"
    if [ -n "$ONLY" ] && ! [[ "$id $dir" =~ $ONLY ]]; then return; fi
    RAN_FILES="$RAN_FILES
$dir/$(grep -oE '[^ ]+\.ya?ml' <<<"$cmd" | tr '\n' ' ')"
    local log="$LOGS/$id.log" status rc secs idem="-"
    printf "%-34s " "$id" | tee -a "$OUT/console.log"

    if [ "$expect" = "skip" ]; then
        status="SKIP"; rc="-"; secs=0
        N_SKIP=$((N_SKIP+1))
        printf "%sSKIP%s  %s\n" "$C_DIM" "$C_0" "$note" | tee -a "$OUT/console.log"
        printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" "$id" "$dir" "$cmd" "$expect" "$status" "$rc" "$secs" "$idem" "$note" >> "$TSV"
        return
    fi

    { echo "# dir: $L/$dir"; echo "# cmd: $cmd"; echo "# expect: $expect"; echo; } > "$log"
    local t0; t0=$(date +%s)
    timeout "$TMO" podman exec -i -u devops -w "$L/$dir" \
        -e ANSIBLE_NOCOLOR=1 -e ANSIBLE_FORCE_COLOR=0 -e PY_COLORS=0 \
        "$CT" bash -c "$cmd" </dev/null >>"$log" 2>&1
    rc=$?
    secs=$(( $(date +%s) - t0 ))
    [ $rc -eq 124 ] && note="TIMEOUT after ${TMO}s. $note"

    # Things that exit 0 but are still suspicious
    local warn=""
    grep -qE "Could not match supplied host pattern|provided hosts list is empty|skipping: no hosts matched" "$log" && warn="no hosts matched"
    grep -qE "Unable to parse .* as an inventory source" "$log" && warn="${warn:+$warn; }inventory not found"
    grep -qE "unreachable=[1-9]" "$log" && warn="${warn:+$warn; }host unreachable"
    grep -qE "\[DEPRECATION WARNING\]" "$log" && note="${note:+$note; }deprecation warning"

    case "$expect" in
        ok)   if [ $rc -eq 0 ] && [ -z "$warn" ]; then status="PASS"
              elif [ $rc -eq 0 ]; then status="WARN"; note="$warn${note:+; $note}"
              else status="FAIL"; note="$(grep -m1 -E 'fatal:|ERROR!|FAILED!|failed:' "$log" | cut -c1-160)${note:+ | $note}"; fi ;;
        fail) if [ $rc -ne 0 ]; then status="XFAIL"; else status="XPASS"; note="expected to fail, but passed. $note"; fi ;;
        info) status="INFO"; note="rc=$rc. $note" ;;
    esac

    # Optional idempotence check: 2nd run must report changed=0
    if [ "$IDEMP" -eq 1 ] && [ "$status" = "PASS" ] && [[ "$cmd" == ansible-playbook* ]] \
       && ! [[ "$cmd" =~ --check|--syntax-check|--list|\&\& ]]; then
        local log2="$LOGS/$id.idempotence.log"
        timeout "$TMO" podman exec -i -u devops -w "$L/$dir" -e ANSIBLE_NOCOLOR=1 \
            "$CT" bash -c "$cmd" </dev/null >"$log2" 2>&1
        if grep -qE "changed=[1-9]" "$log2"; then idem="NO"; else idem="yes"; fi
    fi

    case "$status" in
        PASS)  N_PASS=$((N_PASS+1));   col=$C_OK ;;
        XFAIL) N_XFAIL=$((N_XFAIL+1)); col=$C_OK ;;
        WARN)  N_WARN=$((N_WARN+1));   col=$C_WARN ;;
        INFO)  N_INFO=$((N_INFO+1));   col=$C_DIM ;;
        *)     N_FAIL=$((N_FAIL+1));   col=$C_BAD ;;
    esac
    printf "%s%-5s%s %4ss  %s%s\n" "$col" "$status" "$C_0" "$secs" \
        "$([ "$idem" = NO ] && echo "[NOT idempotent] ")" "$note" | tee -a "$OUT/console.log"
    note="${note//$'\t'/ }"
    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" "$id" "$dir" "$cmd" "$expect" "$status" "$rc" "$secs" "$idem" "$note" >> "$TSV"
}

# ------------------------------------------------------------ test cases ---
# Course order. Commands are the ones documented in the lesson READMEs.
hdr "3. Running the lesson Playbooks"
AP="ansible-playbook"

# lessons/README.md: "Your First Playbook" (exists only inside the README)
run_case 00_your_first_playbook . ok "mkdir -p /tmp/first && cd /tmp/first && printf 'host1\nhost2\n' > inventory.ini && printf -- '---\n- name: Install and configure web server\n  hosts: host1, host2\n  become: true\n  tasks:\n    - name: Install Nginx\n      ansible.builtin.dnf:\n        name: nginx\n        state: present\n    - name: Start and enable Nginx\n      ansible.builtin.systemd:\n        name: nginx\n        state: started\n        enabled: true\n' > your-first-playbook.yml && $AP -i inventory.ini your-first-playbook.yml" "README example, run from /tmp/first"

run_case 01_adhoc_ping            ../labenv ok "ansible all -m ping" "same check as setup_devops.sh"
run_case 04_inventory_hostname    04_Inventory ok "$AP inventory-hostname.yml"

run_case 06_command               06_Playbooks/00-command-shell ok "$AP command.yml"
run_case 06_shell                 06_Playbooks/00-command-shell ok "$AP shell.yml"
run_case 06_haproxy               06_Playbooks/01-haproxy ok "$AP install-haproxy.yaml"
run_case 06_raw_check             06_Playbooks/02-raw ok "$AP raw.yml --check"
run_case 06_raw                   06_Playbooks/02-raw ok "$AP raw.yml"
run_case 06_sample_syntax         06_Playbooks/sample_playbook ok "$AP -i ./myinventory.ini --syntax-check sample_playbook.yml"
run_case 06_sample_check          06_Playbooks/sample_playbook ok "$AP -i ./myinventory.ini --check sample_playbook.yml"
run_case 06_sample                06_Playbooks/sample_playbook ok "$AP -i ./myinventory.ini sample_playbook.yml"
run_case 06_check_content         06_Playbooks/sample_playbook ok "$AP -i myinventory.ini check_content.yml"

run_case 08_hostnames             08_Variables ok "$AP -i app_inventory hostnames.yml"
run_case 08_nested                08_Variables ok "$AP nested.yml"
run_case 08_pass_variable         08_Variables ok "$AP -i pass_inventory pass_variable.yml"
run_case 08_prompt                08_Variables ok "$AP prompt.yml -e username=student -e password=secret -e packagename=tree" "vars_prompt answered with -e"
run_case 08_register              08_Variables ok "$AP register.yml"
run_case 08_test                  08_Variables ok "$AP test.yml"
run_case 08_precedence            08_Variables/precedence ok "$AP playbook.yml"
run_case 08_precedence_e          08_Variables/precedence ok "$AP playbook.yml -e myvar=99"

run_case 10_facts                 10_Facts ok "$AP facts.yml"
run_case 10_custom_facts          10_Facts ok "$AP custom_facts.yml"

run_case 11_vault                 11_Vault ok "$AP --vault-password-file=vault-pass.yml test.yml"
run_case 11_vault_view            11_Vault ok "ansible-vault view --vault-password-file=vault-pass.yml mysecret.yml"

run_case 12_blocks                12_ControlFlow ok "$AP blocks.yml"
run_case 12_conditions            12_ControlFlow ok "$AP conditions.yml"
run_case 12_conditions_bad        12_ControlFlow ok "$AP conditions.yml -e weather=bad"
run_case 12_errors                12_ControlFlow ok "$AP errors.yml"
run_case 12_handlers_1            12_ControlFlow ok "$AP handlers.yml" "1st run: handler runs"
run_case 12_handlers_2            12_ControlFlow ok "out=\$($AP handlers.yml 2>&1); rc=\$?; echo \"\$out\"; [ \$rc -eq 0 ] && ! grep -qE 'changed=[1-9]' <<<\"\$out\"" "2nd run: expect changed=0 everywhere"
run_case 12_handlers_3            12_ControlFlow ok "$AP handlers.yml -e training_header=Hello" "config change: handler runs"
run_case 12_loops                 12_ControlFlow ok "$AP loops.yml"
run_case 12_rolling               12_ControlFlow ok "$AP rolling.yml"

run_case 13_basics                13_Templates/00-basics ok "$AP playbook.yml"
run_case 13_hostdata              13_Templates/01-hostdata ok "$AP hostdata.yml && ansible host1 -m command -a 'cat /tmp/hostdata'"
run_case 13_report                13_Templates/02-report ok "$AP report.yml && ansible host1 -m command -a 'cat /tmp/report.txt'"
run_case 13_report_template       13_Templates/02-report ok "$AP report_template.yml && ansible host1 -m command -a 'cat /tmp/report.txt'"
run_case 13_storage               13_Templates/03-storage ok "$AP storage.yml"
run_case 13_nginx_site            13_Templates/04-nginx-site ok "$AP nginx-site.yml"

run_case 14_01_httpd              14_LinuxAdminLabs/01-webserver-testing ok "$AP -e webserver=httpd webserver.yml"
run_case 14_01_nginx              14_LinuxAdminLabs/01-webserver-testing ok "$AP -e webserver=nginx webserver.yml"
run_case 14_02_states             14_LinuxAdminLabs/02-services-states ok "$AP states.yml"
run_case 14_02_alternative        14_LinuxAdminLabs/02-services-states/alternative ok "$AP -i myhosts setup.yml" "command exactly as in README"
run_case 14_03_sshd               14_LinuxAdminLabs/03-sshd ok "$AP sshd.yml"
run_case 14_04_config_ssh         14_LinuxAdminLabs/04-config-ssh ok "$AP config-ssh.yml -e yesorno=yes" "vars_prompt answered with -e"
run_case 14_04_copy_motd          14_LinuxAdminLabs/04-config-ssh ok "$AP copy-motd.yml"
run_case 14_05_exists             14_LinuxAdminLabs/05-stat ok "$AP exists.yml"
run_case 14_05_stat               14_LinuxAdminLabs/05-stat ok "$AP stat.yml"
run_case 14_05_stat_e             14_LinuxAdminLabs/05-stat ok "$AP -e target_path=/etc/passwd stat.yml"
run_case 14_06_setup              14_LinuxAdminLabs/06-users ok "$AP 01-setup.yml"
run_case 14_06_create             14_LinuxAdminLabs/06-users ok "echo secret > /tmp/.vp && $AP --vault-password-file /tmp/.vp 02-create.yml; rc=\$?; rm -f /tmp/.vp; exit \$rc" "vault password 'secret' from file instead of @prompt"
run_case 14_06_copysshid          14_LinuxAdminLabs/06-users ok "$AP 03-copysshid.yml"
run_case 14_07_prepare            14_LinuxAdminLabs/07-backup ok "$AP prepare.yml"
run_case 14_07_rsync              14_LinuxAdminLabs/07-backup ok "$AP rsync.yml"
run_case 14_07_fetch              14_LinuxAdminLabs/07-backup ok "$AP fetch.yml"
run_case 14_08_download           14_LinuxAdminLabs/08-download ok "$AP download.yml"
run_case 14_09_chrony             14_LinuxAdminLabs/09-chrony ok "$AP chrony.yml"
run_case 14_10_syntax             14_LinuxAdminLabs/10-troubleshoot info "$AP --syntax-check site.yml" "troubleshooting lab"
run_case 14_10_site               14_LinuxAdminLabs/10-troubleshoot fail "$AP site.yml" "broken on purpose (diagnostic exercise)"
run_case 14_10_acceptance         14_LinuxAdminLabs/10-troubleshoot fail "bash test.sh | grep 'managed by Ansible'" "acceptance test must not pass before the fix"

run_case 15_deploy_web            15_Roles/deploy-web ok "$AP deploy-web.yml"
run_case 15_galaxy_install        15_Roles/galaxy ok "ansible-galaxy install -r requirements.yml" "needs galaxy.ansible.com + github.com"
run_case 15_system_roles_install  15_Roles/galaxy ok "rpm -q linux-system-roles || sudo dnf install -y linux-system-roles" "README step before timesync.yml"
run_case 15_galaxy_timesync       15_Roles/galaxy ok "$AP timesync.yml"
run_case 15_vsftpd                15_Roles/vsftpd ok "$AP site.yml"
run_case 15_vsftpd_role           15_Roles/vsftpd-role ok "$AP test.yml"

run_case 18_list_tags             18_Tags ok "$AP tags.yml --list-tags"
run_case 18_tags                  18_Tags ok "$AP tags.yml"
run_case 18_tags_install          18_Tags ok "$AP tags.yml --tags install"
run_case 18_tags_webserver        18_Tags ok "$AP tags.yml --tags webserver"
run_case 18_tags_list_tasks       18_Tags ok "$AP tags.yml --tags webserver --list-tasks"
run_case 18_skip_configure        18_Tags ok "$AP tags.yml --skip-tags configure"
run_case 18_tags_cleanup          18_Tags ok "$AP tags.yml --tags cleanup"
run_case 18_tags_facts            18_Tags ok "$AP tags_facts.yml --tags install_apache"

run_case 19_cmdb                  19_Git ok "$AP cmdb.yml"
run_case 19_cmdb_okos             19_Git info "$AP cmdb_okos.yml" "earlier version, kept for reference"

# No Windows / network devices in the lab: syntax only
for f in config iis updates users win_ping; do
    run_case "20_${f}_syntax"     20_Windows info "$AP --syntax-check $f.yml" "no Windows host in lab"
done
for f in backup config facts show vlans; do
    run_case "21_${f}_syntax"     21_Network info "$AP --syntax-check $f.yml" "no network device in lab"
done

# ------------------------------------------------- syntax-check everything ---
hdr "4. Syntax check of every Playbook found in lessons/ (coverage)"
SYN_FAIL=0; SYN_EXPECTED=0
cexec /tmp "echo secret > /tmp/.vp"   # both vault lessons use the password 'secret'
cexec "$L" "grep -rlE '^\s*-?\s*hosts:' --include=*.yml --include=*.yaml . | grep -v -e '^./mydir/' | sort" \
    > "$OUT/all_playbooks.txt" 2>/dev/null
NOT_RUN=""
while read -r pb; do
    d=$(dirname "${pb#./}"); f=$(basename "$pb")
    if cexec "$L/$d" "ansible-playbook --vault-password-file /tmp/.vp --syntax-check $f" > "$LOGS/syntax__${d//\//_}__$f.log" 2>&1; then
        r="ok"
    elif [[ "$d" == */tests || "$d" == *10-troubleshoot ]]; then
        r="xfail"; SYN_EXPECTED=$((SYN_EXPECTED+1))   # role skeleton tests / broken on purpose
    else
        r="FAIL"; SYN_FAIL=$((SYN_FAIL+1))
    fi
    # was this playbook executed in section 3?
    if grep -qF "$d/" <<<"$RAN_FILES" && grep -E "^$d/" <<<"$RAN_FILES" | grep -qw "$f"; then ran="ran"
    elif [[ "$d" == */tests ]]; then ran="role skeleton test"
    elif cexec "$L/$d" "grep -lqE 'import_playbook: *$f' *.yml" >/dev/null 2>&1; then ran="ran (imported)"
    else ran="NOT RUN"; NOT_RUN="$NOT_RUN $pb"; fi
    printf "   %-62s syntax:%-4s %s\n" "$pb" "$r" "$ran" | tee -a "$OUT/console.log" >/dev/null
    [ "$r" = "FAIL" ] && printf "   %s%-62s syntax:FAIL%s\n" "$C_BAD" "$pb" "$C_0"
done < "$OUT/all_playbooks.txt"
say "   $(wc -l < "$OUT/all_playbooks.txt") Playbooks found, $SYN_FAIL syntax failures, $SYN_EXPECTED expected (role skeleton tests, troubleshooting lab)"
[ -n "$NOT_RUN" ] && say "   Not executed in section 3:$NOT_RUN"

# ----------------------------------------------------------------- report ---
hdr "5. Summary"
TOTAL=$((N_PASS+N_FAIL+N_WARN+N_XFAIL+N_INFO+N_SKIP))
{
    echo "# Ansible lab test - $(date '+%Y-%m-%d %H:%M')"
    echo
    echo '```'; cat "$OUT/env.txt"; echo '```'
    echo
    echo "**$TOTAL test cases:** PASS $N_PASS · FAIL $N_FAIL · WARN $N_WARN · expected-fail $N_XFAIL · info $N_INFO · skipped $N_SKIP"
    echo "**Syntax check:** $(wc -l < "$OUT/all_playbooks.txt") Playbooks, $SYN_FAIL failed"
    echo
    echo "| ID | Dir | Status | rc | s | Idempotent | Note |"
    echo "|---|---|---|---|---|---|---|"
    tail -n +2 "$TSV" | awk -F'\t' '{printf "| %s | %s | **%s** | %s | %s | %s | %s |\n",$1,$2,$5,$6,$7,$8,$9}'
    echo
    echo "Per-test logs: logs/<ID>.log"
} > "$MD"

say "PASS $N_PASS   FAIL $N_FAIL   WARN $N_WARN   expected-fail $N_XFAIL   info $N_INFO   skip $N_SKIP"
if [ $((N_FAIL+N_WARN)) -gt 0 ]; then
    say ""
    say "Problems:"
    awk -F'\t' '$5=="FAIL"||$5=="WARN"||$5=="XPASS"{printf "   %-28s %-5s %s\n",$1,$5,$9}' "$TSV" | tee -a "$OUT/console.log"
fi

chown -R "$REAL_USER": "$OUT"
TAR="$REAL_HOME/lab-test-$STAMP.tar.gz"
tar -czf "$TAR" -C "$REAL_HOME" "lab-test-$STAMP" && chown "$REAL_USER": "$TAR"
say ""
say "Report:  $MD"
say "Archive: $TAR"

# Under WSL also drop the archive into the Windows Downloads folder
if grep -qi microsoft /proc/version && command -v cmd.exe >/dev/null 2>&1; then
    WINPROFILE=$(cd /mnt/c 2>/dev/null && cmd.exe /c "echo %USERPROFILE%" 2>/dev/null | tr -d '\r')
    if [ -n "$WINPROFILE" ]; then
        DL="$(wslpath "$WINPROFILE")/Downloads"
        [ -d "$DL" ] && cp "$TAR" "$DL/" && say "Copied to Windows: $WINPROFILE\\Downloads\\$(basename "$TAR")"
    fi
fi

[ "$N_FAIL" -eq 0 ]
