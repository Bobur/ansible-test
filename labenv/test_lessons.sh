#!/bin/bash
#
# Test the lessons that run on the lab VM with ansible-navigator and Execution Environments:
#   22_Navigator, 23_ExecutionEnvironments (and later lessons, see "Adding a lesson" below)
#
# Run it on the lab VM (where labenv/run.sh started the lab containers), as the user who
# does the lessons:
#
#   ./test_lessons.sh                 # all lessons
#   ./test_lessons.sh 23              # only lesson 23
#   ./test_lessons.sh --no-build      # skip EE builds, test only the images that already exist
#   ./test_lessons.sh --rebuild 22    # rebuild the EE images of lesson 22 even if they exist
#   ./test_lessons.sh --reinstall     # recreate the navigator venv with the latest pip packages
#   ./test_lessons.sh --no-install    # don't create the venv, use ansible-navigator from the PATH
#
# ansible-navigator and ansible-builder are installed with pip into the venv ~/navigator
# (as in 22_Navigator), with the newest Python found: 3.10+ preferred, 3.9 gets older releases.
# Set NAVIGATOR_VENV to use another directory.
# Missing EE images are built (several minutes per image on the first run).
# Every command's output is kept in a log directory, printed at the end.
# Exit code: the number of failed tests (0 = all passed).
#
# Adding a lesson: write a function test_NN (NN = lesson number) using the helpers below,
# and add NN to ALL_LESSONS.

ALL_LESSONS=(22 23)

usage() {
	sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'
	exit "${1:-0}"
}

REBUILD=false
BUILD=true
INSTALL=true
REINSTALL=false
VENV=${NAVIGATOR_VENV:-$HOME/navigator}
SELECTED=()
for arg in "$@"; do
	case $arg in
		--rebuild)  REBUILD=true ;;
		--no-build) BUILD=false ;;
		--no-install) INSTALL=false ;;
		--reinstall) REINSTALL=true ;;
		-h|--help)  usage ;;
		[0-9][0-9]) SELECTED+=("$arg") ;;
		*)          echo "Unknown argument: $arg"; usage 1 ;;
	esac
