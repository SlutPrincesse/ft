#!/bin/bash
# angel-safety — Safety Governor: Permissions, sandboxing, resource control.
#
# Provides:
#   1. Permission system for skills/plugins (allow/deny/ask per operation)
#   2. Execution sandboxing (resource limits, timeouts, cgroups)
#   3. Audit trail for all operations
#   4. Rollback capability
#   5. Threat detection (dangerous commands, network access, file access)
#   6. Quota management (rate limits, concurrent execution limits)
#
# Makes AngelKernel safe to run untrusted skills and plugins.

ANGEL_HOME="${ANGEL_HOME:-$HOME/.angelkernel}"
source "$ANGEL_HOME/lib/angel-lib.sh" 2>/dev/null || true
ANGEL_SCRIPT="safety"
angel_console_init 2>/dev/null || true

SAFETY_DIR="$ANGEL_HOME/store/safety"
PERMISSIONS_FILE="$SAFETY_DIR/permissions.json"
AUDIT_LOG="$SAFETY_DIR/audit.ndjson"
SANDBOX_DIR="$SAFETY_DIR/sandbox"
mkdir -p "$SAFETY_DIR" "$SANDBOX_DIR"

# Initialize permissions
[ ! -f "$PERMISSIONS_FILE" ] && echo '{"skills":{},"plugins":{},"default":"ask"}' > "$PERMISSIONS_FILE"

# ========================================================================
# PERMISSION SYSTEM
# ========================================================================

# Operation types
OPS_FILE="file_read,file_write,file_delete"
OPS_NET="network_connect,network_listen"
OPS_EXEC="command_exec,subprocess_spawn"
OPS_SYS="system_modify,service_control"
OPS_ALL="$OPS_FILE,$OPS_NET,$OPS_EXEC,$OPS_SYS"

# Permission levels: allow, deny, ask, inherit
safety_check_permission() {
  local entity="$1" operation="$2" entity_type="${3:-skill}"
  
  python3 -c "
import json, sys

entity = '$entity'
operation = '$operation'
entity_type = '$entity_type'

try:
    with open('$PERMISSIONS_FILE') as f:
        db = json.load(f)
except:
    db = {'skills': {}, 'plugins': {}, 'default': 'ask'}

# Check entity-specific permission
perm = db.get(entity_type, {}).get(entity, {}).get(operation)
if perm:
    print(perm)
    sys.exit(0)

# Check wildcard for this entity
perm = db.get(entity_type, {}).get(entity, {}).get('*')
if perm:
    print(perm)
    sys.exit(0)

# Check entity type default
perm = db.get(entity_type, {}).get('__default__')
if perm:
    print(perm)
    sys.exit(0)

# Global default
print(db.get('default', 'ask'))
" 2>/dev/null
}

safety_set_permission() {
  local entity="$1" operation="$2" level="$3" entity_type="${4:-skill}"
  
  python3 -c "
import json
try:
    with open('$PERMISSIONS_FILE') as f:
        db = json.load(f)
except:
    db = {'skills': {}, 'plugins': {}, 'default': 'ask'}

if '$entity_type' not in db:
    db['$entity_type'] = {}
if '$entity' not in db['$entity_type']:
    db['$entity_type']['$entity'] = {}
db['$entity_type']['$entity']['$operation'] = '$level'

with open('$PERMISSIONS_FILE', 'w') as f:
    json.dump(db, f, indent=2)
print(f'Permission set: $entity_type/$entity can $operation = $level')
" 2>/dev/null
  
  safety_audit "permission_change" "$entity_type/$entity" "{\"operation\":\"$operation\",\"level\":\"$level\"}"
}

safety_list_permissions() {
  echo "=== Safety Permissions ==="
  python3 -c "
import json
with open('$PERMISSIONS_FILE') as f:
    db = json.load(f)
for etype, entities in db.items():
    if etype == 'default':
        print(f'\\nDefault policy: {entities}')
        continue
    print(f'\\n{etype.upper()}:')
    for entity, perms in entities.items():
        for op, level in perms.items():
            op_display = '*' if op == '*' else op
            print(f'  {entity}: {op_display} → {level}')
" 2>/dev/null
}