done
[ ${#SELECTED[@]} -eq 0 ] && SELECTED=("${ALL_LESSONS[@]}")

# Always work relative to this script: labenv/../lessons
cd "$(dirname "$0")/../lessons" || exit 1
LESSONS_DIR=$(pwd)
LOGDIR=$(mktemp -d /tmp/test_lessons.XXXXXX)

# The lab containers (ansible, host1..3) are rootful: reach them with sudo if not root
if [ "$(id -u)" -eq 0 ]; then LABPODMAN=(podman); else LABPODMAN=(sudo -n podman); fi

if [ -t 1 ]; then
	G=$'\e[32m'; R=$'\e[31m'; Y=$'\e[33m'; B=$'\e[1m'; N=$'\e[0m'
else
	G=""; R=""; Y=""; B=""; N=""
fi

PASS=0; FAIL=0; SKIP=0; WARN=0
FAILED=()
CURRENT=""
COUNT=0
LASTLOG=""

#################################################################
# Helpers
#################################################################

section() { CURRENT=$1; printf "\n${B}== %s ==${N}\n" "$1"; }
pass()    { PASS=$((PASS+1)); printf "  ${G}PASS${N}  %s\n" "$1"; }
skip()    { SKIP=$((SKIP+1)); printf "  ${Y}SKIP${N}  %s\n" "$1"; }
warn()    { WARN=$((WARN+1)); printf "  ${Y}WARN${N}  %s\n" "$1"; }
fail() {
	FAIL=$((FAIL+1)); FAILED+=("$CURRENT: $1")
	printf "  ${R}FAIL${N}  %s\n" "$1"
	[ -n "${2:-}" ] && printf "        ${Y}hint:${N} %s\n" "$2"
	return 0
}
show_tail() { [ -f "$LASTLOG" ] && tail -n 8 "$LASTLOG" | sed 's/^/        | /'; }

# run CMD... : run a command, output into a new log file ($LASTLOG), return its exit code
run() {
	COUNT=$((COUNT+1))
	LASTLOG=$(printf "%s/%03d.log" "$LOGDIR" "$COUNT")
	echo "\$ $*" >"$LASTLOG"
	"$@" >>"$LASTLOG" 2>&1
}

# check NAME HINT CMD... : PASS if CMD succeeds
check() {
	local name=$1 hint=$2; shift 2
	if run "$@"; then pass "$name"; return 0; fi
	fail "$name" "$hint"; show_tail; return 1
}

# check_output NAME REGEX HINT CMD... : PASS if CMD succeeds and its output matches REGEX
check_output() {
	local name=$1 regex=$2 hint=$3; shift 3
	if run "$@" && grep -Eq -- "$regex" "$LASTLOG"; then pass "$name"; return 0; fi
	fail "$name" "$hint"; show_tail; return 1
}

# check_fails NAME REGEX CMD... : PASS if CMD fails (an expected failure) and its output matches REGEX
check_fails() {
	local name=$1 regex=$2; shift 2
	if ! run "$@" && grep -Eq -- "$regex" "$LASTLOG"; then pass "$name"; return 0; fi
	fail "$name" "expected a failure mentioning: $regex"; show_tail; return 1
}

# log_has NAME REGEX : PASS if the output of the previous command matches REGEX
log_has() {
	if grep -Eq -- "$2" "$LASTLOG"; then pass "$1"; else fail "$1"; show_tail; fi
}

image_exists() { podman image exists "$1"; }

# build_ee DIR NAME:TAG : build the EE of DIR as localhost/NAME:TAG if missing (or --rebuild)
build_ee() {
	local dir=$1 tag=$2
	if image_exists "localhost/$tag" && ! $REBUILD; then
		pass "image localhost/$tag present (no build, use --rebuild to force)"
	elif ! $BUILD; then
		skip "build of localhost/$tag (--no-build)"
	else
		printf "  ....  building localhost/%s in %s, this takes a few minutes\n" "$tag" "$dir"
		check "ansible-builder build -t $tag" \
			"read the log; base image / PyPI / galaxy reachable through the proxy?" \
			bash -c "cd '$dir' && ansible-builder build -t '$tag' -v 2"
	fi
}

#################################################################
# ansible-navigator and ansible-builder with pip, in a venv
#################################################################

# find_python MINOR: print the newest python3.x on the PATH with x >= MINOR
find_python() {
	local py
	for py in python3.13 python3.12 python3.11 python3.10 python3.9 python3; do
		if command -v "$py" >/dev/null 2>&1 &&
		   "$py" -c "import sys; sys.exit(sys.version_info < (3, $1))" 2>/dev/null; then
			echo "$py"
			return 0
		fi
	done
	return 1
}

test_install() {
	section "ansible-navigator and ansible-builder (pip, venv $VENV)"

	if ! $INSTALL; then
		pass "--no-install: using ansible-navigator from the PATH"
		return 0
	fi

	if [ -x "$VENV/bin/ansible-navigator" ] && ! $REINSTALL; then
		# shellcheck disable=SC1091
		source "$VENV/bin/activate"
		pass "venv present, activated (use --reinstall to recreate it)"
		return 0
	fi

	local py
	if py=$(find_python 10); then
		pass "Python for the venv: $py ($("$py" --version 2>&1))"
	elif py=$(find_python 9); then
		warn "only $py ($("$py" --version 2>&1)): pip installs an older ansible-navigator (current needs 3.10+)"
	else
		fail "no Python >= 3.9 found" \
			"RHEL 9: sudo dnf install python3.12 ; RHEL 8: sudo dnf install python3.11 (8.8+) or python39"
		return 1
	fi

	if $REINSTALL && [ -d "$VENV" ]; then
		rm -rf "$VENV"
	fi
	check "create venv $VENV" "is the python venv module installed?" "$py" -m venv "$VENV" || return 1
	# shellcheck disable=SC1091
	source "$VENV/bin/activate"
	check "upgrade pip in the venv" "PyPI reachable? proxy set (HTTPS_PROXY)?" \
		python -m pip install --upgrade pip || return 1
	printf "  ....  pip install ansible-navigator ansible-builder, this takes a minute\n"
	check "pip install ansible-navigator ansible-builder" "PyPI reachable? proxy set (HTTPS_PROXY)?" \
		python -m pip install --upgrade ansible-navigator ansible-builder || return 1
	return 0
}

#################################################################
# Prerequisites (lab VM)
#################################################################

test_prereq() {
	section "Prerequisites on the lab VM"

	local cmd ok=true
	for cmd in podman ansible-navigator ansible-builder ssh; do
		if command -v "$cmd" >/dev/null 2>&1; then
			pass "$cmd found: $(command -v "$cmd")"
		else
			fail "$cmd not found" "install ansible-navigator in a venv, see 22_Navigator/README.md#installation"
			ok=false
		fi
	done
	$ok || return 1

	check_output "ansible-navigator runs" "ansible-navigator" "" ansible-navigator --version

	local driver
	driver=$(podman info --format '{{.Store.GraphDriverName}}' 2>/dev/null)
	if [ "$driver" = "overlay" ]; then
		pass "podman storage driver: overlay"
	else
		warn "podman storage driver: ${driver:-unknown} (not overlay: EE builds will be very slow)"
	fi

	local port
	for port in 2021 2022 2023; do
		if timeout 3 bash -c "</dev/tcp/127.0.0.1/$port" 2>/dev/null; then
			pass "Managed Host ssh port 127.0.0.1:$port open"
		else
			fail "Managed Host ssh port 127.0.0.1:$port closed" "start the lab with labenv/run.sh"
		fi
	done
	return 0
}

#################################################################
# Lesson 22: ansible-navigator
#################################################################

test_22() {
	section "22_Navigator"
	cd "$LESSONS_DIR/22_Navigator" || { fail "lesson directory missing"; return; }

	check "settings file ansible-navigator.yml is valid" "" \
		ansible-navigator settings --effective

	# Without an EE: the Playbook runs on the lab VM itself
	rm -f /tmp/whereami.txt
	check_output "whereami.yml without EE (--ee false)" "ansible-core:" "" \
		ansible-navigator run whereami.yml --ee false
	if [ -f /tmp/whereami.txt ]; then
		pass "--ee false: /tmp/whereami.txt written on the lab VM"
	else
		fail "--ee false: /tmp/whereami.txt missing on the lab VM"
	fi

	# In an EE: localhost is the container, nothing is left on the lab VM
	rm -f /tmp/whereami.txt
	check_output "whereami.yml in community-ee-minimal" "ansible-core:" \
		"can the VM pull ghcr.io/ansible-community/community-ee-minimal:latest?" \
		ansible-navigator run whereami.yml
	if [ ! -f /tmp/whereami.txt ]; then
		pass "in the EE: /tmp/whereami.txt NOT written on the lab VM"
	else
		fail "in the EE: /tmp/whereami.txt appeared on the lab VM"
	fi

	# Credentials: key login to the Managed Hosts, ssh-agent
	local port
	for port in 2021 2022 2023; do
		check "ssh key login devops@127.0.0.1:$port" \
			"ssh-copy-id -p $port devops@127.0.0.1   (password: devops)" \
			ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
			    -o ConnectTimeout=5 -p "$port" devops@127.0.0.1 true
	done
	if ssh-add -l >/dev/null 2>&1; then
		pass "ssh-agent running with a key"
	else
		warn "no ssh-agent with a key (eval \$(ssh-agent); ssh-add): the EE may not get the key"
	fi

	check_output "ping.yml in the EE reaches host1..host3" "host3 \(port 2023\) says" \
		"ssh-agent? SELinux (add --security-opt=label=disable to container-options)? ssh client in the image?" \
		ansible-navigator run ping.yml

	# report.yml needs community.general + jmespath: fails in the minimal EE ...
	check_fails "report.yml fails in community-ee-minimal (expected)" "json_query|community\.general" \
		ansible-navigator run report.yml

	# ... and works in our own EE
	build_ee "$LESSONS_DIR/22_Navigator/ee" "lab-ee:1.0"
	if image_exists localhost/lab-ee:1.0; then
		check_output "lab-ee contains ansible-core 2.18" "core 2\.18" "" \
			podman run --rm localhost/lab-ee:1.0 ansible --version
		check_output "lab-ee contains community.general" "community\.general" "" \
			podman run --rm localhost/lab-ee:1.0 ansible-galaxy collection list community.general
		check "lab-ee contains jmespath" "" \
			podman run --rm localhost/lab-ee:1.0 python3.12 -c "import jmespath"
		check_output "report.yml succeeds in lab-ee" "host1" "" \
			ansible-navigator run report.yml --eei localhost/lab-ee:1.0 --pp never
		check "ansible-navigator doc json_query from lab-ee" "" \
			ansible-navigator doc community.general.json_query -t filter --eei localhost/lab-ee:1.0 --pp never
	else
		skip "lab-ee tests (image localhost/lab-ee:1.0 missing)"
	fi

	if ls artifacts/*-artifact-*.json >/dev/null 2>&1; then
		pass "playbook artifacts saved in artifacts/ ($(ls artifacts/*.json | wc -l) files)"
	else
		fail "no playbook artifacts in artifacts/" "check playbook-artifact in ansible-navigator.yml"
	fi
}

#################################################################
# Lesson 23: Execution Environments
#################################################################

test_23() {
	section "23_ExecutionEnvironments"
	cd "$LESSONS_DIR/23_ExecutionEnvironments" || { fail "lesson directory missing"; return; }

	# Exercise 1 runs in the Control Node container (only the smoke test, nothing is installed)
	local lesson=/home/devops/ansible/lessons/23_ExecutionEnvironments
	if ! "${LABPODMAN[@]}" container exists ansible 2>/dev/null; then
		skip "versions.yml on the Control Node (container 'ansible' not running, or no sudo)"
	elif ! "${LABPODMAN[@]}" exec -u devops ansible test -d "$lesson" 2>/dev/null; then
		skip "versions.yml on the Control Node (lesson not in the container's clone: push it, then git pull there)"
	else
		check_output "versions.yml on the Control Node (Exercise 1)" "ansible-core:" "" \
			"${LABPODMAN[@]}" exec -u devops -w "$lesson" ansible ansible-playbook versions.yml
		log_has "Control Node sees a packaged community.general" "community\.general"
	fi

	# Exercise 2: two teams, two EEs
	build_ee "$LESSONS_DIR/23_ExecutionEnvironments/team-a-ee" "team-a-ee:1.0"
	build_ee "$LESSONS_DIR/23_ExecutionEnvironments/team-b-ee" "team-b-ee:1.0"

	if image_exists localhost/team-a-ee:1.0; then
		check_output "team-a-ee runs as a plain container: ansible-core 2.16" "core 2\.16" "" \
			podman run --rm localhost/team-a-ee:1.0 ansible --version
		check_output "versions.yml in team-a-ee: ansible-core 2.16" "ansible-core: +2\.16" "" \
			ansible-navigator run versions.yml --eei localhost/team-a-ee:1.0 --pp never
		log_has "team-a-ee sees community.general 8.x" "community\.general +8\."
	else
		skip "team-a-ee tests (image localhost/team-a-ee:1.0 missing)"
	fi

	if image_exists localhost/team-b-ee:1.0; then
		check_output "team-b-ee runs as a plain container: ansible-core 2.18" "core 2\.18" "" \
			podman run --rm localhost/team-b-ee:1.0 ansible --version
		check_output "versions.yml in team-b-ee: ansible-core 2.18" "ansible-core: +2\.18" "" \
			ansible-navigator run versions.yml --eei localhost/team-b-ee:1.0 --pp never
		log_has "team-b-ee sees community.general 10.x" "community\.general +10\."
		check "team-b-ee contains jmespath" "" \
			podman run --rm localhost/team-b-ee:1.0 python3.12 -c "import jmespath"
		check_output "default image of ansible-navigator.yml is team-b-ee" "ansible-core: +2\.18" "" \
			ansible-navigator run versions.yml
	else
		skip "team-b-ee tests (image localhost/team-b-ee:1.0 missing)"
	fi
}

#################################################################
# Main
#################################################################

printf "${B}Lesson tests:${N} %s   (logs: %s)\n" "${SELECTED[*]}" "$LOGDIR"

if test_install && test_prereq; then
	for lesson in "${SELECTED[@]}"; do
		if declare -F "test_$lesson" >/dev/null; then
			"test_$lesson"
		else
			section "Lesson $lesson"
			skip "no tests for lesson $lesson in this script"
		fi
	done
else
	printf "\n${R}Prerequisites missing, lesson tests not run.${N}\n"
fi

printf "\n${B}== Summary ==${N}\n"
printf "  ${G}%d passed${N}, ${R}%d failed${N}, ${Y}%d skipped, %d warnings${N}\n" "$PASS" "$FAIL" "$SKIP" "$WARN"
for f in "${FAILED[@]}"; do printf "  ${R}x${N} %s\n" "$f"; done
printf "  Logs of every command: %s\n" "$LOGDIR"

exit "$FAIL"