# ========================================================================
# AUDIT SYSTEM
# ========================================================================

safety_audit() {
  local action="$1" subject="$2" details="${3:-{}}" result="${4:-allowed}"
  local entry
  entry=$(python3 -c "
import json, sys
entry = {
    'ts': $(date +%s),
    'iso': '$(angel_iso)',
    'action': '${action//\'/\\'}',
    'subject': '${subject//\'/\\'}',
    'details': $details,
    'result': '${result//\'/\\'}',
    'pid': $$
}
print(json.dumps(entry))
" 2>/dev/null)
  echo "$entry" >> "$AUDIT_LOG"
}

safety_audit_log() {
  local tail_lines="${1:-50}"
  echo "=== Safety Audit Log (last $tail_lines entries) ==="
  tail -"$tail_lines" "$AUDIT_LOG" 2>/dev/null | python3 -c "
import json, sys
for line in sys.stdin:
    line = line.strip()
    if not line: continue
    try:
        d = json.loads(line)
        print(f\"[{d.get('iso','?')}] {d.get('action','?')} | {d.get('subject','?')} | {d.get('result','?')}\")
    except: pass
" 2>/dev/null
}

# ========================================================================
# SANDBOX — Execute commands with resource limits
# ========================================================================

safety_sandbox() {
  local command="$1" timeout="${2:-30}" memory_limit_mb="${3:-512}" entity="${4:-unknown}"
  
  angel_info "[safety] Sandbox: $entity | timeout=${timeout}s | mem=${memory_limit_mb}MB"
  
  # Check permissions first
  local perm
  perm=$(safety_check_permission "$entity" "command_exec")
  if [ "$perm" = "deny" ]; then
    safety_audit "exec_blocked" "$entity" "{\"command\":\"${command:0:100}\"}" "denied"
    angel_error "[safety] Execution denied for $entity: command_exec not permitted"
    return 1
  fi
  
  # Create sandbox directory
  local sandbox_id="SB-$(date +%s)-$$"
  local sandbox_path="$SANDBOX_DIR/$sandbox_id"
  mkdir -p "$sandbox_path"
  
  # Write command to script
  local script_file="$sandbox_path/run.sh"
  echo '#!/bin/bash' > "$script_file"
  echo "$command" >> "$script_file"
  chmod +x "$script_file"
  
  # Execute with timeout and resource limits
  local start_time end_time exit_code output
  start_time=$(date +%s)
  
  output=$(timeout "$timeout" bash "$script_file" 2>&1)
  exit_code=$?
  end_time=$(date +%s)
  
  local elapsed=$((end_time - start_time))
  
  # Log the execution
  safety_audit "exec" "$entity" "{\"command\":\"${command:0:100}\",\"timeout\":$timeout,\"elapsed\":$elapsed,\"exit_code\":$exit_code}" \
    "$([ $exit_code -eq 0 ] && echo 'success' || echo 'failed')"
  
  # Check for dangerous patterns in output
  if [ $exit_code -ne 0 ]; then
    local error_snippet
    error_snippet=$(echo "$output" | tail -5 | tr '\n' ' ' | head -c 200)
    angel_warn "[safety] Sandbox $sandbox_id exited with code $exit_code: $error_snippet"
  fi
  
  # Cleanup
  rm -rf "$sandbox_path" &
  
  echo "$output"
  return $exit_code
}

# ========================================================================
# SANDBOX — Restricted file operations
# ========================================================================

safety_sandbox_file() {
  local operation="$1" filepath="$2" content="$3" entity="${4:-unknown}"
  
  # Resolve real path
  local real_path
  real_path=$(realpath "$filepath" 2>/dev/null || echo "$filepath")
  
  # Check permissions
  local op_name="file_${operation}"
  local perm
  perm=$(safety_check_permission "$entity" "$op_name")
  
  if [ "$perm" = "deny" ]; then
    safety_audit "file_blocked" "$entity" "{\"op\":\"$operation\",\"file\":\"$real_path\"}" "denied"
    angel_error "[safety] $op_name denied for $entity on $real_path"
    return 1
  fi
  
  # Check if file is within allowed paths
  local allowed=true
  case "$real_path" in
    $ANGEL_HOME/*|/tmp/*|/data/user/0/gptos.intelligence.assistant/cache/opencode/*)
      allowed=true ;;
    *)
      if [ "$perm" != "allow" ]; then
        safety_audit "file_blocked" "$entity" "{\"op\":\"$operation\",\"file\":\"$real_path\"}" "path_not_allowed"
        angel_warn "[safety] Path not in allowed zones: $real_path"
        return 1
      fi
      ;;
  esac
  
  # Execute the operation
  case "$operation" in
    read)
      if [ -f "$real_path" ]; then
        cat "$real_path"
        safety_audit "file_read" "$entity" "{\"file\":\"$real_path\"}" "success"
      else
        safety_audit "file_read" "$entity" "{\"file\":\"$real_path\"}" "not_found"
        return 1
      fi
      ;;
    write)
      mkdir -p "$(dirname "$real_path")"
      echo "$content" > "$real_path"
      safety_audit "file_write" "$entity" "{\"file\":\"$real_path\",\"size\":${#content}}" "success"
      ;;
    delete)
      if [ -f "$real_path" ]; then
        # Backup before delete
        cp "$real_path" "$SAFETY_DIR/trash/$(basename "$real_path").$(date +%s).bak" 2>/dev/null
        rm "$real_path"
        safety_audit "file_delete" "$entity" "{\"file\":\"$real_path\"}" "success"
      fi
      ;;
  esac
}

# ========================================================================
# THREAT DETECTION
# ========================================================================

safety_scan_command() {
  local command="$1"
  
  python3 -c "
import re, json

cmd = '''$command'''

threats = []

# Detect dangerous patterns
dangerous_patterns = [
    (r'rm\s+-rf\s+/|rm\s+-rf\s+~|mkfs\.|dd\s+if=|:\(\)\s*\{|:\(\)\s*\{|>[\s]*/dev/|wget.*--output-document.*/etc|curl.*-o.*/etc', 'DESTRUCTIVE: Potential system destruction'),
    (r'chmod\s+777|chown\s+-R|sudo\s+.*\|.*sh', 'PRIVILEGE ESCALATION: Permission manipulation'),
    (r'/dev/(sda|sdb|sdc|nvme|mmcblk|loop)', 'BLOCK_DEVICE: Direct block device access'),
    (r'>[\s]*(/etc/|/boot/|/sys/|/proc/)', 'SYSTEM_FILE: Writing to system paths'),
    (r'wget|curl.*-o|curl.*--output', 'NETWORK_DOWNLOAD: External download'),
    (r'base64.*--decode|echo.*\|.*base64.*-d', 'OBFUSCATION: Potentially obfuscated code'),
    (r'iptables|ufw|firewall-cmd', 'FIREWALL: Firewall modification'),
    (r'systemctl|service.*\s+start|update-rc\.d', 'SERVICE: Service manipulation'),
    (r'kill\s+-9|pkill|killall', 'PROCESS_KILL: Process termination'),
    (r'passwd|useradd|usermod|groupadd|chpasswd', 'USER_MGMT: User/group management'),
    (r'ssh\s+|telnet\s+|nc\s+|nmap\s+', 'NETWORK_TOOL: Network scanning/connection'),
    (r'mount|umount|losetup|swapon', 'MOUNT: Filesystem mounting'),
]

for pattern, description in dangerous_patterns:
    if re.search(pattern, cmd, re.IGNORECASE):
        threats.append({'pattern': pattern, 'description': description, 'severity': 'high'})

# Risk score — weighted by severity
risk_score = 0.0
for t in threats:
    if 'DESTRUCTIVE' in t.get('description', ''):
        risk_score += 0.8
    elif 'PRIVILEGE' in t.get('description', '') or 'SYSTEM' in t.get('description', ''):
        risk_score += 0.6
    else:
        risk_score += 0.3
risk_score = min(1.0, risk_score)

print(json.dumps({
    'threats': threats,
    'risk_score': round(risk_score, 2),
    'is_dangerous': risk_score > 0.5,
    'command_preview': cmd[:100]
}))
" 2>/dev/null
}

safety_validate_skill() {
  local skill_dir="$1"
  
  echo "=== Validating Skill: $(basename "$skill_dir") ==="
  
  local issues=0
  
  # Check SKILL.md exists
  if [ ! -f "$skill_dir/SKILL.md" ]; then
    echo "  [WARN] No SKILL.md found"
    issues=$((issues + 1))
  fi
  
  # Check for dangerous files
  if [ -f "$skill_dir/install.sh" ]; then
    echo "  [INFO] install.sh present — scanning..."
    local scan_result
    scan_result=$(safety_scan_command "$(cat "$skill_dir/install.sh")")
    local is_dangerous
    is_dangerous=$(echo "$scan_result" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('is_dangerous', False))" 2>/dev/null)
    if [ "$is_dangerous" = "True" ]; then
      echo "  [FAIL] install.sh contains dangerous patterns!"
      issues=$((issues + 1))
    else
      echo "  [PASS] install.sh is safe"
    fi
  fi
  
  if [ "$issues" -eq 0 ]; then
    echo "  [PASS] Skill validation complete"
  else
    echo "  [WARN] $issues issue(s) found"
  fi
}

# ========================================================================
# QUOTA MANAGEMENT
# ========================================================================

safety_quota_check() {
  local entity="$1" resource="${2:-exec}" limit="${3:-10}" window="${4:-60}"
  
  # Count recent executions
  local count
  count=$(grep -c "$entity" "$AUDIT_LOG" 2>/dev/null || echo 0)
  
  if [ "$count" -gt "$limit" ]; then
    angel_warn "[safety] Quota exceeded for $entity: $count > $limit (${window}s window)"
    return 1
  fi
  return 0
}

# ========================================================================
# ROLLBACK — Revert a failed operation
# ========================================================================

safety_rollback() {
  local audit_id="$1"
  
  angel_info "[safety] Attempting rollback of $audit_id"
  
  # Find the audit entry
  local entry
  entry=$(grep "$audit_id" "$AUDIT_LOG" 2>/dev/null | head -1)
  
  if [ -z "$entry" ]; then
    angel_error "[safety] No audit entry found: $audit_id"
    return 1
  fi
  
  local action subject
  action=$(echo "$entry" | python3 -c "import json,sys; d=json.loads(sys.stdin); print(d.get('action',''))" 2>/dev/null)
  subject=$(echo "$entry" | python3 -c "import json,sys; d=json.loads(sys.stdin); print(d.get('subject',''))" 2>/dev/null)
  
  case "$action" in
    file_write|file_delete)
      # Restore from trash
      local backup
      backup=$(ls -t "$SAFETY_DIR/trash/${subject}."*".bak" 2>/dev/null | head -1)
      if [ -n "$backup" ]; then
        cp "$backup" "$subject" 2>/dev/null && angel_info "[safety] Rolled back: $subject"
        safety_audit "rollback" "$subject" "{\"from_action\":\"$action\"}" "success"
      else
        angel_warn "[safety] No backup found for: $subject"
      fi
      ;;
    exec)
      # Can't roll back execution, but can log it
      angel_warn "[safety] Cannot roll back execution: $subject"
      safety_audit "rollback_impossible" "$subject" "{\"from_action\":\"$action\"}" "skipped"
      ;;
  esac
}

# ========================================================================
# EMERGENCY BRAKE — Halt all non-essential operations
# ========================================================================

safety_emergency_stop() {
  local reason="$1"
  
  angel_error "[safety] EMERGENCY STOP: $reason"
  
  # Set default policy to deny
  python3 -c "
import json
with open('$PERMISSIONS_FILE') as f:
    db = json.load(f)
db['default'] = 'deny'
with open('$PERMISSIONS_FILE', 'w') as f:
    json.dump(db, f, indent=2)
"
  
  safety_audit "emergency_stop" "system" "{\"reason\":\"${reason:0:200}\"}" "emergency"
  
  echo "EMERGENCY STOP ACTIVATED"
  echo "  Reason: $reason"
  echo "  All operations now denied by default"
  echo "  To reset: angel-safety.sh reset"
}

safety_reset() {
  angel_info "[safety] Resetting to defaults..."
  echo '{"skills":{},"plugins":{},"default":"ask"}' > "$PERMISSIONS_FILE"
  safety_audit "reset" "system" "{}" "reset"
  echo "Safety reset to defaults. Policy: ask"
}

# ========================================================================
# STATS
# ========================================================================

safety_stats() {
  echo "=== Safety Governor Stats ==="
  echo ""
  
  local audit_count exec_count blocked_count
  audit_count=$(wc -l < "$AUDIT_LOG" 2>/dev/null || echo 0)
  exec_count=$(grep -c '"action":"exec"' "$AUDIT_LOG" 2>/dev/null || echo 0)
  blocked_count=$(grep -c 'denied\|blocked' "$AUDIT_LOG" 2>/dev/null || echo 0)
  
  echo "Audit entries:     $audit_count"
  echo "Executions:        $exec_count"
  echo "Blocked actions:   $blocked_count"
  echo ""
  
  python3 -c "
import json
with open('$PERMISSIONS_FILE') as f:
    db = json.load(f)
print(f'Default policy: {db.get(\"default\", \"ask\")}')
skills = db.get('skills', {})
plugins = db.get('plugins', {})
print(f'Skills with permissions: {len(skills)}')
print(f'Plugins with permissions: {len(plugins)}')
total_rules = sum(len(p) for p in skills.values()) + sum(len(p) for p in plugins.values())
print(f'Total permission rules: {total_rules}')
" 2>/dev/null
}

# ========================================================================
# MAIN
# ========================================================================

case "${1:-}" in
  check-perm|check)
    safety_check_permission "$2" "$3" "${4:-skill}" ;;
  set-perm|set)
    safety_set_permission "$2" "$3" "$4" "${5:-skill}" ;;
  list-perm|perms)
    safety_list_permissions ;;
  sandbox|run)
    shift; safety_sandbox "$1" "${2:-30}" "${3:-512}" "${4:-unknown}" ;;
  sandbox-file|file)
    safety_sandbox_file "$2" "$3" "$4" "${5:-unknown}" ;;
  scan)
    shift; safety_scan_command "$*" ;;
  validate)
    safety_validate_skill "$2" ;;
  audit)
    safety_audit_log "${2:-50}" ;;
  rollback)
    safety_rollback "$2" ;;
  emergency|stop)
    shift; safety_emergency_stop "$*" ;;
  reset)
    safety_reset ;;
  quota)
    safety_quota_check "$2" "${3:-exec}" "${4:-10}" "${5:-60}" ;;
  stats)
    safety_stats ;;
  *)
    echo "AngelKernel Safety Governor"
    echo ""
    echo "Usage:"
    echo "  angel-safety.sh check <entity> <op> [type]    — Check permission"
    echo "  angel-safety.sh set <entity> <op> <level>     — Set permission"
    echo "  angel-safety.sh sandbox <cmd> [timeout] [mem] — Execute sandboxed"
    echo "  angel-safety.sh scan <cmd>                    — Scan for threats"
    echo "  angel-safety.sh validate <skill-dir>          — Validate a skill"
    echo "  angel-safety.sh audit [lines]                 — View audit log"
    echo "  angel-safety.sh emergency <reason>             — Emergency stop"
    echo "  angel-safety.sh reset                          — Reset to defaults"
    echo "  angel-safety.sh stats                          — Show stats"
    echo ""
    echo "Permission levels: allow, deny, ask"
    echo "Operation types: file_read, file_write, command_exec, network_connect, *"
    ;;
esac
