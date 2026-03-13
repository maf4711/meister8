#!/bin/bash
# ==============================================================================
# meister2026.sh
#
# macOS Maintenance, Update & Self-Healing Script
# Version: 0.04
# Stand: 2026-03-12
#
# NEU in v0.04:
#  105. BUG: module_git_repos() haengt bei Repos mit langsamen Remotes
#       → timeout 5 vor alle git-Netzwerk-Befehle (remote, rev-parse upstream, log, push)
#  106. BUG: date +%s%N funktioniert nicht auf macOS → perl/gdate Fallback
#  107. BUG: git status --porcelain 2x aufgerufen → gecacht
#  108. BUG: Versionsnummern Banner/Report "v0.01" statt "v0.03" korrigiert
#  109. PERFORMANCE: strip_think_tags() 2 sed → 1 sed (Fork gespart)
#  110. PERFORMANCE: ps -eo in module_performance gecacht (5 Forks → 1)
#  111. PERFORMANCE: wc -l | xargs durch $(wc -l < ...) ersetzt (~30 xargs Forks gespart)
#  112. PERFORMANCE: log() Timestamp via printf statt date-Fork (~200+ Forks gespart)
#  113. PERFORMANCE: module_homebrew parallel outdated checks (2s gespart)
#  114. PERFORMANCE: check_net() parallelisiert (bis 6s gespart bei Fehler)
#
# NEU in v0.03:
#  101. GIT: Unpushed Repos finden + automatisch pushen (-G Flag)
#  102. GIT: Backup aller Repos als tar.gz nach iCloud Drive
#  103. GIT: Alte Backups nach GIT_BACKUP_RETENTION_DAYS aufräumen
#  104. CONFIG: GIT_AUTO_PUSH, GIT_BACKUP_DIR, GIT_BACKUP_EXCLUDE etc.
#
# NEU in v0.02:
#   94. PERFORMANCE: Memory-Hogs aktiv killen (PERF_KILL_HOGS, Whitelist)
#   95. PERFORMANCE: Alle Login Items entfernen (PERF_CLEAN_LOGIN_ITEMS)
#   96. PERFORMANCE: Unnoetige LaunchAgents deaktivieren (PERF_DISABLE_AGENTS)
#   97. PERFORMANCE: Unbenutzte Ollama-Modelle loeschen (PERF_CLEAN_OLLAMA)
#   98. PERFORMANCE: RAM Purge nach Cleanup (PERF_RAM_PURGE)
#   99. CONFIG: OLLAMA_KEEP_MODELS, PERF_KILL_WHITELIST, PERF_DISABLE_AGENT_PATTERNS
#  100. PERFORMANCE: 12 → 16 Sub-Module im Performance-Modul
#
# NEU in v0.01:
#   54-67. DEEPCLEAN: 14 Module (Logs, Downloads, Orphans, Plists, Mail,
#          Screenshots, TM-Snapshots, RAM, LaunchServices, Spotlight,
#          Recent Items, Duplikate, iOS-Backups, Login Items)
#   68. BUG: run_verbose PIPESTATUS Subshell-Bug → tmpfile
#   69. BUG: TM-Snapshot Parsing (falscher awk-Feld-Index)
#   70. BUG: mdfind Injection in Login-Items (Sonderzeichen escaped)
#   71. BUG: Unquoted $fsize in Berechnungen → ${fsize:-0}
#   72. DEEPCLEAN: npm/pip/yarn/gem Caches aufraumen
#   73. DEEPCLEAN: CocoaPods/SPM/Carthage Caches
#   74. DEEPCLEAN: Docker Container/Images/Volumes prunen
#   75. DEEPCLEAN: Parallels VM-Logs (>30 Tage)
#   76. DEEPCLEAN: Font-Cache + QuickLook-Cache rebuild
#   77. DEEPCLEAN: Quarantine-Attribute entfernen (xattr)
#   78. CONFIG: Deep-Clean-Module schaltbar (CLEAN_PKG_CACHES etc.)
#   79. HILFE: Erweiterte Hilfe mit Beispielen und Moduluebersicht
#   80. REPORT: Gesamt-Speicher-Summary (MB/GB freigegeben)
#   81. SICHERHEIT: safe_exec_lines Whitelist verschaerft (killall etc.)
#   82. PERFORMANCE: Plist-Linting parallelisiert (xargs -P 4)
#   83. PERFORMANCE: Config-Parsing ohne sed (Shell Parameter-Expansion)
#   84. PERFORMANCE: get_system_context() gecacht (einmaliger Aufruf)
#   85. PERFORMANCE: Orphaned Prefs via mdfind-Batch statt einzeln (~50-100s gespart)
#   86. PERFORMANCE: Quarantine-Entfernung parallelisiert (xargs -P 8)
#   87. PERFORMANCE: vm_stat/ioreg/curl Batch-Aufrufe im Benchmark
#   88. PERFORMANCE: XProtect-Version via pkgutil statt system_profiler (~10s)
#   89. PERFORMANCE: ollama list gecacht (1x statt mehrfach)
#   90. PERFORMANCE: safe_exec_lines sed durch Parameter-Expansion
#   91. PERFORMANCE: Log ANSI-Strip nur bei Bedarf (spart ~95% der sed-Forks)
#   92. PERFORMANCE: Login Items tote-Erkennung via Batch-mdfind
#   93. macOS PERFORMANCE MODUL: DNS, TCP, Kernel, TRIM/SMART, Spotlight,
#       Memory/CPU-Hogs, WindowServer, Swap, Services, GUI, Power (-P Flag)
#
# NEU in v12.0:
#   53. BENCHMARK: Taeglicher System-Benchmark mit historischem Vergleich
#       - CPU (Pi-Berechnung), Disk I/O (256MB R/W), Netzwerk (Latenz+Speed)
#       - RAM/Swap/Memory-Pressure, Load Average, Thermal, Battery
#       - Security-Audit: FileVault, Firewall, Gatekeeper, SIP, XProtect
#       - JSON-Export (~/.meister/benchmarks/YYYY-MM-DD.json)
#       - Automatischer Vergleich mit letztem Lauf + Degradation-Warnungen
#       - Max 1x/24h, alte Benchmarks nach 90 Tagen aufgeraeumt
#
# NEU in v11.0:
#   31. SICHERHEIT: eval durch /bin/bash -c ersetzt in safe_exec_lines
#   32. SICHERHEIT: Pipe/Chain-Blocker (;, &&, ||, |) in AI-Commands
#   33. SICHERHEIT: Config-Werte numerisch validiert
#   34. run_verbose: PIPESTATUS statt tmpfile Race-Condition
#   35. Trap-Vereinheitlichung: ein cleanup fuer INT/TERM/EXIT
#   36. Log-Rotation: 3 Generationen statt nur .old
#   37. -a Flag: Alle optionalen Module auf einmal
#   38. Exit-Code 1 bei Errors
#   39. ClamAV: Array statt eval fuer exclude_args
#   40. Magic Numbers als benannte Konstanten
#   41. Doppelter Ollama-Startcode in ensure_ollama_running() vereint
#   42. brew doctor Re-check nur nach tatsaechlichen Auto-Fixes
#   43. mas account Check vor Update
#   44. Sprache vereinheitlicht (Deutsch)
#   45. OLLAMA: Modell-Verfuegbarkeit pruefen + Auto-Pull/Fallback
#   46. OLLAMA: Konfigurierbarer Query-Timeout + Cold-Start-Erkennung
#   47. OLLAMA: Einmaliger Retry bei Query-Fehler
#   48. OLLAMA: Erweiterter Prompt mit macOS-/Chip-/Brew-Version
#   49. OLLAMA: Hash-basierter Query-Cache (gleiche Fehler nicht nochmal)
#   50. OLLAMA: Fehlerbehandlung in ollama_summary
#   51. OLLAMA: Query-Statistik (Anzahl, Dauer, Erfolge)
#   52. OLLAMA: qwen3-coder <think>-Tags rausfiltern
#
# NEU in v10.0:
#   22. brew doctor Auto-Fix (unlinked kegs, autoremove, Ollama-Fallback)
#   23. brew autoremove nach upgrade
#   24. MS Office: Sicherheitsrichtlinien-Check (MDM, MAU-Channel, TCC)
#   25. MS Office: Automatischer Retry nach Timeout
#   26. softwareupdate --install --recommended (auto-install)
#   27. Log-Analyse: Wiederkehrende Warnings erkennen
#   28. terminal-notifier mit Fallback auf osascript
#   29. Pushover-Benachrichtigung (optional via Config)
#   30. LaunchAgent Self-Setup (-I Flag)
#
# FIXES vs v9.0:
#   17. OLLAMA_MODEL Default auf llama3:latest (llama3.1:8b war nicht installiert)
#   18. ollama_query: Response-JSON mit tr bereinigen (Ollama liefert ungueltige
#       Control-Chars die jq/python3 crashen)
#   19. safe_exec_lines: AI-Response-Bereinigung (Markdown/Erklaerungen rausfiltern)
#   20. sudo-Whitelist erweitert: brew, mv, scutil hinzugefuegt
#   21. Blocklist-Regex: rm -rf / ohne Trailing-Char wird jetzt erkannt
#
# FIXES vs v8.0:
#   1.  eval durch safe_exec_lines ersetzt (Whitelist + Blocklist)
#   2.  Prompt-Injection-Schutz: sanitize_for_prompt()
#   3.  JSON-Building: jq bevorzugt, python3 mit argv statt stdin
#   4.  Pipe-Exit-Codes korrekt via run_verbose() Helper
#   5.  Subshell-Counter-Bug in module_ollama gefixt
#   6.  Stderr-Capture: Logfile-Diff statt leerer stderr-Datei
#   7.  Dead Code entfernt (RETRY_COUNT, RETRY_DELAY)
#   8.  Lockfile gegen parallele Instanzen
#   9.  Signal-Handling (trap) fuer sauberes Cleanup
#   10. Dry-Run-Modus (-n Flag)
#   11. Netzwerk-Check mit mehreren Endpunkten
#   12. brew --greedy statt --force
#   13. Config-Datei (~/.meister/config)
#   14. Logfile nach ~/.meister/meister.log verschoben
#   15. ClamAV: bessere Exclude-Patterns
#   16. Run-History in ~/.meister/history.log
#
# Usage: ./meister2026.sh [flags]
#   -a  ALLE optionalen Module    -A  ClamAV (sudo)
#   -X  Xcode clean               -M  Monolingual
#   -T  Trash leeren              -S  Sudo tasks
#   -C  Caches (sudo)             -L  Grosse Dateien
#   -O  LM Studio sync            -c  NUR ClamAV
#   -H  Health Dashboard          -n  Dry-Run
#   -I  LaunchAgent install       -h  Hilfe
# ==============================================================================

#############################
# 1. CONFIGURATION
#############################

MEISTER_DIR="$HOME/.meister"
mkdir -p "$MEISTER_DIR/patches" "$MEISTER_DIR/output" 2>/dev/null

# Defaults
LOGFILE="$MEISTER_DIR/meister.log"
LOCKFILE="$MEISTER_DIR/meister.lock"
MSUPDATE_PATH="/Library/Application Support/Microsoft/MAU2.0/Microsoft AutoUpdate.app/Contents/MacOS/msupdate"
DISK_USAGE_THRESHOLD=80
LARGE_FILE_SIZE_MB=1000
MSUPDATE_TIMEOUT=120
OLLAMA_URL="${OLLAMA_URL:-http://localhost:11434}"
OLLAMA_MODEL="${OLLAMA_MODEL:-qwen3-coder:30b}"
OLLAMA_FALLBACK_MODEL="llama3:latest"
OLLAMA_ENABLED=true
OLLAMA_QUERY_TIMEOUT=120
OLLAMA_QUERY_RETRIES=1
SELFHEAL_MAX_RETRIES=2
NET_CHECK_HOSTS="google.com apple.com cloudflare.com"
PUSHOVER_USER=""
PUSHOVER_TOKEN=""
REPORT_NOTIFY="local"
LAUNCHAGENT_SCHEDULE="weekly"

# Fix #78: Deep Clean Config-Gating (via ~/.meister/config steuerbar)
CLEAN_PKG_CACHES=true         # npm/pip/yarn/gem Caches
CLEAN_DEV_CACHES=true         # CocoaPods/SPM/Carthage
CLEAN_DOCKER=false            # Docker Prune (default: aus, Sicherheit)
CLEAN_PARALLELS_LOGS=true     # Parallels VM-Logs
CLEAN_FONT_CACHE=true         # Font-Cache + QuickLook-Cache
CLEAN_QUARANTINE=true         # xattr Quarantine entfernen

# Fix #93: macOS Performance-Optimierung (via ~/.meister/config steuerbar)
PERF_DNS_OPTIMIZE=true        # DNS auf Cloudflare/Google setzen
PERF_SYSCTL_TUNE=true         # TCP-Buffer/Kernel-Limits optimieren
PERF_GUI_REDUCE=false          # GUI-Animationen reduzieren (default: aus, kosmetisch)
PERF_SERVICE_AUDIT=true        # Schwere Hintergrund-Dienste erkennen
PERF_SPOTLIGHT_EXCLUDE=true    # Dev-Verzeichnisse von Spotlight ausschliessen
PERF_KILL_HOGS=true            # Schwere User-Prozesse beenden (>RAM-Schwelle)
PERF_KILL_THRESHOLD_MB=500     # Prozesse ueber diesem RAM-Verbrauch killen
PERF_CLEAN_LOGIN_ITEMS=true    # Alle Login Items entfernen
PERF_DISABLE_AGENTS=true       # Unnoetige User LaunchAgents deaktivieren
PERF_CLEAN_OLLAMA=true         # Unbenutzte Ollama-Modelle loeschen
PERF_RAM_PURGE=true            # sudo purge nach Cleanup ausfuehren
OLLAMA_KEEP_MODELS="qwen3-coder:30b llama3.2:latest"  # Modelle die behalten werden

# Git Repo Management (via -G Flag aktiviert)
GIT_AUTO_PUSH=true                          # Unpushed Commits automatisch pushen
GIT_BACKUP_ENABLED=true                     # Repos als tar.gz nach iCloud sichern
GIT_REPO_SEARCH_PATHS="$HOME/Documents $HOME/Projekte"  # Suchpfade fuer Repos
GIT_REPO_MAXDEPTH=5                         # Max Tiefe fuer Repo-Suche
GIT_BACKUP_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Backups/GitRepos"
GIT_BACKUP_RETENTION_DAYS=30                # Alte Backups nach X Tagen loeschen
GIT_BACKUP_EXCLUDE="node_modules .next dist build .nuxt .output __pycache__ .venv venv .build DerivedData Pods .gradle .cache"

# Whitelist: Prozesse die NIE gekillt werden (Teilmatch auf Prozessname)
PERF_KILL_WHITELIST="iTerm2 Terminal Finder Dock SystemUIServer loginwindow WindowServer kernel_task claude meister launchd sshd"

# LaunchAgents die deaktiviert werden sollen (Teilmatch auf plist-Name)
PERF_DISABLE_AGENT_PATTERNS="com.google.GoogleUpdater com.google.keystone com.macpaw.CleanMyMac com.bluebubbles.server com.heald.daemon"

# Benannte Konstanten (Fix #40)
LOG_MAX_SIZE=1048576          # 1MB - Log-Rotation Schwelle
LOG_GENERATIONS=3             # Anzahl rotierter Logs
OLLAMA_STARTUP_WAIT=15        # Sekunden Warten auf Ollama-Server
LOG_CAPTURE_LINES=50          # Zeilen fuer Fehleranalyse aus Log
SAFE_CMD_MAX_LEN=500          # Max Laenge eines AI-Fix-Befehls
DISK_CRITICAL_THRESHOLD=95    # Prozent - Notfall-Cleanup Schwelle
OLLAMA_COLD_START_EXTRA=60    # Extra-Sekunden beim ersten Query (Modell-Load)

# Config-Datei laden (ueberschreibt Defaults)
MEISTER_CONFIG="$MEISTER_DIR/config"
if [ -f "$MEISTER_CONFIG" ]; then
    while IFS='=' read -r key value; do
        # Fix #83: Parameter-Expansion statt sed (4 Forks gespart pro Zeile)
        key="${key#"${key%%[![:space:]]*}"}"
        key="${key%"${key##*[![:space:]]}"}"
        value="${value#"${value%%[![:space:]]*}"}"
        value="${value%"${value##*[![:space:]]}"}"
        [ -z "$key" ] && continue
        [ "${key:0:1}" = "#" ] && continue
        # Fix #33: Numerische Werte validieren
        case "$key" in
            OLLAMA_MODEL)          OLLAMA_MODEL="$value" ;;
            OLLAMA_FALLBACK_MODEL) OLLAMA_FALLBACK_MODEL="$value" ;;
            OLLAMA_URL)            OLLAMA_URL="$value" ;;
            OLLAMA_QUERY_TIMEOUT)  [[ "$value" =~ ^[0-9]+$ ]] && OLLAMA_QUERY_TIMEOUT="$value" ;;
            OLLAMA_QUERY_RETRIES)  [[ "$value" =~ ^[0-9]+$ ]] && OLLAMA_QUERY_RETRIES="$value" ;;
            MSUPDATE_TIMEOUT)      [[ "$value" =~ ^[0-9]+$ ]] && MSUPDATE_TIMEOUT="$value" ;;
            DISK_USAGE_THRESHOLD)  [[ "$value" =~ ^[0-9]+$ ]] && DISK_USAGE_THRESHOLD="$value" ;;
            LARGE_FILE_SIZE_MB)    [[ "$value" =~ ^[0-9]+$ ]] && LARGE_FILE_SIZE_MB="$value" ;;
            SELFHEAL_MAX_RETRIES)  [[ "$value" =~ ^[0-9]+$ ]] && SELFHEAL_MAX_RETRIES="$value" ;;
            NET_CHECK_HOSTS)       NET_CHECK_HOSTS="$value" ;;
            PUSHOVER_USER)         PUSHOVER_USER="$value" ;;
            PUSHOVER_TOKEN)        PUSHOVER_TOKEN="$value" ;;
            REPORT_NOTIFY)         [[ "$value" =~ ^(local|pushover|all|none)$ ]] && REPORT_NOTIFY="$value" ;;
            LAUNCHAGENT_SCHEDULE)  [[ "$value" =~ ^(daily|weekly|monthly)$ ]] && LAUNCHAGENT_SCHEDULE="$value" ;;
            CLEAN_PKG_CACHES)      [[ "$value" =~ ^(true|false)$ ]] && CLEAN_PKG_CACHES="$value" ;;
            CLEAN_DEV_CACHES)      [[ "$value" =~ ^(true|false)$ ]] && CLEAN_DEV_CACHES="$value" ;;
            CLEAN_DOCKER)          [[ "$value" =~ ^(true|false)$ ]] && CLEAN_DOCKER="$value" ;;
            CLEAN_PARALLELS_LOGS)  [[ "$value" =~ ^(true|false)$ ]] && CLEAN_PARALLELS_LOGS="$value" ;;
            CLEAN_FONT_CACHE)      [[ "$value" =~ ^(true|false)$ ]] && CLEAN_FONT_CACHE="$value" ;;
            CLEAN_QUARANTINE)      [[ "$value" =~ ^(true|false)$ ]] && CLEAN_QUARANTINE="$value" ;;
            PERF_DNS_OPTIMIZE)     [[ "$value" =~ ^(true|false)$ ]] && PERF_DNS_OPTIMIZE="$value" ;;
            PERF_SYSCTL_TUNE)      [[ "$value" =~ ^(true|false)$ ]] && PERF_SYSCTL_TUNE="$value" ;;
            PERF_GUI_REDUCE)       [[ "$value" =~ ^(true|false)$ ]] && PERF_GUI_REDUCE="$value" ;;
            PERF_SERVICE_AUDIT)    [[ "$value" =~ ^(true|false)$ ]] && PERF_SERVICE_AUDIT="$value" ;;
            PERF_SPOTLIGHT_EXCLUDE) [[ "$value" =~ ^(true|false)$ ]] && PERF_SPOTLIGHT_EXCLUDE="$value" ;;
            PERF_KILL_HOGS)        [[ "$value" =~ ^(true|false)$ ]] && PERF_KILL_HOGS="$value" ;;
            PERF_KILL_THRESHOLD_MB) [[ "$value" =~ ^[0-9]+$ ]] && PERF_KILL_THRESHOLD_MB="$value" ;;
            PERF_CLEAN_LOGIN_ITEMS) [[ "$value" =~ ^(true|false)$ ]] && PERF_CLEAN_LOGIN_ITEMS="$value" ;;
            PERF_DISABLE_AGENTS)   [[ "$value" =~ ^(true|false)$ ]] && PERF_DISABLE_AGENTS="$value" ;;
            PERF_CLEAN_OLLAMA)     [[ "$value" =~ ^(true|false)$ ]] && PERF_CLEAN_OLLAMA="$value" ;;
            PERF_RAM_PURGE)        [[ "$value" =~ ^(true|false)$ ]] && PERF_RAM_PURGE="$value" ;;
            OLLAMA_KEEP_MODELS)    OLLAMA_KEEP_MODELS="$value" ;;
            PERF_KILL_WHITELIST)   PERF_KILL_WHITELIST="$value" ;;
            PERF_DISABLE_AGENT_PATTERNS) PERF_DISABLE_AGENT_PATTERNS="$value" ;;
            GIT_AUTO_PUSH)         [[ "$value" =~ ^(true|false)$ ]] && GIT_AUTO_PUSH="$value" ;;
            GIT_BACKUP_ENABLED)    [[ "$value" =~ ^(true|false)$ ]] && GIT_BACKUP_ENABLED="$value" ;;
            GIT_REPO_SEARCH_PATHS) GIT_REPO_SEARCH_PATHS="$value" ;;
            GIT_REPO_MAXDEPTH)     [[ "$value" =~ ^[0-9]+$ ]] && GIT_REPO_MAXDEPTH="$value" ;;
            GIT_BACKUP_DIR)        GIT_BACKUP_DIR="$value" ;;
            GIT_BACKUP_RETENTION_DAYS) [[ "$value" =~ ^[0-9]+$ ]] && GIT_BACKUP_RETENTION_DAYS="$value" ;;
            GIT_BACKUP_EXCLUDE)    GIT_BACKUP_EXCLUDE="$value" ;;
        esac
    done < "$MEISTER_CONFIG"
fi

# Report Arrays
declare -a REPORT_SUCCESS
declare -a REPORT_FIXED
declare -a REPORT_WARNINGS
declare -a REPORT_ERRORS
declare -a REPORT_HEALED
MSUPDATE_OUTPUT_LOG=""
SCRIPT_START_TIME=$(date +%s)

# Fix #51: Ollama Query-Statistik (dateibasiert wg. Subshell-Problem)
OLLAMA_STATS_FILE="$MEISTER_DIR/output/ollama_stats_$$.dat"
OLLAMA_COLD_START=true

# Fix #84/#89: Gecachte Werte (einmaliger Aufruf, spart wiederholte Forks)
_SYSTEM_CONTEXT_CACHE=""
_OLLAMA_LIST_CACHE=""

mkdir -p "$MEISTER_DIR/cache" 2>/dev/null
echo "0 0 0 0 0" > "$OLLAMA_STATS_FILE"

# Statistik-Helfer (atomar, Subshell-sicher)
ollama_stat_inc() {
    local field="$1" amount="${2:-1}"
    local counts
    read -r c_count c_ok c_fail c_cached c_secs < "$OLLAMA_STATS_FILE"
    case "$field" in
        count)  c_count=$((c_count + amount)) ;;
        ok)     c_ok=$((c_ok + amount)) ;;
        fail)   c_fail=$((c_fail + amount)) ;;
        cached) c_cached=$((c_cached + amount)) ;;
        secs)   c_secs=$((c_secs + amount)) ;;
    esac
    echo "$c_count $c_ok $c_fail $c_cached $c_secs" > "$OLLAMA_STATS_FILE"
}

ollama_stat_read() {
    cat "$OLLAMA_STATS_FILE" 2>/dev/null || echo "0 0 0 0 0"
}
MODULE_STEP=0
MODULE_TOTAL=0
SUDO_KEEPALIVE_PID=""
INTERRUPTED=false

# Flags
RUN_CLAMAV=false
CLEAN_XCODE=false
RUN_MONOLINGUAL=false
EMPTY_TRASH=false
RUN_SUDO_TASKS=false
CLEAN_CACHES=false
LIST_LARGE_FILES=false
RUN_LMSTUDIO_COPY=false
CLAMAV_ONLY=false
NEEDS_SUDO=false
SHOW_HEALTH=false
DRY_RUN=false
INSTALL_LAUNCHAGENT=false
RUN_PERF_TUNE=false
RUN_GIT_REPOS=false

#############################
# 2. CORE HELPERS & LOGGING
#############################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Fix #112: Timestamp-Cache spart ~200+ date-Forks pro Lauf
_LOG_TS_CACHE=""
_LOG_TS_SEC=-1

log() {
    local level="$1"; shift; local msg="$*"
    # Timestamp nur neu berechnen wenn sich die Sekunde aendert ($SECONDS ist builtin, kein Fork)
    if [ "$SECONDS" != "$_LOG_TS_SEC" ]; then
        _LOG_TS_CACHE=$(date +'%Y-%m-%d %H:%M:%S')
        _LOG_TS_SEC=$SECONDS
    fi
    local ts="$_LOG_TS_CACHE"
    local color=$NC
    case "$level" in
        INFO)  color=$GREEN ;;
        WARN)  color=$YELLOW ;;
        ERROR) color=$RED ;;
        FIX)   color=$CYAN ;;
        HEAL)  color=$MAGENTA ;;
        STEP)  color=$DIM ;;
    esac
    echo -e "${color}[${level}]${NC} ${msg}"
    # Fix #91: ANSI-Strip nur wenn noetig (spart sed-Fork in ~95% der Aufrufe)
    if [[ "$msg" == *$'\033'* ]]; then
        echo "$ts - $level - $(echo "$msg" | sed 's/\x1b\[[0-9;]*m//g')" >> "$LOGFILE"
    else
        echo "$ts - $level - $msg" >> "$LOGFILE"
    fi
}

section_header() {
    local title="$1"
    MODULE_STEP=$((MODULE_STEP + 1))
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  [${MODULE_STEP}/${MODULE_TOTAL}] ${BOLD}${title}${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

module_timer_start() {
    MODULE_START_TS=$(date +%s)
}

module_timer_stop() {
    local name="$1"
    local end_ts=$(date +%s)
    local elapsed=$((end_ts - MODULE_START_TS))
    local mins=$((elapsed / 60))
    local secs=$((elapsed % 60))
    if [ $mins -gt 0 ]; then
        log STEP "   ${name} abgeschlossen in ${mins}m ${secs}s"
    else
        log STEP "   ${name} abgeschlossen in ${secs}s"
    fi
}

report_add() {
    local type="$1"; local msg="$2"
    case "$type" in
        SUCCESS) REPORT_SUCCESS+=("$msg") ;;
        FIX)     REPORT_FIXED+=("$msg") ;;
        WARN)    REPORT_WARNINGS+=("$msg") ;;
        ERROR)   REPORT_ERRORS+=("$msg") ;;
        HEALED)  REPORT_HEALED+=("$msg") ;;
    esac
}

command_exists() { command -v "$1" &> /dev/null; }

rotate_logs() {
    if [ -f "$LOGFILE" ]; then
        local size=$(stat -f%z "$LOGFILE" 2>/dev/null || echo 0)
        if [ "$size" -gt "$LOG_MAX_SIZE" ]; then
            # Fix #36: Nummerierte Rotation (3 Generationen)
            local i=$((LOG_GENERATIONS - 1))
            while [ $i -ge 1 ]; do
                [ -f "${LOGFILE}.$i" ] && mv "${LOGFILE}.$i" "${LOGFILE}.$((i + 1))"
                i=$((i - 1))
            done
            [ -f "${LOGFILE}.old" ] && mv "${LOGFILE}.old" "${LOGFILE}.1"
            mv "$LOGFILE" "${LOGFILE}.old"
            log INFO "Logfile rotiert (war $(( size / 1024 ))KB)"
        fi
    fi
    touch "$LOGFILE"
}

# Fuehrt Befehl aus, zeigt Output zeilenweise, gibt echten Exit-Code zurueck
# Fix #68: tmpfile statt PIPESTATUS (Subshell-Bug vermieden)
run_verbose() {
    if $DRY_RUN; then
        log STEP "   [DRY-RUN] $*"
        return 0
    fi
    local tmpout
    tmpout=$(mktemp)
    "$@" > "$tmpout" 2>&1
    local rc=$?
    while IFS= read -r line; do
        [ -n "$line" ] && log STEP "   $line"
    done < "$tmpout"
    rm -f "$tmpout"
    return $rc
}

# Einfacher Dry-Run-Wrapper ohne Output-Streaming
run_or_dry() {
    if $DRY_RUN; then
        log STEP "   [DRY-RUN] $*"
        return 0
    fi
    "$@"
}

# Fix #8: Lockfile
acquire_lock() {
    if [ -f "$LOCKFILE" ]; then
        local old_pid=$(cat "$LOCKFILE" 2>/dev/null)
        if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
            log ERROR "Meister laeuft bereits (PID: $old_pid)"
            exit 1
        else
            log WARN "Stale Lockfile entfernt (PID $old_pid nicht mehr aktiv)"
            rm -f "$LOCKFILE"
        fi
    fi
    echo $$ > "$LOCKFILE"
}

release_lock() {
    rm -f "$LOCKFILE" 2>/dev/null
}

# Fix #35: Vereinheitlichter Trap fuer INT/TERM/EXIT
cleanup() {
    if $INTERRUPTED; then return; fi
    INTERRUPTED=true
    # Bei Signal (nicht normalem Exit) Report ausgeben
    if [ -n "$CLEANUP_SIGNAL" ]; then
        echo ""
        log WARN "Script unterbrochen ($CLEANUP_SIGNAL), raeume auf..."
        print_report 2>/dev/null
        save_history 2>/dev/null
    fi
    [ -n "$SUDO_KEEPALIVE_PID" ] && kill "$SUDO_KEEPALIVE_PID" 2>/dev/null
    rm -f "$MEISTER_DIR/output"/*_$$.log "$OLLAMA_STATS_FILE" 2>/dev/null
    release_lock
}

trap 'CLEANUP_SIGNAL=INT; cleanup' INT
trap 'CLEANUP_SIGNAL=TERM; cleanup' TERM
trap 'cleanup' EXIT

#############################
# 3. OLLAMA SELF-HEALING
#############################

ollama_available() {
    [ "$OLLAMA_ENABLED" = "true" ] && curl -sf --max-time 5 "${OLLAMA_URL}/api/tags" >/dev/null 2>&1
}

# Fix #41: Zentraler Ollama-Starter (ersetzt doppelten Code in module_ollama + main)
ensure_ollama_running() {
    local context="${1:-}"  # optionaler Kontext fuer Log-Meldungen
    if ollama_available; then
        return 0
    fi
    if ! command_exists ollama; then
        return 1
    fi
    log WARN "${context}Ollama offline - starte Server..."
    ollama serve &>/dev/null &
    local ollama_pid=$!
    local wait_count=0
    while [ $wait_count -lt "$OLLAMA_STARTUP_WAIT" ]; do
        sleep 1
        wait_count=$((wait_count + 1))
        if curl -sf --max-time 2 "${OLLAMA_URL}/api/tags" >/dev/null 2>&1; then
            break
        fi
        [ $((wait_count % 5)) -eq 0 ] && log STEP "${context}   Warte auf Ollama-Server... (${wait_count}s)"
    done
    if ollama_available; then
        log FIX "${context}Ollama-Server gestartet (nach ${wait_count}s)"
        OLLAMA_ENABLED=true
        return 0
    else
        log WARN "${context}Ollama-Server antwortet nicht nach ${OLLAMA_STARTUP_WAIT}s"
        if kill -0 "$ollama_pid" 2>/dev/null; then
            log STEP "${context}   Prozess laeuft (PID: $ollama_pid) aber API nicht erreichbar"
        else
            log WARN "${context}   Ollama-Prozess sofort beendet"
            local ollama_log="$HOME/.ollama/logs/server.log"
            if [ -f "$ollama_log" ]; then
                log STEP "${context}   Letzte Logzeilen:"
                tail -5 "$ollama_log" 2>/dev/null | while IFS= read -r line; do
                    log STEP "${context}     $line"
                done
            fi
        fi
        OLLAMA_ENABLED=false
        return 1
    fi
}

# Fix #45: Modell-Verfuegbarkeit pruefen, Auto-Pull oder Fallback
ensure_ollama_model() {
    if ! ollama_available; then return 1; fi
    local model="$OLLAMA_MODEL"
    # Modellname ohne Tag fuer grep (z.B. "qwen3-coder" aus "qwen3-coder:30b")
    if ollama_list_cached | awk 'NR>1 {print $1}' | grep -q "^${model}$"; then
        log STEP "   Modell $model verfuegbar"
        return 0
    fi
    # Modell nicht vorhanden - versuche Auto-Pull
    log WARN "   Modell $model nicht lokal verfuegbar, starte Pull..."
    if ollama pull "$model" 2>/dev/null; then
        ollama_list_invalidate
        log FIX "   Modell $model erfolgreich heruntergeladen"
        report_add FIX "Ollama: Modell $model auto-pulled"
        return 0
    fi
    # Pull fehlgeschlagen - Fallback-Modell pruefen
    if [ -n "$OLLAMA_FALLBACK_MODEL" ] && [ "$OLLAMA_FALLBACK_MODEL" != "$model" ]; then
        if ollama_list_cached | awk 'NR>1 {print $1}' | grep -q "^${OLLAMA_FALLBACK_MODEL}$"; then
            log WARN "   Fallback auf $OLLAMA_FALLBACK_MODEL (statt $model)"
            OLLAMA_MODEL="$OLLAMA_FALLBACK_MODEL"
            report_add WARN "Ollama: Fallback auf $OLLAMA_FALLBACK_MODEL"
            return 0
        fi
    fi
    # Letzter Versuch: erstes verfuegbares Modell nehmen
    local first_model=$(ollama_list_cached | awk 'NR==2 {print $1}')
    if [ -n "$first_model" ]; then
        log WARN "   Fallback auf erstes verfuegbares Modell: $first_model"
        OLLAMA_MODEL="$first_model"
        report_add WARN "Ollama: Fallback auf $first_model"
        return 0
    fi
    log ERROR "   Kein Ollama-Modell verfuegbar"
    OLLAMA_ENABLED=false
    return 1
}

# Fix #89: ollama list gecacht (wird nur 1x abgefragt)
ollama_list_cached() {
    if [ -z "$_OLLAMA_LIST_CACHE" ]; then
        _OLLAMA_LIST_CACHE=$(ollama list 2>/dev/null)
    fi
    echo "$_OLLAMA_LIST_CACHE"
}
# Cache invalidieren (z.B. nach pull)
ollama_list_invalidate() {
    _OLLAMA_LIST_CACHE=""
}

# Fix #2: Prompt-Injection-Schutz
sanitize_for_prompt() {
    local input="$1"
    local max_len="${2:-1000}"
    # Kontrollzeichen entfernen, Laenge begrenzen, gefaehrliche Shell-Zeichen strippen
    echo "$input" | tr -cd '[:print:]\n' | head -c "$max_len" | sed 's/[`]//g'
}

# Fix #52/#109: qwen3-coder <think>-Tags entfernen (1 sed statt 2 → Fork gespart)
strip_think_tags() {
    sed -e '/<think>/,/<\/think>/d' -e 's/<think>[^<]*<\/think>//g'
}

# Fix #49: Hash-basierter Query-Cache
ollama_cache_key() {
    local prompt="$1"
    # MD5-Hash des Prompts als Cache-Key
    echo "$prompt" | md5 2>/dev/null || echo "$prompt" | md5sum 2>/dev/null | awk '{print $1}'
}

ollama_cache_get() {
    local hash="$1"
    local cache_file="$MEISTER_DIR/cache/${hash}"
    # Cache gueltig fuer 24 Stunden
    if [ -f "$cache_file" ]; then
        local cache_age=$(( $(date +%s) - $(stat -f%m "$cache_file" 2>/dev/null || echo 0) ))
        if [ "$cache_age" -lt 86400 ]; then
            cat "$cache_file"
            return 0
        fi
        rm -f "$cache_file"
    fi
    return 1
}

ollama_cache_set() {
    local hash="$1"
    local response="$2"
    echo "$response" > "$MEISTER_DIR/cache/${hash}" 2>/dev/null
}

# Interner Query ohne Retry/Cache/Stats (wird von ollama_query aufgerufen)
_ollama_raw_query() {
    local prompt="$1"
    local timeout="$2"
    local json_payload

    if command_exists jq; then
        json_payload=$(jq -n \
            --arg model "$OLLAMA_MODEL" \
            --arg prompt "$prompt" \
            '{model: $model, prompt: $prompt, stream: false, options: {temperature: 0.1, num_predict: 512}}')
    elif command_exists python3; then
        json_payload=$(python3 -c "
import sys, json
print(json.dumps({
    'model': sys.argv[1],
    'prompt': sys.stdin.read(),
    'stream': False,
    'options': {'temperature': 0.1, 'num_predict': 512}
}))" "$OLLAMA_MODEL" <<< "$prompt" 2>/dev/null)
    else
        log WARN "Kein jq oder python3 fuer JSON-Encoding verfuegbar"
        return 1
    fi

    [ -z "$json_payload" ] && return 1

    local response
    response=$(curl -sf --max-time "$timeout" "${OLLAMA_URL}/api/generate" \
        -H "Content-Type: application/json" \
        -d "$json_payload" 2>/dev/null)

    [ $? -ne 0 ] || [ -z "$response" ] && return 1

    # Fix #18: Ollama JSON-Bereinigung + Fix #52: think-Tags entfernen
    local parsed
    if command_exists jq; then
        parsed=$(echo "$response" | awk '{if(NR>1) printf "\\n"; printf "%s", $0}' | jq -r '.response // ""')
    else
        parsed=$(echo "$response" | awk '{if(NR>1) printf "\\n"; printf "%s", $0}' | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('response',''))" 2>/dev/null)
    fi

    # Fix #52: <think>-Tags rausfiltern (qwen3-coder)
    echo "$parsed" | strip_think_tags
}

# Fix #46/#47/#49/#51: Ollama Query mit Timeout, Retry, Cache und Statistik
ollama_query() {
    local prompt="$1"
    local use_cache="${2:-true}"
    ollama_stat_inc count

    # Fix #49: Cache pruefen
    if [ "$use_cache" = "true" ]; then
        local cache_hash=$(ollama_cache_key "$prompt")
        local cached_result
        if cached_result=$(ollama_cache_get "$cache_hash"); then
            ollama_stat_inc cached
            ollama_stat_inc ok
            log STEP "   (Cache-Hit)" >&2
            echo "$cached_result"
            return 0
        fi
    fi

    # Fix #46: Timeout berechnen (Cold-Start beruecksichtigen)
    local timeout="$OLLAMA_QUERY_TIMEOUT"
    if $OLLAMA_COLD_START; then
        timeout=$((timeout + OLLAMA_COLD_START_EXTRA))
        log STEP "   Cold-Start: Timeout ${timeout}s (normal: ${OLLAMA_QUERY_TIMEOUT}s)" >&2
    fi

    local query_start=$(date +%s)
    local result

    # Erster Versuch
    result=$(_ollama_raw_query "$prompt" "$timeout")
    local rc=$?

    # Fix #47: Retry bei Fehler
    if [ $rc -ne 0 ] && [ "$OLLAMA_QUERY_RETRIES" -gt 0 ]; then
        log WARN "   Ollama-Query fehlgeschlagen, Retry..." >&2
        sleep 2
        result=$(_ollama_raw_query "$prompt" "$timeout")
        rc=$?
    fi

    local query_end=$(date +%s)
    local query_dur=$((query_end - query_start))
    ollama_stat_inc secs "$query_dur"

    # Nach erstem erfolgreichen Query: Cold-Start abschalten
    if [ $rc -eq 0 ] && [ -n "$result" ]; then
        OLLAMA_COLD_START=false
        ollama_stat_inc ok

        # Cache speichern
        if [ "$use_cache" = "true" ]; then
            ollama_cache_set "$cache_hash" "$result"
        fi

        echo "$result"
        return 0
    fi

    ollama_stat_inc fail
    log WARN "   Ollama-Query endgueltig fehlgeschlagen (${query_dur}s)" >&2
    return 1
}

# Fix #48: System-Info fuer bessere Prompts sammeln
# Fix #84: Gecacht - wird nur beim ersten Aufruf berechnet
get_system_context() {
    if [ -n "$_SYSTEM_CONTEXT_CACHE" ]; then
        echo "$_SYSTEM_CONTEXT_CACHE"
        return
    fi
    local macos_ver=$(sw_vers -productVersion 2>/dev/null || echo "unbekannt")
    local chip=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "unbekannt")
    local brew_ver=$(brew --version 2>/dev/null | head -1 || echo "unbekannt")
    local bash_ver=$(/bin/bash --version 2>/dev/null | head -1 | sed 's/.*version //' | sed 's/ .*//')
    _SYSTEM_CONTEXT_CACHE="SYSTEM: macOS ${macos_ver}, ${chip}, Homebrew ${brew_ver}, Bash ${bash_ver}"
    echo "$_SYSTEM_CONTEXT_CACHE"
}

selfheal_analyze() {
    local module_name="$1"
    local error_output="$2"
    local exit_code="$3"

    # Fix #2: Fehlertext sanitizen
    local safe_error=$(sanitize_for_prompt "$error_output" 800)

    # Fix #48: Erweiterte System-Info
    local sys_ctx=$(get_system_context)

    local prompt="Du bist ein macOS System-Administrator. Ein Wartungsscript-Modul ist fehlgeschlagen.

MODUL: ${module_name}
EXIT CODE: ${exit_code}
FEHLER:
${safe_error}

${sys_ctx}

Liefere NUR den Fix-Befehl (Shell-Commands, eine pro Zeile).
Keine Erklaerungen. Kein Markdown. Keine <think>-Tags. Muss ohne Interaktion laufen.
Erlaubte Befehle: brew, git, sudo, xcode-select, dscacheutil, killall, rm, mkdir, cp, mv, defaults, softwareupdate, mas, ollama.
Wenn kein Fix moeglich: nur NOFIX"

    ollama_query "$prompt"
}

# Fix #31: /bin/bash -c statt eval, Fix #32: Pipe/Chain-Blocker
safe_exec_lines() {
    local fix_cmd="$1"
    local module_name="$2"
    local blocked=false
    local tmpscript=$(mktemp)
    local rc=0

    # Zeile fuer Zeile validieren
    while IFS= read -r line; do
        # Fix #90: Parameter-Expansion statt sed (2 Forks gespart pro Zeile)
        local stripped="${line#"${line%%[![:space:]]*}"}"
        stripped="${stripped%"${stripped##*[![:space:]]}"}"
        [ -z "$stripped" ] && continue
        [ "${stripped:0:1}" = "#" ] && continue
        # Fix #19: AI-Response-Bereinigung - Markdown und Erklaerungen rausfiltern
        echo "$stripped" | grep -qiE '^(```|here |the |this |note:|warning:|these )' && continue
        # Nummern-Praefixe entfernen (Ollama liefert "1. sudo rm ...")
        # Fix #90: Nummern-Praefixe ohne sed entfernen
        if [[ "$stripped" =~ ^[0-9]+\.[[:space:]]*(.*) ]]; then
            stripped="${BASH_REMATCH[1]}"
        fi
        [ -z "$stripped" ] && continue

        # Laengen-Check
        if [ ${#stripped} -gt "$SAFE_CMD_MAX_LEN" ]; then
            log ERROR "BLOCKED: Zeile zu lang (${#stripped} Zeichen)"
            blocked=true
            break
        fi

        # Fix #32: Pipe/Chain-Blocker - keine verketteten Befehle
        if echo "$stripped" | grep -qE '[;|&]{1,2}'; then
            log ERROR "BLOCKED: Pipe/Chain in Befehl: $stripped"
            blocked=true
            break
        fi

        # Erweiterte Blocklist (Patterns)
        if echo "$stripped" | grep -qiE \
            'rm -rf /($|[^A-Za-z~.])|mkfs|dd if=|chmod -R 777 /|> /dev/|eval |exec [^-]|base64|curl.*sh|wget.*sh|python.*-c.*import os|osascript.*-e.*do shell|launchctl.*remove|diskutil.*erase|nvram'; then
            log ERROR "BLOCKED: Gefaehrliches Pattern: $stripped"
            blocked=true
            break
        fi

        # Fix #81: Whitelist verschaerft + Sub-Command Validierung
        local first_word=$(echo "$stripped" | awk '{print $1}')
        case "$first_word" in
            brew|git|xcode-select|dscacheutil|mkdir|cp|mv|defaults|softwareupdate|mas|ollama|mdimport|sleep|true)
                # Erlaubt
                ;;
            killall)
                # Nur sichere Prozesse erlaubt
                if echo "$stripped" | grep -qiE 'killall.*(kernel|init|launchd|loginwindow|WindowServer|Finder|Dock|SystemUIServer)'; then
                    log ERROR "BLOCKED: killall auf Systemprozess: $stripped"
                    blocked=true; break
                fi
                ;;
            rm)
                # rm wird unten separat geprueft
                ;;
            sudo)
                # sudo wird unten separat geprueft
                ;;
            *)
                log ERROR "BLOCKED: '$first_word' nicht in Whitelist"
                blocked=true
                break
                ;;
        esac

        # sudo-Subcommand pruefen
        if [ "$first_word" = "sudo" ]; then
            local sudo_cmd=$(echo "$stripped" | awk '{print $2}')
            case "$sudo_cmd" in
                dscacheutil|killall|periodic|xcode-select|softwareupdate|cp|mkdir|sed|rm|defaults|brew|mv|scutil|chmod|chown)
                    # Erlaubte sudo-Commands
                    ;;
                *)
                    log ERROR "BLOCKED: 'sudo $sudo_cmd' nicht erlaubt"
                    blocked=true
                    break
                    ;;
            esac
        fi

        # rm Validierung: nur bestimmte Pfade
        if [ "$first_word" = "rm" ] || echo "$stripped" | grep -q "sudo rm"; then
            if ! echo "$stripped" | grep -qE '(Library/Caches|\.Trash|DerivedData|/tmp/|/private/var/tmp|\.meister/)'; then
                log ERROR "BLOCKED: rm auf unerlaubtem Pfad: $stripped"
                blocked=true
                break
            fi
        fi

        echo "$stripped" >> "$tmpscript"
    done <<< "$fix_cmd"

    if $blocked; then
        rm -f "$tmpscript"
        report_add ERROR "AI-Fix geblockt (Sicherheit): $module_name"
        return 1
    fi

    # Fix #31: Validierte Zeilen via /bin/bash -c ausfuehren (kein eval)
    while IFS= read -r cmd; do
        [ -z "$cmd" ] && continue
        log STEP "   Exec: $cmd"
        /bin/bash -c "$cmd" 2>&1
        rc=$?
        if [ $rc -ne 0 ]; then
            log WARN "   Befehl Exit: $rc"
        fi
    done < "$tmpscript"

    rm -f "$tmpscript"
    return $rc
}

selfheal_apply() {
    local module_name="$1"
    local fix_cmd="$2"

    # Patch archivieren
    local ts=$(date +%Y%m%d_%H%M%S)
    echo "# AI-Fix: $module_name ($ts)" > "$MEISTER_DIR/patches/${module_name}_${ts}.sh"
    echo "$fix_cmd" >> "$MEISTER_DIR/patches/${module_name}_${ts}.sh"

    log HEAL "Wende AI-Fix an fuer $module_name..."

    # Fix #1: safe_exec_lines statt eval
    safe_exec_lines "$fix_cmd" "$module_name"
}

# Known-Fix Patterns: schnelle Fixes ohne Ollama
known_fix() {
    local module_name="$1"
    local error_output="$2"

    case "$error_output" in
        *"Could not resolve host"*|*"Failed to connect"*|*"Network is unreachable"*)
            log HEAL "Known-Fix: DNS/Netzwerk-Reset..."
            sudo dscacheutil -flushcache 2>/dev/null
            sudo killall -HUP mDNSResponder 2>/dev/null
            sleep 2
            return 0
            ;;
        *"No space left on device"*)
            log HEAL "Known-Fix: Platz schaffen..."
            rm -rf "$HOME/Library/Caches"/* 2>/dev/null
            brew cleanup -s 2>/dev/null
            return 0
            ;;
        *"shallow"*|*"fetch-pack"*|*"Could not resolve HEAD"*)
            log HEAL "Known-Fix: Homebrew Repo reparieren..."
            git -C "$(brew --repo)" fetch --unshallow 2>/dev/null
            brew update-reset 2>/dev/null
            return 0
            ;;
        *"already installed"*|*"is already an installed"*)
            log HEAL "Known-Fix: Bereits installiert, OK"
            return 0
            ;;
        *"Couldn't find remote ref"*|*"fatal: bad object"*)
            log HEAL "Known-Fix: Git-Repository Reset..."
            brew update-reset 2>/dev/null
            return 0
            ;;
        *"Error: Your CLT"*|*"xcode-select"*)
            log HEAL "Known-Fix: Xcode CLT reparieren..."
            sudo xcode-select --reset 2>/dev/null
            return 0
            ;;
        *"SIGTERM"*|*"Terminated"*|*"kill"*)
            log HEAL "Known-Fix: Prozess wurde beendet, Retry..."
            sleep 3
            return 0
            ;;
    esac
    return 1
}

# Fix #6: Logfile-Diff statt leerer stderr-Datei
run_module_safe() {
    local module_name="$1"
    local module_func="$2"
    local attempt=0
    local max=$((SELFHEAL_MAX_RETRIES + 1))

    section_header "$module_name"
    module_timer_start

    while [ $attempt -lt $max ]; do
        attempt=$((attempt + 1))
        [ $attempt -gt 1 ] && log HEAL "Retry ${attempt}/${max} fuer $module_name..."

        # Log-Position merken fuer Fehleranalyse
        local log_lines_before=$(wc -l < "$LOGFILE" 2>/dev/null || echo 0)

        $module_func
        local rc=$?

        if [ $rc -eq 0 ]; then
            [ $attempt -gt 1 ] && report_add HEALED "$module_name nach ${attempt} Versuchen geheilt"
            module_timer_stop "$module_name"
            return 0
        fi

        # Modul-Output aus Logfile extrahieren
        local module_output=$(tail -n +$((log_lines_before + 1)) "$LOGFILE" 2>/dev/null | head -"$LOG_CAPTURE_LINES")

        log ERROR "$module_name fehlgeschlagen (Exit: $rc)"

        if [ $attempt -ge $max ]; then
            report_add ERROR "$module_name nach ${max} Versuchen fehlgeschlagen"
            module_timer_stop "$module_name"
            return $rc
        fi

        # Erst Known-Fixes probieren
        local full_error="Exit: $rc. $module_output"
        if known_fix "$module_name" "$full_error"; then
            log HEAL "Known-Fix angewendet, neuer Versuch..."
            report_add HEALED "$module_name: Known-Fix angewendet"
            sleep 1
            continue
        fi

        # Dann Ollama
        if ! ollama_available; then
            log WARN "Ollama nicht erreichbar, kein AI-Fix moeglich"
            report_add ERROR "$module_name fehlgeschlagen (kein Ollama)"
            module_timer_stop "$module_name"
            return $rc
        fi

        log HEAL "Analysiere via Ollama (${OLLAMA_MODEL})..."
        local fix
        fix=$(selfheal_analyze "$module_name" "$full_error" "$rc")

        if [ -z "$fix" ] || [ "$fix" = "NOFIX" ]; then
            log WARN "Kein AI-Fix verfuegbar fuer $module_name"
            report_add WARN "Self-Heal: Kein Fix fuer $module_name"
            module_timer_stop "$module_name"
            return $rc
        fi

        log HEAL "Ollama schlaegt vor:"
        echo "$fix" | while IFS= read -r line; do
            [ -n "$line" ] && log STEP "   > $line"
        done

        selfheal_apply "$module_name" "$fix" || {
            report_add ERROR "AI-Fix fehlgeschlagen fuer $module_name"
            module_timer_stop "$module_name"
            return $rc
        }

        sleep 2
    done
}

#############################
# 4. INFRASTRUCTURE
#############################

# Fix #11: Mehrere Endpunkte
check_net() {
    log INFO "Pruefe Netzwerk..."
    # Fix #114: Parallele Ping-Checks statt sequentiell (bis 6s gespart bei Fehler)
    local _net_ok_file
    _net_ok_file=$(mktemp)
    rm -f "$_net_ok_file"
    for host in $NET_CHECK_HOSTS; do
        ( ping -c 1 -W 3 "$host" &>/dev/null && echo "$host" > "$_net_ok_file" ) &
    done
    wait
    if [ -f "$_net_ok_file" ]; then
        local ok_host
        ok_host=$(cat "$_net_ok_file")
        rm -f "$_net_ok_file"
        log INFO "   Netzwerk OK (ping $ok_host)"
        return 0
    fi
    rm -f "$_net_ok_file" 2>/dev/null

    log STEP "   Ping fehlgeschlagen, versuche HTTPS..."
    for host in $NET_CHECK_HOSTS; do
        if curl -sf --max-time 5 "https://$host" >/dev/null 2>&1; then
            log INFO "   Netzwerk OK (HTTPS $host)"
            return 0
        fi
    done

    log ERROR "Keine Internet-Verbindung!"

    # Self-Healing: Netzwerk-Diagnose mit Ollama
    if ollama_available; then
        local net_info="DNS: $(scutil --dns 2>/dev/null | head -5)
Interface: $(ifconfig en0 2>/dev/null | grep 'inet ')
Route: $(netstat -rn 2>/dev/null | head -8)"
        log HEAL "Netzwerk-Diagnose via Ollama..."
        local diag
        diag=$(ollama_query "macOS hat keine Internetverbindung. Analysiere und gib Fix-Befehle:
$(sanitize_for_prompt "$net_info" 500)
Nur Shell-Commands, eine pro Zeile. Keine Erklaerungen, kein Markdown, keine <think>-Tags.
Erlaubt: sudo dscacheutil, sudo killall, defaults, networksetup.
Wenn kein Fix moeglich: nur NOFIX")
        if [ -n "$diag" ] && [ "$diag" != "NOFIX" ]; then
            log HEAL "Ollama Netzwerk-Fix:"
            echo "$diag" | while IFS= read -r line; do
                [ -n "$line" ] && log STEP "   > $line"
            done
            selfheal_apply "Network" "$diag"
            sleep 2
            for host in $NET_CHECK_HOSTS; do
                if ping -c 1 -W 3 "$host" &>/dev/null; then
                    log FIX "Netzwerk wiederhergestellt!"
                    report_add HEALED "Netzwerk via AI-Fix repariert"
                    return 0
                fi
            done
        fi
    fi

    report_add ERROR "No Internet connection"
    return 1
}

ensure_brew() {
    if ! command_exists brew; then
        log WARN "Homebrew not found. Installing..."
        run_or_dry /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        if command_exists brew; then
            log FIX "Homebrew installed."
            report_add FIX "Installed Homebrew"
            eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || eval "$(/usr/local/bin/brew shellenv)" 2>/dev/null
        else
            log ERROR "Homebrew install failed."
            report_add ERROR "Homebrew missing"
            return 1
        fi
    else
        log STEP "   Homebrew gefunden: $(brew --prefix)"
    fi
    return 0
}

ensure_tool() {
    local cmd="$1"
    local pkg="$2"
    local is_cask="${3:-}"

    if command_exists "$cmd"; then
        log STEP "   Tool '$cmd' vorhanden"
        return 0
    fi

    log WARN "Tool '$cmd' fehlt. Installiere $pkg..."
    ensure_brew || return 1

    if run_or_dry brew install $is_cask "$pkg"; then
        log FIX "Installed '$pkg'."
        report_add FIX "Auto-installed: $pkg"
        return 0
    else
        log ERROR "Failed to install '$pkg'."
        report_add ERROR "Failed to install $pkg"

        if ollama_available; then
            log HEAL "Frage Ollama warum '$pkg' Installation fehlschlaegt..."
            local diag
            diag=$(selfheal_analyze "install-$pkg" "brew install $is_cask $pkg failed" "1")
            if [ -n "$diag" ] && [ "$diag" != "NOFIX" ]; then
                selfheal_apply "install-$pkg" "$diag"
                if run_or_dry brew install $is_cask "$pkg" 2>/dev/null; then
                    log FIX "Installation von '$pkg' nach AI-Fix erfolgreich!"
                    report_add HEALED "Install $pkg via AI-Fix"
                    return 0
                fi
            fi
        fi
        return 1
    fi
}

#############################
# 5. MODULES
#############################

# ── MIGRATION ──

MIGRATE_APPS=(
    "WhatsApp.app"
    "WhatsApp 2.app"
    "Google Chrome.app"
    "Firefox.app"
    "Slack.app"
    "Zoom.us.app"
    "Microsoft Word.app"
    "Microsoft Excel.app"
    "Microsoft PowerPoint.app"
    "Visual Studio Code.app"
    "Spotify.app"
    "Telegram.app"
    "VLC.app"
    "OneDrive.app"
)
MIGRATE_CASKS=(
    "whatsapp"
    ""
    "google-chrome"
    "firefox"
    "slack"
    "zoom"
    "microsoft-word"
    "microsoft-excel"
    "microsoft-powerpoint"
    "visual-studio-code"
    "spotify"
    "telegram"
    "vlc"
    "onedrive"
)

module_migration() {
    log INFO "Pruefe Apps fuer Migration von AppStore zu Brew..."
    ensure_brew || return 1
    local migrated_count=0
    local checked_count=0
    local i=0

    while [ $i -lt ${#MIGRATE_APPS[@]} ]; do
        local app_name="${MIGRATE_APPS[$i]}"
        local cask_name="${MIGRATE_CASKS[$i]}"
        local app_path="/Applications/$app_name"
        i=$((i + 1))
        checked_count=$((checked_count + 1))

        if [ -z "$cask_name" ]; then
            if [ -d "$app_path" ]; then
                log WARN "   Removing duplicate: $app_name"
                run_or_dry pkill -f "${app_name%.app}" &>/dev/null || true
                local owner=$(stat -f%Su "$app_path" 2>/dev/null)
                if [ "$owner" = "root" ]; then
                    run_or_dry sudo rm -rf "$app_path"
                else
                    run_or_dry rm -rf "$app_path"
                fi
                report_add FIX "Removed duplicate: $app_name"
                migrated_count=$((migrated_count + 1))
            fi
            continue
        fi

        if [ -d "$app_path" ] && [ -d "$app_path/Contents/_MASReceipt" ]; then
            log STEP "   MAS-App gefunden: $app_name"

            # Pruefen ob Cask deprecated ist
            local cask_info=$(brew info --cask "$cask_name" 2>&1)
            if echo "$cask_info" | grep -qi "deprecated\|disabled\|discontinued"; then
                log WARN "   Cask '$cask_name' ist deprecated - ueberspringe $app_name"
                report_add WARN "Migration uebersprungen: $app_name (Cask deprecated)"
                continue
            fi

            if echo "$cask_info" | grep -qi "$cask_name"; then
                log WARN "   MIGRATING $app_name -> Homebrew ($cask_name)..."
                run_or_dry pkill -f "${app_name%.app}" &>/dev/null || true

                # MAS-Apps gehoeren root, brauchen sudo
                local owner=$(stat -f%Su "$app_path" 2>/dev/null)
                if [ "$owner" = "root" ]; then
                    log STEP "   App gehoert root, verwende sudo rm"
                    run_or_dry sudo rm -rf "$app_path"
                else
                    run_or_dry rm -rf "$app_path"
                fi

                if [ -d "$app_path" ]; then
                    log ERROR "Konnte $app_name nicht loeschen (Rechte?)"
                    report_add ERROR "Migration failed: $app_name (rm fehlgeschlagen)"
                    continue
                fi

                if run_or_dry brew install --cask "$cask_name"; then
                    log FIX "Migrated $app_name to Brew."
                    report_add FIX "Migrated $app_name from MAS to Brew"
                    migrated_count=$((migrated_count + 1))
                else
                    log ERROR "Brew install failed for $cask_name!"
                    report_add ERROR "Migration failed: $app_name"
                fi
            fi
        fi
    done

    log INFO "   ${checked_count} Apps geprueft, ${migrated_count} migriert"
    [ $migrated_count -eq 0 ] && log INFO "   Alle Apps bereits auf Brew oder nicht MAS"
}

# ── HOMEBREW (Fix #4: korrekte Exit-Codes) ──

module_homebrew() {
    log INFO "Homebrew Wartung..."
    ensure_brew || return 1

    local brew_version=$(brew --version 2>/dev/null | head -1)
    log STEP "   Version: $brew_version"

    # brew update mit korrektem Exit-Code
    log INFO "   brew update..."
    run_verbose brew update
    local update_rc=$?
    if [ $update_rc -ne 0 ]; then
        log WARN "brew update fehlgeschlagen (Exit: $update_rc). Trying unshallow..."
        git -C "$(brew --repo)" fetch --unshallow &>/dev/null
        run_verbose brew update
        if [ $? -eq 0 ]; then
            report_add FIX "Fixed Homebrew repo (unshallow)"
        else
            log ERROR "brew update weiterhin fehlgeschlagen"
        fi
    fi

    # Outdated formulae
    log INFO "   Pruefe veraltete Formulae..."
    local outdated_formulae=$(brew outdated --formula 2>/dev/null)
    if [ -n "$outdated_formulae" ]; then
        local formula_count=$(echo "$outdated_formulae" | wc -l | xargs)
        log INFO "   ${formula_count} veraltete Formulae:"
        echo "$outdated_formulae" | while IFS= read -r line; do
            log STEP "     - $line"
        done
    else
        log INFO "   Alle Formulae aktuell"
    fi

    # brew upgrade mit korrektem Exit-Code
    log INFO "   brew upgrade..."
    run_verbose brew upgrade
    if [ $? -eq 0 ]; then
        report_add SUCCESS "Homebrew Formulae upgraded"
    else
        report_add WARN "Homebrew upgrade had issues"
    fi

    # Outdated casks
    log INFO "   Pruefe veraltete Casks..."
    local outdated_casks=$(brew outdated --cask --greedy 2>/dev/null)
    if [ -n "$outdated_casks" ]; then
        local cask_count=$(echo "$outdated_casks" | wc -l | xargs)
        log INFO "   ${cask_count} veraltete Casks:"
        echo "$outdated_casks" | while IFS= read -r line; do
            log STEP "     - $line"
        done
    else
        log INFO "   Alle Casks aktuell"
    fi

    # Fix #12: --greedy statt --force
    log INFO "   Upgrading Casks (--greedy)..."
    run_verbose brew upgrade --cask --greedy

    # Fix #23: autoremove nach upgrade
    log INFO "   Autoremove ungenutzter Dependencies..."
    local removed=$(brew autoremove 2>&1)
    if echo "$removed" | grep -q "Uninstalling"; then
        local rm_count=$(echo "$removed" | grep -c "Uninstalling")
        log FIX "   ${rm_count} ungenutzte Dependencies entfernt"
        report_add FIX "brew autoremove: ${rm_count} Pakete entfernt"
    else
        log STEP "   Keine ungenutzten Dependencies"
    fi

    log INFO "   Cleanup..."
    run_verbose brew cleanup -s
    report_add SUCCESS "Homebrew Cleanup finished"

    # Doctor-Check mit Auto-Fix (Fix #22)
    log INFO "   brew doctor..."
    local doctor_output=$(brew doctor 2>&1)
    if echo "$doctor_output" | grep -q "ready to brew"; then
        log INFO "   Homebrew ist gesund"
    else
        local warn_count=$(echo "$doctor_output" | grep -c "Warning" 2>/dev/null || echo 0)
        log WARN "   brew doctor: ${warn_count} Warnings"
        echo "$doctor_output" | grep "Warning" | head -5 | while IFS= read -r line; do
            log STEP "     $line"
        done

        # Auto-Fix: Unlinked kegs
        local did_autofix=false
        local unlinked=$(echo "$doctor_output" | grep -A20 "unlinked kegs" | grep "^  " | sed 's/^[[:space:]]*//' | head -10)
        if [ -n "$unlinked" ]; then
            log HEAL "   Auto-Fix: Unlinked Kegs linken..."
            did_autofix=true
            while IFS= read -r keg; do
                [ -z "$keg" ] && continue
                local keg_name=$(echo "$keg" | awk '{print $1}')
                if run_or_dry brew link "$keg_name" 2>/dev/null; then
                    log FIX "     Linked: $keg_name"
                    report_add FIX "brew link: $keg_name"
                else
                    log WARN "     Link fehlgeschlagen: $keg_name (versuche --overwrite)"
                    run_or_dry brew link --overwrite "$keg_name" 2>/dev/null && \
                        report_add FIX "brew link --overwrite: $keg_name"
                fi
            done <<< "$unlinked"
        fi

        # Auto-Fix: Outdated Xcode CLT
        if echo "$doctor_output" | grep -qi "command line tools.*outdated\|CLT.*update"; then
            log HEAL "   Auto-Fix: Xcode CLT Update anstossen..."
            did_autofix=true
            run_or_dry softwareupdate --install --all 2>/dev/null
            report_add FIX "Xcode CLT Update angestossen"
        fi

        # Auto-Fix: Broken symlinks
        if echo "$doctor_output" | grep -qi "broken symlinks"; then
            log HEAL "   Auto-Fix: Broken Symlinks bereinigen..."
            did_autofix=true
            brew cleanup -s 2>/dev/null
            report_add FIX "brew cleanup: Broken Symlinks bereinigt"
        fi

        # Fix #42: Re-check nur wenn tatsaechlich Auto-Fixes angewendet wurden
        if $did_autofix; then
            local doctor_recheck=$(brew doctor 2>&1)
            if echo "$doctor_recheck" | grep -q "ready to brew"; then
                log FIX "   Homebrew nach Auto-Fix gesund!"
                report_add FIX "brew doctor: Alle Warnings behoben"
            else
                local warn_remain=$(echo "$doctor_recheck" | grep -c "Warning" 2>/dev/null || echo 0)
                if [ "$warn_remain" -lt "$warn_count" ]; then
                    log FIX "   ${warn_count} -> ${warn_remain} Warnings reduziert"
                    report_add FIX "brew doctor: ${warn_count} -> ${warn_remain} Warnings"
                fi

                # Verbleibende Warnings an Ollama delegieren
                if [ "$warn_remain" -gt 0 ] && ollama_available; then
                    log HEAL "   Frage Ollama zu verbleibenden brew doctor Warnings..."
                    local safe_doctor=$(sanitize_for_prompt "$doctor_recheck" 800)
                    local doctor_fix
                    doctor_fix=$(selfheal_analyze "brew-doctor" "$safe_doctor" "1")
                    if [ -n "$doctor_fix" ] && [ "$doctor_fix" != "NOFIX" ]; then
                        selfheal_apply "brew-doctor" "$doctor_fix"
                        report_add HEALED "brew doctor: AI-Fix angewendet"
                    else
                        report_add WARN "brew doctor: ${warn_remain} Warnings verbleiben (siehe Log)"
                    fi
                else
                    report_add WARN "brew doctor: ${warn_remain} Warnings verbleiben (siehe Log)"
                fi
            fi
        else
            report_add WARN "brew doctor: ${warn_count} Warnings (kein Auto-Fix moeglich, siehe Log)"
        fi
    fi
}

# ── MAS (APP STORE) ──

module_mas() {
    log INFO "Pruefe Mac App Store..."
    ensure_tool "mas" "mas" || return 1

    # Fix #43: Pruefen ob User im App Store eingeloggt ist
    if ! mas account &>/dev/null; then
        log WARN "   Nicht im App Store eingeloggt - ueberspringe MAS-Updates"
        report_add WARN "App Store: Nicht eingeloggt (manuell anmelden)"
        return 0
    fi

    export MAS_NO_AUTO_INDEX=1

    local spotlight_marker="$MEISTER_DIR/spotlight_fixed"
    if [ ! -f "$spotlight_marker" ]; then
        log INFO "   Indexiere MAS-Apps fuer Spotlight (einmalig)..."
        local idx_count=0
        for app_dir in /Applications/*.app; do
            [ -d "$app_dir/Contents/_MASReceipt" ] || continue
            mdimport "$app_dir" &>/dev/null || true
            idx_count=$((idx_count + 1))
            log STEP "   Indexiert: $(basename "$app_dir")"
        done
        touch "$spotlight_marker"
        log FIX "Spotlight-Index fuer ${idx_count} MAS-Apps rebuilt"
        report_add FIX "Spotlight-Index fuer ${idx_count} App Store Apps repariert"
    fi

    log INFO "   Pruefe MAS-Updates..."
    local outdated=$(mas outdated 2>/dev/null)
    if [ -z "$outdated" ]; then
        log INFO "   Alle App Store Apps aktuell"
        report_add SUCCESS "App Store apps up to date"
    else
        local count=$(echo "$outdated" | wc -l | xargs)
        log INFO "   ${count} Updates verfuegbar:"
        echo "$outdated" | while IFS= read -r line; do
            log STEP "     - $line"
        done
        log INFO "   Installiere Updates..."
        run_verbose mas upgrade
        if [ $? -eq 0 ]; then
            report_add FIX "Updated $count App Store Apps"
        else
            report_add ERROR "MAS Upgrade failed"
        fi
    fi
}

# ── MS OFFICE (Timeout-Fix + Policy-Check + Retry) ──

# Fix #24: Sicherheitsrichtlinien fuer MS Updates pruefen
check_ms_update_policy() {
    log INFO "   Pruefe MS Update Sicherheitsrichtlinien..."

    # MDM-Profile die Updates blockieren koennten
    local profiles=$(profiles list 2>/dev/null || echo "")
    if echo "$profiles" | grep -qi "microsoft\|update.*restrict\|MAU\|com.microsoft"; then
        log WARN "   MDM-Profil koennte MS-Updates einschraenken"
        echo "$profiles" | grep -i "microsoft\|MAU" | head -3 | while IFS= read -r line; do
            log STEP "     $line"
        done
        report_add WARN "MDM-Profil fuer Microsoft gefunden (pruefen)"
    else
        log STEP "   Keine restriktiven MDM-Profile gefunden"
    fi

    # MAU-Channel pruefen
    local mau_channel=$(defaults read com.microsoft.autoupdate2 ChannelName 2>/dev/null)
    if [ -n "$mau_channel" ]; then
        log STEP "   MAU Channel: $mau_channel"
        if [ "$mau_channel" = "Custom" ]; then
            log WARN "   MAU Channel auf Custom - Updates koennten eingeschraenkt sein"
            report_add WARN "MAU Channel: Custom (ggf. auf Production setzen)"
        fi
    fi

    # Auto-Update Modus pruefen
    local mau_how=$(defaults read com.microsoft.autoupdate2 HowToCheck 2>/dev/null)
    if [ "$mau_how" = "Manual" ]; then
        log WARN "   MAU auf Manual gestellt - setze auf Automatic"
        run_or_dry defaults write com.microsoft.autoupdate2 HowToCheck Automatic
        report_add FIX "MAU HowToCheck: Manual -> Automatic"
    elif [ -n "$mau_how" ]; then
        log STEP "   MAU HowToCheck: $mau_how"
    fi

    # Auto-Download pruefen
    local mau_auto_dl=$(defaults read com.microsoft.autoupdate2 EnableCheckForUpdatesButton 2>/dev/null)
    if [ "$mau_auto_dl" = "0" ]; then
        log WARN "   MAU Update-Button deaktiviert - reaktiviere"
        run_or_dry defaults write com.microsoft.autoupdate2 EnableCheckForUpdatesButton -bool true
        report_add FIX "MAU Update-Button reaktiviert"
    fi

    # Full Disk Access Hinweis (nur Info, kann nicht automatisch geaendert werden)
    if [ -f "/Library/Application Support/com.apple.TCC/TCC.db" ]; then
        local has_fda
        has_fda=$(sudo sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" \
            "SELECT client FROM access WHERE service='kTCCServiceSystemPolicyAllFiles' AND auth_value=2" 2>/dev/null \
            | grep -ci "microsoft" 2>/dev/null) || has_fda=0
        if [ "${has_fda:-0}" -eq 0 ]; then
            log WARN "   MS AutoUpdate hat moeglicherweise keinen Full Disk Access"
            report_add WARN "MS AutoUpdate: Full Disk Access pruefen (Systemeinstellungen > Datenschutz)"
        else
            log STEP "   MS Apps haben Full Disk Access"
        fi
    fi
}

module_office() {
    log INFO "Microsoft Office Updates..."
    if [ ! -f "$MSUPDATE_PATH" ]; then
        log WARN "   MS AutoUpdate nicht gefunden"
        log STEP "   Pfad: $MSUPDATE_PATH"
        report_add WARN "MS AutoUpdate not found (Skipped)"
        return 0
    fi

    if $DRY_RUN; then
        log STEP "   [DRY-RUN] wuerde msupdate --install ausfuehren"
        return 0
    fi

    # Fix #24: Policy-Check vor Update
    check_ms_update_policy

    log INFO "   MS AutoUpdate gefunden, pruefe verfuegbare Updates..."

    # Erst --list ausfuehren um zu pruefen ob Updates verfuegbar sind
    # (--install haengt wenn keine Updates vorhanden)
    local list_file=$(mktemp /tmp/msupdate_list_XXXXXX.log 2>/dev/null || echo "/tmp/msupdate_list_$$.log")
    timeout "$MSUPDATE_TIMEOUT" "$MSUPDATE_PATH" --list > "$list_file" 2>&1
    local list_rc=$?
    local list_output=$(cat "$list_file" 2>/dev/null)
    rm -f "$list_file" 2>/dev/null

    if [ $list_rc -eq 124 ]; then
        log WARN "   msupdate --list Timeout nach ${MSUPDATE_TIMEOUT}s"
        report_add WARN "Office Update: --list Timeout (manuell pruefen)"
        pkill -f "Microsoft AutoUpdate" 2>/dev/null || true
        pkill -f "Microsoft Update Assistant" 2>/dev/null || true
        return 0
    fi

    # ANSI-Escape-Codes entfernen fuer sauberen Vergleich
    local clean_output=$(echo "$list_output" | sed $'s/\x1b\\[[0-9;]*[a-zA-Z]//g' | tr -s ' ')

    if echo "$clean_output" | grep -qi "No updates"; then
        log INFO "   Office ist aktuell (keine Updates verfuegbar)"
        MSUPDATE_OUTPUT_LOG="$list_output"
        report_add SUCCESS "Office is up to date"
        return 0
    fi

    # Updates verfuegbar - anzeigen was kommt
    log INFO "   Updates verfuegbar:"
    echo "$clean_output" | grep -v '^$' | while IFS= read -r line; do
        [ -n "$line" ] && log STEP "   $line"
    done

    # Jetzt --install ausfuehren
    log INFO "   Starte Installation..."
    log STEP "   Timeout: ${MSUPDATE_TIMEOUT}s"

    local output_file=$(mktemp /tmp/msupdate_XXXXXX.log 2>/dev/null || echo "/tmp/msupdate_$$.log")

    "$MSUPDATE_PATH" --install > "$output_file" 2>&1 &
    local ms_pid=$!
    log STEP "   msupdate PID: $ms_pid"

    local waited=0
    local dot_count=0
    while kill -0 "$ms_pid" 2>/dev/null && [ $waited -lt $MSUPDATE_TIMEOUT ]; do
        sleep 5
        waited=$((waited + 5))
        dot_count=$((dot_count + 1))
        if [ $((dot_count % 3)) -eq 0 ]; then
            log STEP "   Warte auf msupdate... (${waited}s/${MSUPDATE_TIMEOUT}s)"
            local current_output=$(tail -1 "$output_file" 2>/dev/null)
            [ -n "$current_output" ] && log STEP "   Status: $current_output"
        fi
    done

    if kill -0 "$ms_pid" 2>/dev/null; then
        log WARN "   msupdate haengt nach ${MSUPDATE_TIMEOUT}s - beende Prozess!"
        kill "$ms_pid" 2>/dev/null
        sleep 2
        if kill -0 "$ms_pid" 2>/dev/null; then
            log WARN "   Force-Kill msupdate..."
            kill -9 "$ms_pid" 2>/dev/null
        fi
        wait "$ms_pid" 2>/dev/null

        local stuck_output=$(cat "$output_file" 2>/dev/null)
        MSUPDATE_OUTPUT_LOG="[TIMEOUT nach ${MSUPDATE_TIMEOUT}s] $stuck_output"
        report_add WARN "Office Update Timeout nach ${MSUPDATE_TIMEOUT}s (manuell pruefen)"

        # Auch MAU-Hilfsprozesse killen die haengen bleiben
        log STEP "   Beende verwaiste MAU-Prozesse..."
        pkill -f "Microsoft AutoUpdate" 2>/dev/null || true
        pkill -f "Microsoft Update Assistant" 2>/dev/null || true

        if ollama_available; then
            log HEAL "Frage Ollama warum MS Update haengt..."
            local safe_output=$(sanitize_for_prompt "$stuck_output" 500)
            local diag
            diag=$(ollama_query "msupdate (Microsoft AutoUpdate auf macOS) haengt seit ${MSUPDATE_TIMEOUT} Sekunden.
Output: $safe_output
Shell-Commands, eine pro Zeile. Keine Erklaerungen, kein Markdown, keine <think>-Tags. Wenn kein Fix: nur NOFIX")
            if [ -n "$diag" ] && [ "$diag" != "NOFIX" ]; then
                log HEAL "Ollama MS-Update Fix:"
                echo "$diag" | while IFS= read -r line; do
                    [ -n "$line" ] && log STEP "   > $line"
                done
                selfheal_apply "MSUpdate-Stuck" "$diag"
                report_add HEALED "MS Update: AI-Fix angewendet"
            fi
        fi

        # Fix #25: Retry nach Timeout
        log INFO "   Office-Update Retry nach Timeout..."
        sleep 5
        local retry_file=$(mktemp /tmp/msupdate_retry_XXXXXX.log 2>/dev/null || echo "/tmp/msupdate_retry_$$.log")
        timeout "$MSUPDATE_TIMEOUT" "$MSUPDATE_PATH" --install > "$retry_file" 2>&1
        local retry_rc=$?
        local retry_output=$(cat "$retry_file" 2>/dev/null)
        rm -f "$retry_file" 2>/dev/null

        if [ $retry_rc -eq 0 ]; then
            log FIX "   Retry: Office Updates installiert!"
            report_add FIX "Office Update via Retry erfolgreich"
        elif [ $retry_rc -eq 124 ]; then
            log ERROR "   Retry: Erneuter Timeout"
            report_add ERROR "Office Update: Timeout auch nach Retry (manuell pruefen)"
        else
            log WARN "   Retry: Exit $retry_rc"
            report_add WARN "Office Update Retry: Exit $retry_rc (manuell pruefen)"
        fi
    else
        wait "$ms_pid" 2>/dev/null
        local code=$?
        local output=$(cat "$output_file" 2>/dev/null)
        MSUPDATE_OUTPUT_LOG="$output"

        if [ $code -eq 0 ]; then
            log FIX "Office Updates installiert"
            echo "$output" | sed $'s/\x1b\\[[0-9;]*[a-zA-Z]//g' | grep -v '^$' | while IFS= read -r line; do
                [ -n "$line" ] && log STEP "   $line"
            done
            report_add FIX "Office updates installed"
        else
            log ERROR "Office update fehlgeschlagen (Exit: $code)"
            echo "$output" | tail -5 | while IFS= read -r line; do
                [ -n "$line" ] && log STEP "   $line"
            done
            report_add ERROR "Office update failed (Exit: $code)"
        fi
    fi

    rm -f "$output_file" 2>/dev/null
}

# ── OLLAMA (Fix #5: Subshell-Counter-Bug) ──

module_ollama() {
    log INFO "Pruefe Ollama..."

    if ! command_exists ollama; then
        if command_exists brew && brew list --cask ollama &>/dev/null; then
            ensure_tool "ollama" "ollama" "--cask"
        else
            log INFO "   Ollama nicht installiert. Ueberspringe."
            return 0
        fi
    fi

    if ! command_exists ollama; then return 0; fi

    # Fix #41: Zentralen Starter verwenden
    if ollama_available; then
        log INFO "   Ollama-Server laeuft"
    elif ensure_ollama_running "   "; then
        report_add FIX "Ollama-Server automatisch gestartet"
    else
        report_add WARN "Ollama-Server offline"
    fi

    local models=$(ollama_list_cached | awk 'NR>1 {print $1}')
    if [ -z "$models" ]; then
        log INFO "   Keine Ollama-Modelle installiert"
        return 0
    fi

    local model_count=$(echo "$models" | wc -l | xargs)
    log INFO "   ${model_count} Modelle gefunden"

    # Fix #5: Kein Pipe, kein Subshell-Problem
    local updated=0
    local failed=0
    for model in $models; do
        log INFO "   Pulling: $model"
        local pull_output
        pull_output=$(run_or_dry ollama pull "$model" 2>&1)
        local pull_rc=$?
        if [ $pull_rc -eq 0 ]; then
            updated=$((updated + 1))
            log STEP "     OK"
        else
            failed=$((failed + 1))
            log WARN "   Pull fehlgeschlagen: $model"
            [ -n "$pull_output" ] && log STEP "     $(echo "$pull_output" | tail -1)"
        fi
    done

    [ $updated -gt 0 ] && ollama_list_invalidate
    log INFO "   ${updated}/${model_count} Modelle aktualisiert"
    [ $failed -gt 0 ] && log WARN "   ${failed} Pulls fehlgeschlagen"
    report_add FIX "Updated $updated/$model_count Ollama models"

    if $RUN_LMSTUDIO_COPY; then
        log INFO "   Sync GGUF-Modelle zu LM Studio..."
        local dest="$HOME/Library/Application Support/LM Studio/models"
        mkdir -p "$dest"
        local synced=0
        while IFS= read -r -d '' f; do
            local bname=$(basename "$f")
            if [ ! -f "$dest/$bname" ]; then
                run_or_dry cp "$f" "$dest/"
                synced=$((synced + 1))
                log STEP "     Synced: $bname"
            fi
        done < <(find "$HOME/.ollama/models" -name "*.gguf" -print0 2>/dev/null)
        log INFO "   ${synced} Modelle synchronisiert"
        report_add FIX "Synced $synced GGUF models to LM Studio"
    fi
}

# ── GIT REPO MANAGEMENT (Fix #101-102) ──

module_git_repos() {
    log INFO "Git Repository Management..."
    local repos_found=0

    # Repos einmalig suchen und cachen (sort -u entfernt Duplikate bei ueberlappenden Suchpfaden)
    local repo_list=$(mktemp)
    for search_path in $GIT_REPO_SEARCH_PATHS; do
        [ ! -d "$search_path" ] && continue
        find "$search_path" -maxdepth "$GIT_REPO_MAXDEPTH" -name ".git" -type d \
            -not -path "*/node_modules/*" \
            -not -path "*/.Trash/*" \
            -not -path "*/Backups/*" \
            2>/dev/null
    done | sort -u > "$repo_list"
    repos_found=$(wc -l < "$repo_list")
    repos_found=${repos_found##* }
    log INFO "   ${repos_found} Repos gefunden"

    # ── [1/2] Unpushed Repos finden und pushen ──
    log STEP "   [1/2] Unpushed Repos synchronisieren..."
    local repos_pushed=0
    local repos_dirty=0
    local repos_unpushed=0

    while IFS= read -r gitdir; do
        [ -z "$gitdir" ] && continue
        local repo_dir=$(dirname "$gitdir")
        local repo_name=$(basename "$repo_dir")

        # Fix #105: timeout 5 vor ALLE git-Befehle (auch "lokale" koennen auf iCloud-Repos haengen)
        local remote
        remote=$(timeout 5 git -C "$repo_dir" remote 2>/dev/null | head -1)
        if [ $? -eq 124 ]; then
            log WARN "     ${repo_name}: TIMEOUT bei git remote"
            continue
        fi
        if [ -z "$remote" ]; then
            log STEP "     ${repo_name}: kein Remote, uebersprungen"
            continue
        fi

        local branch
        branch=$(timeout 5 git -C "$repo_dir" symbolic-ref --short HEAD 2>/dev/null)
        [ -z "$branch" ] && continue

        # Fix #107: git status --porcelain einmal cachen statt 2x aufrufen
        local dirty_output
        dirty_output=$(timeout 5 git -C "$repo_dir" status --porcelain 2>/dev/null)
        if [ -n "$dirty_output" ]; then
            local dirty_count
            dirty_count=$(echo "$dirty_output" | wc -l)
            dirty_count=${dirty_count##* }
            log WARN "     ${repo_name}: ${dirty_count} uncommitted changes (${branch})"
            repos_dirty=$((repos_dirty + 1))
        fi

        # Fix #105: Upstream-Check mit timeout (kann Netzwerk brauchen)
        local upstream
        upstream=$(timeout 5 git -C "$repo_dir" rev-parse --abbrev-ref "${branch}@{upstream}" 2>/dev/null)
        if [ -z "$upstream" ]; then
            local remote_branch="${remote}/${branch}"
            local remote_exists
            remote_exists=$(timeout 5 git -C "$repo_dir" rev-parse --verify "$remote_branch" 2>/dev/null)
            [ -z "$remote_exists" ] && continue
            upstream="$remote_branch"
        fi

        # Fix #105: Log-Vergleich mit timeout
        local unpushed_output
        unpushed_output=$(timeout 5 git -C "$repo_dir" log "${upstream}..HEAD" --oneline 2>/dev/null)
        local unpushed=0
        [ -n "$unpushed_output" ] && unpushed=$(echo "$unpushed_output" | wc -l) && unpushed=${unpushed##* }
        if [ "${unpushed:-0}" -gt 0 ]; then
            repos_unpushed=$((repos_unpushed + 1))
            if $GIT_AUTO_PUSH && $RUN_GIT_REPOS; then
                log STEP "     ${repo_name}: ${unpushed} Commits pushen (${branch} -> ${remote})..."
                local push_output
                # Fix #105: Push mit timeout 30 (braucht mehr Zeit als Check)
                push_output=$(run_or_dry timeout 30 git -C "$repo_dir" push "$remote" "$branch" 2>&1)
                local push_rc=$?
                if [ $push_rc -eq 0 ]; then
                    log FIX "     ${repo_name}: ${unpushed} Commits erfolgreich gepusht"
                    repos_pushed=$((repos_pushed + 1))
                elif [ $push_rc -eq 124 ]; then
                    log ERROR "     ${repo_name}: Push Timeout (>30s)"
                else
                    log ERROR "     ${repo_name}: Push fehlgeschlagen"
                    [ -n "$push_output" ] && log STEP "       $(echo "$push_output" | tail -1)"
                fi
            else
                log WARN "     ${repo_name}: ${unpushed} unpushed Commits (${branch}) [-G zum Pushen]"
            fi
        fi
    done < "$repo_list"

    log INFO "   Push-Ergebnis: ${repos_pushed} gepusht, ${repos_unpushed} hatten Aenderungen, ${repos_dirty} dirty"
    [ "$repos_pushed" -gt 0 ] && report_add FIX "Git: ${repos_pushed} Repos gepusht"
    [ "$repos_dirty" -gt 0 ] && report_add WARN "Git: ${repos_dirty} Repos mit uncommitted changes"
    [ "$repos_unpushed" -gt "$repos_pushed" ] && \
        report_add WARN "Git: $((repos_unpushed - repos_pushed)) Repos noch unpushed (-G)"

    # ── [2/2] Backup aller Repos als tar.gz nach iCloud Drive ──
    if $GIT_BACKUP_ENABLED && $RUN_GIT_REPOS; then
        log STEP "   [2/2] Git Repo Backup nach iCloud Drive..."
        local backup_date=$(date +%Y-%m-%d)
        local backup_count=0
        local backup_size_total=0

        # Backup-Verzeichnis erstellen
        run_or_dry mkdir -p "$GIT_BACKUP_DIR"

        # Exclude-Argumente zusammenbauen
        local exclude_args=""
        for excl in $GIT_BACKUP_EXCLUDE; do
            exclude_args="${exclude_args} --exclude=${excl}"
        done

        while IFS= read -r gitdir; do
            [ -z "$gitdir" ] && continue
            local repo_dir=$(dirname "$gitdir")
            local repo_name=$(basename "$repo_dir")
            local archive_name="${backup_date}_${repo_name}.tar.gz"
            local archive_path="${GIT_BACKUP_DIR}/${archive_name}"

            # Ueberspringen falls heute schon gesichert
            if [ -f "$archive_path" ]; then
                log STEP "     ${repo_name}: heute schon gesichert"
                continue
            fi

            log STEP "     ${repo_name}: Backup erstellen..."
            local parent_dir=$(dirname "$repo_dir")
            run_or_dry tar czf "$archive_path" \
                -C "$parent_dir" \
                $exclude_args \
                "$repo_name" 2>/dev/null

            if [ -f "$archive_path" ]; then
                local archive_size=$(du -sh "$archive_path" 2>/dev/null | awk '{print $1}')
                local archive_bytes=$(stat -f%z "$archive_path" 2>/dev/null || echo 0)
                backup_size_total=$((backup_size_total + ${archive_bytes:-0}))
                log FIX "     ${repo_name}: ${archive_size} -> iCloud"
                backup_count=$((backup_count + 1))
            fi
        done < "$repo_list"

        # Alte Backups aufraeumen
        local cleaned=0
        if [ -d "$GIT_BACKUP_DIR" ]; then
            while IFS= read -r -d '' old_backup; do
                run_or_dry rm -f "$old_backup"
                cleaned=$((cleaned + 1))
            done < <(find "$GIT_BACKUP_DIR" -name "*.tar.gz" -mtime "+${GIT_BACKUP_RETENTION_DAYS}" -print0 2>/dev/null)
        fi

        local total_mb=$((backup_size_total / 1048576))
        log INFO "   Backup: ${backup_count} Repos gesichert (~${total_mb} MB), ${cleaned} alte Backups entfernt"
        [ "$backup_count" -gt 0 ] && report_add FIX "Git Backup: ${backup_count} Repos nach iCloud (${total_mb} MB)"
        [ "$cleaned" -gt 0 ] && report_add FIX "Git Backup: ${cleaned} alte Backups entfernt (>${GIT_BACKUP_RETENTION_DAYS}d)"
    elif $GIT_BACKUP_ENABLED; then
        log STEP "   [2/2] Git Backup: verfuegbar (-G zum Ausfuehren)"
        report_add WARN "Git Backup nicht ausgefuehrt (-G)"
    else
        log STEP "   [2/2] Git Backup: deaktiviert (Config)"
    fi

    rm -f "$repo_list"
}

# ── CLAMAV (Fix #15: bessere Excludes) ──

module_clamav() {
    log INFO "ClamAV Modul..."
    ensure_tool "clamscan" "clamav" || return 1

    local config_dir="$(brew --prefix)/etc/clamav"
    local db_dir="$(brew --prefix)/var/lib/clamav"
    log STEP "   Config: $config_dir"
    log STEP "   DB: $db_dir"

    if [ ! -f "$config_dir/freshclam.conf" ]; then
        log WARN "freshclam.conf fehlt..."
        if [ -f "$config_dir/freshclam.conf.sample" ]; then
            run_or_dry sudo cp "$config_dir/freshclam.conf.sample" "$config_dir/freshclam.conf"
            run_or_dry sudo sed -i '' 's/^Example/#Example/' "$config_dir/freshclam.conf"
            log FIX "freshclam.conf erstellt"
            report_add FIX "Created freshclam.conf"
        else
            log ERROR "freshclam.conf.sample nicht gefunden"
            report_add ERROR "freshclam.conf.sample not found"
            return 1
        fi
    fi

    [ ! -d "$db_dir" ] && mkdir -p "$db_dir" && report_add FIX "Created ClamAV DB dir"

    log INFO "   Aktualisiere Virus-Definitionen..."
    run_verbose sudo freshclam
    if [ $? -eq 0 ]; then
        report_add SUCCESS "Virus definitions updated"
    else
        report_add WARN "freshclam reported an issue"
    fi

    if $DRY_RUN; then
        log STEP "   [DRY-RUN] wuerde clamscan auf $HOME ausfuehren"
        return 0
    fi

    # Fix #39: Exclude-Liste als Array (kein eval noetig)
    log INFO "   Scanne $HOME (kann dauern)..."
    local -a exclude_args=(
        --exclude-dir='^/Volumes'
        '--exclude-dir=\.ollama/models'
        '--exclude-dir=Library/Application Support/LM Studio'
        '--exclude-dir=Library/Caches'
        '--exclude-dir=\.Trash'
        '--exclude-dir=node_modules'
        '--exclude-dir=\.git/objects'
        '--exclude-dir=miniforge3'
        '--exclude-dir=Parallels'
        '--exclude-dir=Venvs'
        '--exclude-dir=go/pkg'
    )

    log STEP "   Excludes: Volumes, .ollama/models, Caches, .Trash, node_modules, .git, miniforge3, Parallels, Venvs, go/pkg"

    local scan_start=$(date +%s)

    clamscan -r --bell -i "${exclude_args[@]}" "$HOME" 2>&1 | while IFS= read -r line; do
        case "$line" in
            *FOUND*) log ERROR "   FUND: $line" ;;
            *"Scanned files"*|*"Infected files"*|*"Time"*|*"Known viruses"*)
                log INFO "   $line" ;;
        esac
    done
    local scan_rc=${PIPESTATUS[0]}

    local scan_end=$(date +%s)
    local scan_dur=$(( (scan_end - scan_start) / 60 ))
    log INFO "   Scan abgeschlossen in ~${scan_dur} Minuten"

    if [ "$scan_rc" -eq 0 ]; then
        report_add SUCCESS "ClamAV: No Malware Found"
    elif [ "$scan_rc" -eq 1 ]; then
        report_add ERROR "MALWARE FOUND! CHECK LOGS!"
        log ERROR "MALWARE FOUND!"
    else
        report_add WARN "ClamAV Scan beendet (Exit: $scan_rc)"
    fi
}

# ── SYSTEM & CLEANUP ──

module_system() {
    log INFO "macOS System-Update Pruefung..."
    log STEP "   Pruefe softwareupdate..."
    local sysup=$(softwareupdate -l 2>&1)

    if echo "$sysup" | grep -q "No new software"; then
        log INFO "   macOS ist aktuell"
        report_add SUCCESS "macOS is up to date"
    else
        local update_count=$(echo "$sysup" | grep -c "^\*" 2>/dev/null || echo "?")
        log WARN "   ${update_count} macOS Updates verfuegbar:"
        echo "$sysup" | grep "^\*\|Label\|Title" | while IFS= read -r line; do
            log STEP "     $line"
        done

        # Fix #26: Recommended Updates automatisch installieren (kein Restart)
        local has_restart=$(echo "$sysup" | grep -ci "restart" 2>/dev/null || echo 0)
        local has_recommended=$(echo "$sysup" | grep -ci "Recommended: YES" 2>/dev/null || echo 0)

        if [ "$has_recommended" -gt 0 ] && [ "$has_restart" -eq 0 ]; then
            log INFO "   Installiere empfohlene Updates (kein Restart noetig)..."
            run_verbose sudo softwareupdate --install --recommended --agree-to-license
            if [ $? -eq 0 ]; then
                report_add FIX "macOS Recommended Updates installiert"
            else
                report_add WARN "macOS Update Installation fehlgeschlagen"
            fi
        elif [ "$has_restart" -gt 0 ]; then
            log WARN "   Updates benoetigen Restart - ueberspringe Auto-Install"
            report_add WARN "macOS Update verfuegbar (Restart noetig, manuell installieren)"
        else
            report_add WARN "macOS Update Available ($update_count)"
        fi
    fi

    # Disk-Usage Check
    local disk_pct=$(df -h / | awk 'NR==2 {gsub(/%/,"",$5); print $5}')
    local disk_free=$(df -h / | awk 'NR==2 {print $4}')
    log INFO "   Disk: ${disk_pct}% belegt, ${disk_free} frei"
    if [ "$disk_pct" -gt "$DISK_USAGE_THRESHOLD" ] 2>/dev/null; then
        log WARN "   Disk-Usage ueber ${DISK_USAGE_THRESHOLD}%!"
        report_add WARN "Disk usage: ${disk_pct}% (>${DISK_USAGE_THRESHOLD}%)"

        if ollama_available; then
            log HEAL "Frage Ollama nach Platz-Tipps..."
            local tip
            tip=$(ollama_query "macOS Disk ${disk_pct}% voll, ${disk_free} frei. Liste 3-5 sichere Shell-Befehle um Platz zu schaffen. Nur Commands, eine pro Zeile. Keine Erklaerungen, keine <think>-Tags.")
            if [ -n "$tip" ] && [ "$tip" != "NOFIX" ]; then
                log HEAL "Ollama Platz-Tipps:"
                echo "$tip" | while IFS= read -r line; do
                    [ -n "$line" ] && log STEP "   > $line"
                done
                report_add WARN "Ollama Platz-Tipps im Log (manuell pruefen)"
            fi
        fi
    fi
}

module_cleanup() {
    log INFO "Bereinigung..."

    if $CLEAN_XCODE; then
        local xcpath="$HOME/Library/Developer/Xcode/DerivedData"
        if [ -d "$xcpath" ]; then
            local xc_size=$(du -sh "$xcpath" 2>/dev/null | awk '{print $1}')
            log INFO "   Loesche Xcode DerivedData ($xc_size)..."
            run_or_dry rm -rf "$xcpath"
            report_add FIX "Deleted Xcode DerivedData ($xc_size)"
        else
            log INFO "   Kein Xcode DerivedData vorhanden"
        fi
    else
        log STEP "   Xcode clean: uebersprungen (-X)"
    fi

    if $RUN_MONOLINGUAL; then
        ensure_tool "monolingual" "monolingual"
        report_add WARN "Monolingual installed (Run manually)"
    else
        log STEP "   Monolingual: uebersprungen (-M)"
    fi

    if $EMPTY_TRASH; then
        local trash_count=$(ls -1 "$HOME/.Trash" 2>/dev/null | wc -l | xargs)
        log INFO "   Leere Papierkorb ($trash_count Elemente)..."
        run_or_dry rm -rf "$HOME/.Trash"/*
        report_add FIX "Emptied Trash ($trash_count items)"
    else
        log STEP "   Papierkorb: uebersprungen (-T)"
    fi

    if $CLEAN_CACHES; then
        local cache_size=$(du -sh "$HOME/Library/Caches" 2>/dev/null | awk '{print $1}')
        log INFO "   Loesche User Caches ($cache_size)..."
        run_or_dry rm -rf "$HOME/Library/Caches"/*
        report_add FIX "Cleaned User Caches ($cache_size)"
        if $NEEDS_SUDO; then
            log INFO "   Loesche System Caches (sudo)..."
            run_or_dry sudo rm -rf /Library/Caches/* /System/Library/Caches/* /private/var/tmp/*
            report_add FIX "Cleaned System Caches"
        fi
    else
        log STEP "   Cache clean: uebersprungen (-C)"
    fi

    if $LIST_LARGE_FILES; then
        log INFO "   Suche Dateien groesser ${LARGE_FILE_SIZE_MB}MB..."
        local large_files=$(find "$HOME" -xdev -type f -size +${LARGE_FILE_SIZE_MB}M -print0 2>/dev/null | xargs -0 ls -lh 2>/dev/null | awk '{print $5, $9}')
        if [ -n "$large_files" ]; then
            local lf_count=$(echo "$large_files" | wc -l | xargs)
            log INFO "   ${lf_count} grosse Dateien gefunden:"
            echo "$large_files" | head -10 | while IFS= read -r line; do
                log STEP "     $line"
            done
            [ "$lf_count" -gt 10 ] && log STEP "     ... und $((lf_count - 10)) weitere (siehe Log)"
            echo "$large_files" >> "$LOGFILE"
        else
            log INFO "   Keine Dateien groesser ${LARGE_FILE_SIZE_MB}MB"
        fi
        report_add SUCCESS "Large files logged"
    else
        log STEP "   Grosse Dateien: uebersprungen (-L)"
    fi
}

#############################
# 6. DEEP CLEAN & SYSTEM-HYGIENE (Fix #54-#67)
#############################

module_deepclean() {
    log INFO "Deep Clean & System-Hygiene..."
    local total_freed=0

    # Fix #54: System-Logs aufraumen
    log STEP "   [1/14] System-Logs..."
    local user_log_size=$(du -sm "$HOME/Library/Logs" 2>/dev/null | awk '{print $1}')
    [ -z "$user_log_size" ] && user_log_size=0
    if [ "$user_log_size" -gt 50 ]; then
        log INFO "   User-Logs: ${user_log_size} MB - raeume auf..."
        run_or_dry find "$HOME/Library/Logs" -type f -mtime +30 -delete
        local new_size=$(du -sm "$HOME/Library/Logs" 2>/dev/null | awk '{print $1}')
        [ -z "$new_size" ] && new_size=0
        local freed=$((user_log_size - new_size))
        [ "$freed" -gt 0 ] && { total_freed=$((total_freed + freed)); log FIX "   ${freed} MB User-Logs bereinigt"; }
    else
        log STEP "   User-Logs: ${user_log_size} MB (OK)"
    fi
    if $NEEDS_SUDO; then
        local sys_log_size=$(sudo du -sm /private/var/log 2>/dev/null | awk '{print $1}')
        [ -z "$sys_log_size" ] && sys_log_size=0
        if [ "$sys_log_size" -gt 200 ]; then
            log INFO "   System-Logs: ${sys_log_size} MB - raeume auf..."
            run_or_dry sudo find /private/var/log -type f -name "*.log" -mtime +30 -delete
            run_or_dry sudo rm -rf /private/var/log/asl/*.asl 2>/dev/null
            local freed_sys=$((sys_log_size - $(sudo du -sm /private/var/log 2>/dev/null | awk '{print $1}')))
            [ "$freed_sys" -gt 0 ] 2>/dev/null && { total_freed=$((total_freed + freed_sys)); log FIX "   ${freed_sys} MB System-Logs bereinigt"; }
        else
            log STEP "   System-Logs: ${sys_log_size} MB (OK)"
        fi
    fi

    # Fix #55: DMG/PKG/ZIP in Downloads (>30 Tage)
    log STEP "   [2/14] Downloads aufraeumen..."
    local dl_junk_count=0
    local dl_junk_size=0
    while IFS= read -r f; do
        [ -z "$f" ] && continue
        dl_junk_count=$((dl_junk_count + 1))
        local fsize=$(stat -f%z "$f" 2>/dev/null || echo 0)
        dl_junk_size=$((dl_junk_size + ${fsize:-0}))
    done < <(find "$HOME/Downloads" -maxdepth 1 -type f \( -name "*.dmg" -o -name "*.pkg" -o -name "*.zip" -o -name "*.tar.gz" -o -name "*.iso" \) -mtime +30 2>/dev/null)
    if [ "$dl_junk_count" -gt 0 ]; then
        local dl_mb=$((dl_junk_size / 1048576))
        log INFO "   ${dl_junk_count} alte Installer in Downloads (${dl_mb} MB, >30 Tage)"
        run_or_dry find "$HOME/Downloads" -maxdepth 1 -type f \( -name "*.dmg" -o -name "*.pkg" -o -name "*.zip" -o -name "*.tar.gz" -o -name "*.iso" \) -mtime +30 -delete
        total_freed=$((total_freed + dl_mb))
        report_add FIX "Downloads: ${dl_junk_count} alte Installer geloescht (${dl_mb} MB)"
    else
        log STEP "   Downloads: keine alten Installer"
    fi

    # Fix #56/#85: Orphaned Preferences - Batch-mdfind statt einzeln (~50-100s gespart)
    log STEP "   [3/14] Orphaned Preferences..."
    local orphan_count=0
    local installed_ids_file=$(mktemp)
    # Alle installierten Bundle-IDs in EINEM mdfind+mdls Aufruf sammeln
    mdfind "kMDItemContentType == 'com.apple.application-bundle'" 2>/dev/null | \
        xargs mdls -name kMDItemCFBundleIdentifier 2>/dev/null | \
        awk -F'"' '/kMDItemCFBundleIdentifier/ && $2 != "" {print $2}' | \
        sort -u > "$installed_ids_file"
    for plist in "$HOME/Library/Preferences"/*.plist; do
        [ ! -f "$plist" ] && continue
        local bundle_id=$(basename "$plist" .plist)
        # System-Prefs und Apple-eigene ueberspringen
        [[ "$bundle_id" == com.apple.* ]] && continue
        [[ "$bundle_id" == Apple.* ]] && continue
        [[ "$bundle_id" == loginwindow ]] && continue
        [[ "$bundle_id" == com.meister* ]] && continue
        # Fix #85: Pruefen gegen gecachte Bundle-ID-Liste (grep statt mdfind pro Plist)
        if ! grep -qxF "$bundle_id" "$installed_ids_file" 2>/dev/null; then
            orphan_count=$((orphan_count + 1))
            [ "$orphan_count" -le 50 ] && log STEP "     Orphan: $bundle_id"
        fi
    done
    rm -f "$installed_ids_file"
    if [ "$orphan_count" -gt 0 ]; then
        log INFO "   ${orphan_count} verwaiste Preferences gefunden"
        report_add WARN "Deepclean: ${orphan_count} verwaiste Preferences (manuell pruefen)"
    else
        log STEP "   Keine verwaisten Preferences"
    fi

    # Fix #82: Broken Plists erkennen (parallelisiert)
    log STEP "   [4/14] Broken Plists..."
    local broken_count=0
    local broken_list
    broken_list=$(find "$HOME/Library/Preferences" -name "*.plist" -print0 2>/dev/null | \
        xargs -0 -P 4 -I {} sh -c 'plutil -lint "$1" >/dev/null 2>&1 || basename "$1"' _ {} 2>/dev/null)
    if [ -n "$broken_list" ]; then
        while IFS= read -r bp; do
            [ -z "$bp" ] && continue
            broken_count=$((broken_count + 1))
            [ "$broken_count" -le 20 ] && log WARN "   Defekt: $bp"
        done <<< "$broken_list"
        report_add WARN "Deepclean: ${broken_count} defekte Plists"
    else
        log STEP "   Alle Plists OK"
    fi

    # Fix #58: Mail-Attachments (Groesse anzeigen + warnen)
    log STEP "   [5/14] Mail-Attachments..."
    local mail_dir="$HOME/Library/Mail"
    if [ -d "$mail_dir" ]; then
        local mail_size=$(du -sm "$mail_dir" 2>/dev/null | awk '{print $1}')
        [ -z "$mail_size" ] && mail_size=0
        local attach_size=0
        while IFS= read -r d; do
            local ds=$(du -sm "$d" 2>/dev/null | awk '{print $1}')
            attach_size=$((attach_size + ${ds:-0}))
        done < <(find "$mail_dir" -name "Attachments" -type d 2>/dev/null)
        log STEP "   Mail: ${mail_size} MB gesamt, Attachments: ${attach_size} MB"
        if [ "$attach_size" -gt 500 ]; then
            log WARN "   Mail-Attachments > 500 MB! Empfehlung: In Mail.app Attachments loeschen"
            report_add WARN "Mail-Attachments: ${attach_size} MB (manuell pruefen)"
        fi
    else
        log STEP "   Kein Mail-Verzeichnis"
    fi

    # Fix #59: Screenshots aufraumen (Desktop + Schreibtisch, >30 Tage)
    log STEP "   [6/14] Alte Screenshots..."
    local screenshot_count=0
    local screenshot_mb=0
    for dir in "$HOME/Desktop" "$HOME/Schreibtisch"; do
        [ ! -d "$dir" ] && continue
        while IFS= read -r f; do
            [ -z "$f" ] && continue
            screenshot_count=$((screenshot_count + 1))
            local fsize=$(stat -f%z "$f" 2>/dev/null || echo 0)
            screenshot_mb=$((screenshot_mb + ${fsize:-0} / 1048576))
        done < <(find "$dir" -maxdepth 1 -type f \( -name "Screenshot*" -o -name "Bildschirmfoto*" -o -name "Screen Shot*" \) -mtime +30 2>/dev/null)
    done
    if [ "$screenshot_count" -gt 0 ]; then
        log INFO "   ${screenshot_count} alte Screenshots (${screenshot_mb} MB, >30 Tage)"
        for dir in "$HOME/Desktop" "$HOME/Schreibtisch"; do
            [ ! -d "$dir" ] && continue
            run_or_dry find "$dir" -maxdepth 1 -type f \( -name "Screenshot*" -o -name "Bildschirmfoto*" -o -name "Screen Shot*" \) -mtime +30 -delete
        done
        total_freed=$((total_freed + screenshot_mb))
        report_add FIX "Screenshots: ${screenshot_count} geloescht (${screenshot_mb} MB)"
    else
        log STEP "   Keine alten Screenshots"
    fi

    # Fix #60: Time Machine lokale Snapshots
    log STEP "   [7/14] Time Machine Snapshots..."
    local tm_snapshots=$(tmutil listlocalsnapshots / 2>/dev/null | grep -c "com.apple" || echo 0)
    if [ "$tm_snapshots" -gt 0 ]; then
        # Purgeable Space durch TM Snapshots berechnen
        local tm_purgeable=$(tmutil listlocalsnapshots / 2>/dev/null | wc -l | xargs)
        log INFO "   ${tm_purgeable} lokale TM-Snapshots gefunden"
        local disk_pct=$(df -h / | awk 'NR==2 {gsub(/%/,"",$5); print $5}')
        if [ "$disk_pct" -gt "$DISK_USAGE_THRESHOLD" ] 2>/dev/null; then
            log WARN "   Disk ${disk_pct}% voll - loesche alte TM-Snapshots..."
            # Fix #69: Korrektes Snapshot-Datum extrahieren (Format: com.apple.TimeMachine.YYYY-MM-DD-HHMMSS.local)
            tmutil listlocalsnapshots / 2>/dev/null | sed -n 's/.*TimeMachine\.\(.*\)\.local/\1/p' | while IFS= read -r snap; do
                [ -n "$snap" ] && run_or_dry sudo tmutil deletelocalsnapshots "$snap"
            done
            report_add FIX "TM-Snapshots geloescht (Disk war ${disk_pct}%)"
        else
            report_add SUCCESS "TM-Snapshots: ${tm_purgeable} vorhanden (Disk OK)"
        fi
    else
        log STEP "   Keine lokalen TM-Snapshots"
    fi

    # Fix #61: RAM freigeben
    log STEP "   [8/14] RAM freigeben..."
    local mem_before
    mem_before=$(vm_stat 2>/dev/null | awk '/Pages free:/ {gsub(/\./,"",$3); print $3}')
    if $NEEDS_SUDO && ! $DRY_RUN; then
        sudo purge 2>/dev/null
        local mem_after
        mem_after=$(vm_stat 2>/dev/null | awk '/Pages free:/ {gsub(/\./,"",$3); print $3}')
        local pagesize=$(sysctl -n hw.pagesize 2>/dev/null || echo 16384)
        local freed_ram=$(( (${mem_after:-0} - ${mem_before:-0}) * pagesize / 1048576 ))
        [ "$freed_ram" -gt 0 ] 2>/dev/null && log FIX "   ${freed_ram} MB RAM freigegeben"
        [ "$freed_ram" -le 0 ] 2>/dev/null && log STEP "   RAM-Purge ausgefuehrt (kein messbarer Gewinn)"
    else
        log STEP "   RAM-Purge: uebersprungen (sudo noetig oder Dry-Run)"
    fi

    # Fix #62: Launch Services DB rebuild
    log STEP "   [9/14] Launch Services DB..."
    local ls_register="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
    if [ -x "$ls_register" ]; then
        run_or_dry "$ls_register" -kill -r -domain local -domain system -domain user
        log FIX "   Launch Services DB neu aufgebaut"
        report_add FIX "Launch Services DB rebuilt"
    else
        log STEP "   lsregister nicht gefunden"
    fi

    # Fix #63: Spotlight reindexieren (nur wenn Probleme erkannt)
    log STEP "   [10/14] Spotlight-Status..."
    local mdutil_status=$(mdutil -s / 2>/dev/null)
    if echo "$mdutil_status" | grep -qi "disabled\|error"; then
        log WARN "   Spotlight deaktiviert oder fehlerhaft - reindexiere..."
        run_or_dry sudo mdutil -E / 2>/dev/null
        run_or_dry sudo mdutil -i on / 2>/dev/null
        report_add FIX "Spotlight reindexiert"
    else
        log STEP "   Spotlight OK"
    fi

    # Fix #64: Recent Items loeschen
    log STEP "   [11/14] Recent Items..."
    run_or_dry defaults delete com.apple.recentitems RecentDocuments 2>/dev/null
    run_or_dry defaults delete com.apple.recentitems RecentApplications 2>/dev/null
    run_or_dry defaults delete com.apple.recentitems RecentServers 2>/dev/null
    log FIX "   Recent Items geloescht"
    report_add FIX "Recent Items bereinigt"

    # Fix #65: Duplikate finden (nur Report, kein Loeschen)
    log STEP "   [12/14] Duplikate..."
    if command_exists fdupes; then
        local dup_output
        dup_output=$(timeout 120 fdupes -r -q "$HOME/Downloads" "$HOME/Desktop" 2>/dev/null | head -50)
        if [ -n "$dup_output" ]; then
            local dup_count=$(echo "$dup_output" | grep -c "^/")
            log INFO "   ${dup_count} Duplikate gefunden (Top 50 im Log)"
            echo "$dup_output" >> "$LOGFILE"
            report_add WARN "Deepclean: ${dup_count} Duplikate in Downloads/Desktop (siehe Log)"
        else
            log STEP "   Keine Duplikate in Downloads/Desktop"
        fi
    else
        log STEP "   fdupes nicht installiert (brew install fdupes fuer Duplikat-Erkennung)"
    fi

    # Fix #66: Alte iOS-Backups
    log STEP "   [13/14] iOS-Backups..."
    local backup_dir="$HOME/Library/Application Support/MobileSync/Backup"
    if [ -d "$backup_dir" ]; then
        local backup_count=0
        local backup_total_mb=0
        while IFS= read -r d; do
            [ ! -d "$d" ] && continue
            local bsize=$(du -sm "$d" 2>/dev/null | awk '{print $1}')
            [ -z "$bsize" ] && bsize=0
            backup_count=$((backup_count + 1))
            backup_total_mb=$((backup_total_mb + bsize))
            local bname=$(basename "$d")
            log STEP "     Backup: ${bname:0:12}... (${bsize} MB)"
        done < <(find "$backup_dir" -maxdepth 1 -mindepth 1 -type d 2>/dev/null)
        if [ "$backup_count" -gt 0 ]; then
            log INFO "   ${backup_count} iOS-Backups, gesamt ${backup_total_mb} MB"
            if [ "$backup_total_mb" -gt 10240 ]; then
                report_add WARN "iOS-Backups: ${backup_total_mb} MB (${backup_count} Stueck, manuell pruefen)"
            else
                report_add SUCCESS "iOS-Backups: ${backup_count} (${backup_total_mb} MB)"
            fi
        else
            log STEP "   Keine iOS-Backups"
        fi
    else
        log STEP "   Kein iOS-Backup-Verzeichnis"
    fi

    # Fix #67: Login Items auflisten + tote erkennen
    log STEP "   [14/14] Login Items..."
    local login_items
    login_items=$(osascript -e 'tell application "System Events" to get the name of every login item' 2>/dev/null)
    if [ -n "$login_items" ]; then
        log INFO "   Login Items: $login_items"
        # Fix #92: Tote Login Items via Batch-Erkennung (1x mdfind statt pro Item)
        local dead_items=0
        local all_apps_file=$(mktemp)
        mdfind "kMDItemContentType == 'com.apple.application-bundle'" 2>/dev/null | \
            xargs -I{} basename {} .app 2>/dev/null | sort -u > "$all_apps_file"
        IFS=', ' read -ra items <<< "$login_items"
        for item in "${items[@]}"; do
            item="${item#"${item%%[![:space:]]*}"}"
            item="${item%"${item##*[![:space:]]}"}"
            [ -z "$item" ] && continue
            if ! grep -qxF "$item" "$all_apps_file" 2>/dev/null; then
                dead_items=$((dead_items + 1))
                log WARN "   Toter Login Item: $item (App nicht gefunden)"
            fi
        done
        rm -f "$all_apps_file"
        if [ "$dead_items" -gt 0 ]; then
            report_add WARN "Deepclean: ${dead_items} tote Login Items"
        fi
    else
        log STEP "   Keine Login Items konfiguriert"
    fi

    # Fix #72: Package Manager Caches (npm/pip/yarn/gem)
    if $CLEAN_PKG_CACHES; then
        log STEP "   [15/20] Package Manager Caches..."
        local pkg_freed=0

        if command_exists npm && [ -d "$HOME/.npm" ]; then
            local npm_size=$(du -sm "$HOME/.npm" 2>/dev/null | awk '{print $1}')
            [ -z "$npm_size" ] && npm_size=0
            if [ "$npm_size" -gt 50 ]; then
                log INFO "   npm cache: ${npm_size} MB"
                run_or_dry npm cache clean --force 2>/dev/null
                pkg_freed=$((pkg_freed + npm_size))
            else
                log STEP "   npm cache: ${npm_size} MB (OK)"
            fi
        fi

        if command_exists yarn && [ -d "$HOME/.yarn/cache" ]; then
            local yarn_size=$(du -sm "$HOME/.yarn/cache" 2>/dev/null | awk '{print $1}')
            [ -z "$yarn_size" ] && yarn_size=0
            if [ "$yarn_size" -gt 50 ]; then
                log INFO "   yarn cache: ${yarn_size} MB"
                run_or_dry yarn cache clean 2>/dev/null
                pkg_freed=$((pkg_freed + yarn_size))
            fi
        fi

        if command_exists pip3; then
            local pip_dir="$HOME/Library/Caches/pip"
            if [ -d "$pip_dir" ]; then
                local pip_size=$(du -sm "$pip_dir" 2>/dev/null | awk '{print $1}')
                [ -z "$pip_size" ] && pip_size=0
                if [ "$pip_size" -gt 50 ]; then
                    log INFO "   pip cache: ${pip_size} MB"
                    run_or_dry pip3 cache purge 2>/dev/null
                    pkg_freed=$((pkg_freed + pip_size))
                fi
            fi
        fi

        if command_exists gem && [ -d "$HOME/.gem" ]; then
            local gem_size=$(du -sm "$HOME/.gem" 2>/dev/null | awk '{print $1}')
            [ -z "$gem_size" ] && gem_size=0
            if [ "$gem_size" -gt 50 ]; then
                log INFO "   gem cache: ${gem_size} MB"
                run_or_dry gem cleanup 2>/dev/null
                pkg_freed=$((pkg_freed + gem_size / 2))
            fi
        fi

        if [ "$pkg_freed" -gt 0 ]; then
            total_freed=$((total_freed + pkg_freed))
            report_add FIX "Package Caches: ${pkg_freed} MB bereinigt"
        else
            log STEP "   Alle Package Caches klein oder nicht vorhanden"
        fi
    else
        log STEP "   Package Caches: uebersprungen (Config)"
    fi

    # Fix #73: Developer Tool Caches (CocoaPods/SPM/Carthage)
    if $CLEAN_DEV_CACHES; then
        log STEP "   [16/20] Developer Tool Caches..."
        local dev_freed=0

        if [ -d "$HOME/.cocoapods/repos" ]; then
            local pods_size=$(du -sm "$HOME/.cocoapods/repos" 2>/dev/null | awk '{print $1}')
            [ -z "$pods_size" ] && pods_size=0
            if [ "$pods_size" -gt 100 ]; then
                log INFO "   CocoaPods repos: ${pods_size} MB"
                run_or_dry rm -rf "$HOME/.cocoapods/repos/trunk"
                dev_freed=$((dev_freed + pods_size / 2))
            fi
        fi

        if [ -d "$HOME/.swiftpm/cache" ]; then
            local spm_size=$(du -sm "$HOME/.swiftpm/cache" 2>/dev/null | awk '{print $1}')
            [ -z "$spm_size" ] && spm_size=0
            if [ "$spm_size" -gt 100 ]; then
                log INFO "   SPM cache: ${spm_size} MB"
                run_or_dry rm -rf "$HOME/.swiftpm/cache"/*
                dev_freed=$((dev_freed + spm_size))
            fi
        fi

        local carthage_dir="$HOME/Library/Caches/org.carthage.CarthageKit"
        if [ -d "$carthage_dir" ]; then
            local cart_size=$(du -sm "$carthage_dir" 2>/dev/null | awk '{print $1}')
            [ -z "$cart_size" ] && cart_size=0
            if [ "$cart_size" -gt 100 ]; then
                log INFO "   Carthage cache: ${cart_size} MB"
                run_or_dry rm -rf "$carthage_dir"/*
                dev_freed=$((dev_freed + cart_size))
            fi
        fi

        if [ "$dev_freed" -gt 0 ]; then
            total_freed=$((total_freed + dev_freed))
            report_add FIX "Developer Caches: ${dev_freed} MB bereinigt"
        else
            log STEP "   Alle Developer Caches klein oder nicht vorhanden"
        fi
    else
        log STEP "   Developer Caches: uebersprungen (Config)"
    fi

    # Fix #74: Docker Cleanup
    if $CLEAN_DOCKER && command_exists docker; then
        log STEP "   [17/20] Docker Cleanup..."
        if docker info &>/dev/null; then
            local stopped=$(docker ps -aq --filter status=exited 2>/dev/null | wc -l | xargs)
            local dangling=$(docker images -f "dangling=true" -q 2>/dev/null | wc -l | xargs)
            if [ "${stopped:-0}" -gt 0 ] || [ "${dangling:-0}" -gt 0 ]; then
                log INFO "   Docker: ${stopped} stopped containers, ${dangling} dangling images"
                run_or_dry docker container prune -f --filter "until=72h" 2>/dev/null
                run_or_dry docker image prune -f 2>/dev/null
                run_or_dry docker volume prune -f 2>/dev/null
                report_add FIX "Docker: ${stopped} Container + ${dangling} Images aufgeraeumt"
            else
                log STEP "   Docker: sauber"
            fi
        else
            log STEP "   Docker: Daemon nicht erreichbar"
        fi
    elif $CLEAN_DOCKER; then
        log STEP "   Docker: nicht installiert"
    else
        log STEP "   Docker: uebersprungen (Config: CLEAN_DOCKER=false)"
    fi

    # Fix #75: Parallels VM-Logs
    if $CLEAN_PARALLELS_LOGS && [ -d "$HOME/Library/Parallels" ]; then
        log STEP "   [18/20] Parallels VM-Logs..."
        local prl_log_count
        prl_log_count=$(find "$HOME/Library/Parallels" -name "*.log" -mtime +30 2>/dev/null | wc -l | xargs)
        if [ "${prl_log_count:-0}" -gt 0 ]; then
            local prl_size=$(find "$HOME/Library/Parallels" -name "*.log" -mtime +30 -exec du -sm {} + 2>/dev/null | awk '{s+=$1} END {print s+0}')
            log INFO "   Parallels: ${prl_log_count} alte Logs (${prl_size:-0} MB)"
            run_or_dry find "$HOME/Library/Parallels" -name "*.log" -mtime +30 -delete
            total_freed=$((total_freed + ${prl_size:-0}))
            report_add FIX "Parallels Logs: ${prl_log_count} geloescht"
        else
            log STEP "   Parallels: keine alten Logs"
        fi
    else
        log STEP "   Parallels: uebersprungen"
    fi

    # Fix #76: Font-Cache + QuickLook-Cache rebuild
    if $CLEAN_FONT_CACHE; then
        log STEP "   [19/20] Font & QuickLook Cache..."
        # Font-Cache
        if [ -x /usr/bin/atsutil ]; then
            run_or_dry atsutil databases -remove 2>/dev/null
            log FIX "   Font-Cache neuaufgebaut"
        fi
        # QuickLook-Cache
        local ql_dir="$HOME/Library/Caches/com.apple.QuickLookDaemon"
        if [ -d "$ql_dir" ]; then
            local ql_size=$(du -sm "$ql_dir" 2>/dev/null | awk '{print $1}')
            run_or_dry rm -rf "$ql_dir"
            log FIX "   QuickLook-Cache geloescht (${ql_size:-0} MB)"
            total_freed=$((total_freed + ${ql_size:-0}))
        fi
        # qlmanage Reset
        run_or_dry qlmanage -r 2>/dev/null
        report_add FIX "Font & QuickLook Cache rebuilt"
    else
        log STEP "   Font/QuickLook Cache: uebersprungen (Config)"
    fi

    # Fix #77/#86: Quarantine-Attribute entfernen (parallelisiert)
    if $CLEAN_QUARANTINE; then
        log STEP "   [20/20] Quarantine-Attribute..."
        if $DRY_RUN; then
            local qtn_count=$(find "$HOME/Downloads" -maxdepth 1 -type f -exec sh -c 'xattr -p com.apple.quarantine "$1" &>/dev/null && echo x' _ {} \; 2>/dev/null | wc -l | xargs)
            log STEP "   [DRY-RUN] wuerde ${qtn_count:-0} Quarantine-Attribute entfernen"
        else
            # Fix #86: xargs -P 8 fuer parallele Verarbeitung
            local qtn_removed
            qtn_removed=$(find "$HOME/Downloads" -maxdepth 1 -type f -print0 2>/dev/null | \
                xargs -0 -P 8 -I{} sh -c 'xattr -p com.apple.quarantine "$1" &>/dev/null && xattr -d com.apple.quarantine "$1" && echo 1' _ {} 2>/dev/null)
            local qtn_count=0
            [ -n "$qtn_removed" ] && qtn_count=$(echo "$qtn_removed" | wc -l | xargs)
            if [ "$qtn_count" -gt 0 ]; then
                log FIX "   ${qtn_count} Quarantine-Attribute entfernt"
                report_add FIX "Quarantine: ${qtn_count} Attribute entfernt"
            else
                log STEP "   Keine Quarantine-Attribute in Downloads"
            fi
        fi
    else
        log STEP "   Quarantine: uebersprungen (Config)"
    fi

    # Zusammenfassung
    if [ "$total_freed" -gt 0 ]; then
        log FIX "   Deep Clean: ${total_freed} MB insgesamt freigegeben"
        report_add FIX "Deep Clean: ${total_freed} MB freigegeben"
    fi
}

#############################
# 6c. macOS PERFORMANCE OPTIMIERUNG (Fix #93)
#############################

module_performance() {
    log INFO "macOS Performance Optimierung..."
    local perf_fixes=0
    local perf_warns=0

    # Fix #110: ps-Output einmal cachen statt 5x forken
    local _ps_rss_cache _ps_cpu_cache
    _ps_rss_cache=$(ps -eo rss=,pid=,comm=,uid= 2>/dev/null)
    _ps_cpu_cache=$(ps -eo %cpu=,pid=,comm= 2>/dev/null)

    # ── [1/16] DNS Performance ──
    log STEP "   [1/16] DNS Performance..."
    local primary_iface=$(route -n get default 2>/dev/null | awk '/interface:/ {print $2}')
    if [ -n "$primary_iface" ]; then
        local active_service
        active_service=$(networksetup -listallhardwareports 2>/dev/null | \
            awk -v dev="$primary_iface" '/Hardware Port:/{p=$0; sub(/.*: /,"",p)} /Device:/{if($2==dev) print p}')
        if [ -n "$active_service" ]; then
            local current_dns=$(networksetup -getdnsservers "$active_service" 2>/dev/null)
            if echo "$current_dns" | grep -qi "any DNS"; then
                if $RUN_PERF_TUNE && $PERF_DNS_OPTIMIZE; then
                    run_or_dry networksetup -setdnsservers "$active_service" 1.1.1.1 1.0.0.1 8.8.8.8 8.8.4.4
                    run_or_dry sudo dscacheutil -flushcache 2>/dev/null
                    run_or_dry sudo killall -HUP mDNSResponder 2>/dev/null
                    log FIX "   DNS: 1.1.1.1 / 8.8.8.8 gesetzt ($active_service)"
                    report_add FIX "DNS auf Cloudflare/Google optimiert"
                    perf_fixes=$((perf_fixes + 1))
                else
                    log WARN "   Kein DNS konfiguriert (ISP-Default) - 1.1.1.1/8.8.8.8 empfohlen (-P)"
                    report_add WARN "DNS: ISP-Default (Cloudflare/Google empfohlen)"
                    perf_warns=$((perf_warns + 1))
                fi
            else
                # DNS-Latenz testen
                local dns_ms_raw=$(curl -so /dev/null -w "%{time_namelookup}" https://www.apple.com 2>/dev/null)
                local dns_ms_int=$(echo "${dns_ms_raw:-0} * 1000" | bc 2>/dev/null | cut -d. -f1)
                if [ "${dns_ms_int:-0}" -gt 100 ]; then
                    log WARN "   DNS langsam: ${dns_ms_int}ms (>100ms)"
                    report_add WARN "DNS-Latenz hoch: ${dns_ms_int}ms"
                    perf_warns=$((perf_warns + 1))
                else
                    log STEP "   DNS OK: ${dns_ms_int:-?}ms ($(echo "$current_dns" | head -1))"
                fi
            fi
        fi
    fi

    # ── [2/16] TCP/Netzwerk Tuning ──
    log STEP "   [2/16] Netzwerk Tuning..."
    local tcp_send=$(sysctl -n net.inet.tcp.sendspace 2>/dev/null || echo 0)
    local tcp_recv=$(sysctl -n net.inet.tcp.recvspace 2>/dev/null || echo 0)
    local tcp_auto_snd=$(sysctl -n net.inet.tcp.autosndbufmax 2>/dev/null || echo 0)
    local tcp_auto_rcv=$(sysctl -n net.inet.tcp.autorcvbufmax 2>/dev/null || echo 0)
    local tcp_tuned=false
    if [ "$tcp_send" -lt 262144 ] 2>/dev/null || [ "$tcp_recv" -lt 262144 ] 2>/dev/null; then
        if $RUN_PERF_TUNE && $PERF_SYSCTL_TUNE && $NEEDS_SUDO; then
            run_or_dry sudo sysctl -w net.inet.tcp.sendspace=262144
            run_or_dry sudo sysctl -w net.inet.tcp.recvspace=262144
            log FIX "   TCP-Buffer: Send/Recv auf 256KB erhoeht"
            tcp_tuned=true
        else
            log STEP "   TCP-Buffer: Send=${tcp_send} Recv=${tcp_recv} (256KB empfohlen)"
            perf_warns=$((perf_warns + 1))
        fi
    else
        log STEP "   TCP-Buffer: OK (Send=${tcp_send} Recv=${tcp_recv})"
    fi
    if [ "$tcp_auto_snd" -lt 2097152 ] 2>/dev/null || [ "$tcp_auto_rcv" -lt 2097152 ] 2>/dev/null; then
        if $RUN_PERF_TUNE && $PERF_SYSCTL_TUNE && $NEEDS_SUDO; then
            run_or_dry sudo sysctl -w net.inet.tcp.autosndbufmax=2097152
            run_or_dry sudo sysctl -w net.inet.tcp.autorcvbufmax=2097152
            log FIX "   TCP Auto-Buffer-Max: 2MB gesetzt"
            tcp_tuned=true
        else
            log STEP "   TCP Auto-Max: Snd=${tcp_auto_snd} Rcv=${tcp_auto_rcv} (2MB empfohlen)"
        fi
    fi
    $tcp_tuned && { perf_fixes=$((perf_fixes + 1)); report_add FIX "TCP-Buffer optimiert"; }

    # ── [3/16] Kernel Limits ──
    log STEP "   [3/16] Kernel Limits..."
    local maxfiles=$(sysctl -n kern.maxfiles 2>/dev/null || echo 0)
    local maxfilesperproc=$(sysctl -n kern.maxfilesperproc 2>/dev/null || echo 0)
    local somaxconn=$(sysctl -n kern.ipc.somaxconn 2>/dev/null || echo 0)
    local kern_tuned=false
    if [ "$maxfiles" -lt 65536 ] 2>/dev/null || [ "$maxfilesperproc" -lt 32768 ] 2>/dev/null; then
        if $RUN_PERF_TUNE && $PERF_SYSCTL_TUNE && $NEEDS_SUDO; then
            [ "$maxfiles" -lt 65536 ] 2>/dev/null && run_or_dry sudo sysctl -w kern.maxfiles=65536
            [ "$maxfilesperproc" -lt 32768 ] 2>/dev/null && run_or_dry sudo sysctl -w kern.maxfilesperproc=32768
            log FIX "   Kernel: maxfiles=65536, maxfilesperproc=32768"
            kern_tuned=true
        else
            log STEP "   maxfiles=${maxfiles} maxfilesperproc=${maxfilesperproc}"
            [ "$maxfiles" -lt 65536 ] 2>/dev/null && { log WARN "   maxfiles < 65536 (Engpass fuer Dev-Tools)"; perf_warns=$((perf_warns + 1)); }
        fi
    else
        log STEP "   Kernel Limits OK (maxfiles=${maxfiles})"
    fi
    if [ "$somaxconn" -lt 1024 ] 2>/dev/null; then
        if $RUN_PERF_TUNE && $PERF_SYSCTL_TUNE && $NEEDS_SUDO; then
            run_or_dry sudo sysctl -w kern.ipc.somaxconn=2048
            log FIX "   somaxconn: ${somaxconn} -> 2048"
            kern_tuned=true
        else
            log STEP "   somaxconn=${somaxconn} (2048 empfohlen)"
        fi
    fi
    $kern_tuned && { perf_fixes=$((perf_fixes + 1)); report_add FIX "Kernel-Limits optimiert"; }

    # ── [4/16] SSD TRIM + SMART ──
    log STEP "   [4/16] SSD TRIM & SMART..."
    local disk_info=$(diskutil info disk0 2>/dev/null)
    local trim_status=$(echo "$disk_info" | awk -F: '/TRIM Support:/ {gsub(/^[ ]+/,"",$2); print $2}')
    if [ -n "$trim_status" ]; then
        if echo "$trim_status" | grep -qi "yes"; then
            log STEP "   TRIM: aktiviert"
        else
            log WARN "   TRIM: DEAKTIVIERT (SSD-Performance leidet!)"
            report_add WARN "SSD TRIM deaktiviert"
            perf_warns=$((perf_warns + 1))
        fi
    fi
    local smart_status=$(echo "$disk_info" | awk -F: '/SMART Status:/ {gsub(/^[ ]+/,"",$2); print $2}')
    if [ -n "$smart_status" ]; then
        if echo "$smart_status" | grep -qi "Verified"; then
            log STEP "   SMART: Verified"
        else
            log ERROR "   SMART: $smart_status - DISK PRUEFEN!"
            report_add ERROR "SMART Status: $smart_status"
        fi
    fi
    # APFS Container Health
    local apfs_free=$(diskutil apfs list 2>/dev/null | awk '/Free Space:/ {print $NF; exit}')
    [ -n "$apfs_free" ] && log STEP "   APFS Free: $apfs_free"

    # ── [5/16] Spotlight Exclusions ──
    if $PERF_SPOTLIGHT_EXCLUDE; then
        log STEP "   [5/16] Spotlight Exclusions..."
        local spotlight_excluded=0
        local spotlight_dirs=(
            "$HOME/go/pkg"
            "$HOME/miniforge3"
            "$HOME/Venvs"
            "$HOME/.ollama/models"
            "$HOME/.cargo"
            "$HOME/.rustup"
            "$HOME/.npm"
            "$HOME/.gradle"
            "$HOME/.docker"
        )
        for sdir in "${spotlight_dirs[@]}"; do
            if [ -d "$sdir" ] && [ ! -f "$sdir/.metadata_never_index" ]; then
                if $RUN_PERF_TUNE; then
                    run_or_dry touch "$sdir/.metadata_never_index"
                    log FIX "   Spotlight: $(basename "$sdir") ausgeschlossen"
                    spotlight_excluded=$((spotlight_excluded + 1))
                else
                    log STEP "   Spotlight indexiert: $(basename "$sdir") (ausschliessen mit -P)"
                    perf_warns=$((perf_warns + 1))
                fi
            fi
        done
        [ "$spotlight_excluded" -gt 0 ] && {
            perf_fixes=$((perf_fixes + spotlight_excluded))
            report_add FIX "Spotlight: ${spotlight_excluded} Verzeichnisse ausgeschlossen"
        }
    else
        log STEP "   [5/16] Spotlight Exclusions: uebersprungen (Config)"
    fi

    # ── [6/16] Memory-Hogs erkennen + killen ──
    log STEP "   [6/16] Memory-Analyse..."
    local mem_total_mb=$(sysctl -n hw.memsize 2>/dev/null | awk '{printf "%d", $1/1048576}')
    local kill_thresh_kb=$((PERF_KILL_THRESHOLD_MB * 1024))
    # Fix #110: gecachten ps-Output verwenden
    local mem_hogs
    mem_hogs=$(echo "$_ps_rss_cache" | sort -rn | \
        awk -v thresh="$kill_thresh_kb" -v uid="$(id -u)" \
        '$1>thresh && $4==uid {printf "%d %d %s\n", $1/1024, $2, $3}' | head -20)
    if [ -n "$mem_hogs" ]; then
        local killed_count=0
        local killed_mb=0
        log WARN "   Memory-Hogs (>${PERF_KILL_THRESHOLD_MB} MB):"
        while IFS= read -r line; do
            [ -z "$line" ] && continue
            local hog_mb=$(echo "$line" | awk '{print $1}')
            local hog_pid=$(echo "$line" | awk '{print $2}')
            local hog_name=$(echo "$line" | awk '{print $3}')
            # Whitelist pruefen
            local whitelisted=false
            for wl in $PERF_KILL_WHITELIST; do
                if [[ "$hog_name" == *"$wl"* ]]; then
                    whitelisted=true
                    break
                fi
            done
            if $whitelisted; then
                log STEP "     ${hog_name} (${hog_mb} MB) [geschuetzt]"
            elif $RUN_PERF_TUNE && $PERF_KILL_HOGS; then
                run_or_dry kill "$hog_pid"
                log FIX "     ${hog_name} (${hog_mb} MB, PID ${hog_pid}) beendet"
                killed_count=$((killed_count + 1))
                killed_mb=$((killed_mb + hog_mb))
            else
                log STEP "     ${hog_name} (${hog_mb} MB) [-P zum Beenden]"
                perf_warns=$((perf_warns + 1))
            fi
        done <<< "$mem_hogs"
        if [ "$killed_count" -gt 0 ]; then
            report_add FIX "Memory-Hogs: ${killed_count} Prozesse beendet (~${killed_mb} MB frei)"
            perf_fixes=$((perf_fixes + 1))
        fi
    else
        log STEP "   Keine Memory-Hogs (Schwelle: ${PERF_KILL_THRESHOLD_MB} MB)"
    fi
    # Compressed Memory
    local pagesize=$(sysctl -n hw.pagesize 2>/dev/null || echo 16384)
    local compressed_pages=$(vm_stat 2>/dev/null | awk '/stored in compressor:/ {gsub(/\./,"",$NF); print $NF}')
    local compressed_mb=$(( ${compressed_pages:-0} * $pagesize / 1048576 ))
    if [ "$compressed_mb" -gt 2048 ]; then
        log WARN "   Komprimierter RAM: ${compressed_mb} MB (hoch)"
        perf_warns=$((perf_warns + 1))
    else
        log STEP "   Komprimierter RAM: ${compressed_mb} MB"
    fi

    # ── [7/16] CPU-Hogs & Thermal ──
    log STEP "   [7/16] CPU-Analyse..."
    # Fix #110: gecachten ps-Output verwenden
    local cpu_hogs
    cpu_hogs=$(echo "$_ps_cpu_cache" | sort -rn | awk '$1>50.0 {printf "     PID %s: %s (%.0f%%)\n", $2, $3, $1}' | head -5)
    if [ -n "$cpu_hogs" ]; then
        log WARN "   CPU-Hogs (>50%):"
        echo "$cpu_hogs" | while IFS= read -r line; do
            [ -n "$line" ] && log STEP "$line"
        done
        report_add WARN "CPU-Hogs erkannt (>50%)"
        perf_warns=$((perf_warns + 1))
    else
        log STEP "   Keine CPU-Hogs"
    fi
    local cpu_speed_limit=$(pmset -g therm 2>/dev/null | awk '/CPU_Speed_Limit/ {print $3}')
    if [ -n "$cpu_speed_limit" ] && [ "$cpu_speed_limit" -lt 100 ] 2>/dev/null; then
        log WARN "   Thermal Throttling! CPU auf ${cpu_speed_limit}% gedrosselt"
        report_add WARN "CPU thermisch gedrosselt (${cpu_speed_limit}%)"
        perf_warns=$((perf_warns + 1))
    else
        log STEP "   Kein Thermal Throttling"
    fi

    # ── [8/16] WindowServer Performance ──
    log STEP "   [8/16] WindowServer..."
    local ws_cpu=$(echo "$_ps_cpu_cache" | awk '/WindowServer/ {print int($1)}')
    if [ "${ws_cpu:-0}" -gt 15 ]; then
        log WARN "   WindowServer: ${ws_cpu}% CPU (hoch!)"
        log STEP "   Tipp: Transparenz/Animationen reduzieren oder ext. Display-Kabel pruefen"
        report_add WARN "WindowServer CPU: ${ws_cpu}%"
        perf_warns=$((perf_warns + 1))
    else
        log STEP "   WindowServer: ${ws_cpu:-0}% CPU"
    fi

    # ── [9/16] Swap-Analyse ──
    log STEP "   [9/16] Swap-Analyse..."
    local swap_info=$(sysctl -n vm.swapusage 2>/dev/null)
    local swap_used_perf=$(echo "$swap_info" | awk -F'[ =M]+' '{for(i=1;i<=NF;i++) if($i=="used") print $(i+1)}' | cut -d. -f1)
    local swap_total_perf=$(echo "$swap_info" | awk -F'[ =M]+' '{for(i=1;i<=NF;i++) if($i=="total") print $(i+1)}' | cut -d. -f1)
    [ -z "$swap_used_perf" ] && swap_used_perf=0
    if [ "$swap_used_perf" -gt 4096 ] 2>/dev/null; then
        log WARN "   Swap: ${swap_used_perf}/${swap_total_perf:-?} MB (hoch!)"
        log STEP "   Empfehlung: Apps schliessen oder RAM aufrüsten"
        report_add WARN "Swap hoch: ${swap_used_perf} MB"
        perf_warns=$((perf_warns + 1))
    elif [ "$swap_used_perf" -gt 1024 ] 2>/dev/null; then
        log STEP "   Swap: ${swap_used_perf} MB (moderat)"
    else
        log STEP "   Swap: ${swap_used_perf} MB (niedrig)"
    fi

    # ── [10/16] Service-Audit ──
    if $PERF_SERVICE_AUDIT; then
        log STEP "   [10/16] Service-Audit..."
        local heavy_running=0
        local heavy_services="analyticsd photoanalysisd mediaanalysisd suggestd progressd"
        for svc in $heavy_services; do
            local svc_cpu=$(echo "$_ps_cpu_cache" | awk -v s="$svc" '$2~s {total+=$1} END {print int(total)}')
            if [ "${svc_cpu:-0}" -gt 10 ]; then
                log WARN "   Schwerer Dienst: $svc (${svc_cpu}% CPU)"
                heavy_running=$((heavy_running + 1))
            fi
        done
        local user_agents=$(find "$HOME/Library/LaunchAgents" -name "*.plist" 2>/dev/null | wc -l | xargs)
        local sys_daemons=$(find /Library/LaunchDaemons -name "*.plist" 2>/dev/null | wc -l | xargs)
        log STEP "   User-Agents: ${user_agents:-0} | System-Daemons: ${sys_daemons:-0}"
        if [ "${user_agents:-0}" -gt 20 ]; then
            log WARN "   Viele User-LaunchAgents (${user_agents}) - manuell pruefen"
            perf_warns=$((perf_warns + 1))
        fi
        [ "$heavy_running" -gt 0 ] && {
            report_add WARN "Service-Audit: ${heavy_running} schwere Dienste aktiv"
            perf_warns=$((perf_warns + heavy_running))
        }
    else
        log STEP "   [10/16] Service-Audit: uebersprungen (Config)"
    fi

    # ── [11/16] GUI Performance ──
    log STEP "   [11/16] GUI Performance..."
    local reduce_motion=$(defaults read com.apple.universalaccess reduceMotion 2>/dev/null)
    local reduce_transparency=$(defaults read com.apple.universalaccess reduceTransparency 2>/dev/null)
    local anim_windows=$(defaults read NSGlobalDomain NSAutomaticWindowAnimationsEnabled 2>/dev/null)
    if [ "${reduce_motion:-0}" != "1" ] || [ "${reduce_transparency:-0}" != "1" ] || [ "${anim_windows:-1}" != "0" ]; then
        if $RUN_PERF_TUNE && $PERF_GUI_REDUCE; then
            run_or_dry defaults write com.apple.universalaccess reduceMotion -bool true
            run_or_dry defaults write com.apple.universalaccess reduceTransparency -bool true
            run_or_dry defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false
            run_or_dry defaults write com.apple.dock autohide-time-modifier -float 0.15
            run_or_dry defaults write com.apple.dock launchanim -bool false
            run_or_dry defaults write com.apple.dock expose-animation-duration -float 0.12
            run_or_dry killall Dock 2>/dev/null
            log FIX "   GUI: Animationen/Transparenz reduziert"
            report_add FIX "GUI-Animationen reduziert"
            perf_fixes=$((perf_fixes + 1))
        else
            local gui_tips=""
            [ "${reduce_motion:-0}" != "1" ] && gui_tips="Reduce Motion"
            [ "${reduce_transparency:-0}" != "1" ] && gui_tips="${gui_tips:+$gui_tips, }Reduce Transparency"
            [ "${anim_windows:-1}" != "0" ] && gui_tips="${gui_tips:+$gui_tips, }Window-Animationen"
            [ -n "$gui_tips" ] && log STEP "   Optimierbar: ${gui_tips} (-P + PERF_GUI_REDUCE=true)"
        fi
    else
        log STEP "   GUI: Animationen bereits reduziert"
    fi

    # ── [12/16] Power Management ──
    log STEP "   [12/16] Power Management..."
    local power_mode=$(pmset -g 2>/dev/null | awk '/lowpowermode/ {print $2}')
    if [ "${power_mode:-0}" = "1" ]; then
        log WARN "   Stromsparmodus AKTIV (Performance eingeschraenkt)"
        if $RUN_PERF_TUNE && $NEEDS_SUDO; then
            run_or_dry sudo pmset -a lowpowermode 0
            log FIX "   Stromsparmodus deaktiviert"
            report_add FIX "Stromsparmodus deaktiviert"
            perf_fixes=$((perf_fixes + 1))
        else
            report_add WARN "Stromsparmodus aktiv (Performance reduziert)"
            perf_warns=$((perf_warns + 1))
        fi
    else
        log STEP "   Stromsparmodus: aus"
    fi
    local cpu_brand=$(sysctl -n machdep.cpu.brand_string 2>/dev/null)
    if echo "$cpu_brand" | grep -qi "Apple"; then
        log STEP "   Apple Silicon: Performance/Efficiency-Cores aktiv"
    fi

    # ── [13/16] Login Items bereinigen ──
    if $PERF_CLEAN_LOGIN_ITEMS; then
        log STEP "   [13/16] Login Items bereinigen..."
        local login_items
        login_items=$(osascript -e 'tell application "System Events" to get the name of every login item' 2>/dev/null)
        if [ -n "$login_items" ]; then
            local removed_items=0
            IFS=', ' read -ra items <<< "$login_items"
            for item in "${items[@]}"; do
                item="${item#"${item%%[![:space:]]*}"}"
                item="${item%"${item##*[![:space:]]}"}"
                [ -z "$item" ] && continue
                if $RUN_PERF_TUNE; then
                    run_or_dry osascript -e "tell application \"System Events\" to delete login item \"$item\""
                    log FIX "     Login Item entfernt: $item"
                    removed_items=$((removed_items + 1))
                else
                    log STEP "     Login Item: $item [-P zum Entfernen]"
                    perf_warns=$((perf_warns + 1))
                fi
            done
            [ "$removed_items" -gt 0 ] && {
                report_add FIX "Login Items: ${removed_items} entfernt"
                perf_fixes=$((perf_fixes + 1))
            }
        else
            log STEP "   Keine Login Items vorhanden"
        fi
    else
        log STEP "   [13/16] Login Items: uebersprungen (Config)"
    fi

    # ── [14/16] Unnoetige LaunchAgents deaktivieren ──
    if $PERF_DISABLE_AGENTS; then
        log STEP "   [14/16] LaunchAgents bereinigen..."
        local disabled_agents=0
        for pattern in $PERF_DISABLE_AGENT_PATTERNS; do
            for plist in "$HOME/Library/LaunchAgents/"*"${pattern}"*".plist" ; do
                [ ! -f "$plist" ] && continue
                local agent_label=$(basename "$plist" .plist)
                # Pruefen ob geladen
                if launchctl list "$agent_label" &>/dev/null; then
                    if $RUN_PERF_TUNE; then
                        run_or_dry launchctl bootout "gui/$(id -u)" "$plist"
                        log FIX "     LaunchAgent deaktiviert: $agent_label"
                        disabled_agents=$((disabled_agents + 1))
                    else
                        log STEP "     Aktiver Agent: $agent_label [-P zum Deaktivieren]"
                        perf_warns=$((perf_warns + 1))
                    fi
                else
                    log STEP "     Agent bereits inaktiv: $agent_label"
                fi
            done
        done
        [ "$disabled_agents" -gt 0 ] && {
            report_add FIX "LaunchAgents: ${disabled_agents} deaktiviert"
            perf_fixes=$((perf_fixes + 1))
        }
    else
        log STEP "   [14/16] LaunchAgents: uebersprungen (Config)"
    fi

    # ── [15/16] Ollama Model Cleanup ──
    if $PERF_CLEAN_OLLAMA && command_exists ollama; then
        log STEP "   [15/16] Ollama Model Cleanup..."
        local ollama_was_running=false
        ollama_available && ollama_was_running=true

        # Sicherstellen dass Ollama laeuft fuer rm
        if ! $ollama_was_running; then
            ollama serve &>/dev/null &
            local ollama_tmp_pid=$!
            sleep 3
        fi

        if ollama_available; then
            local installed_models=$(ollama list 2>/dev/null | awk 'NR>1 {print $1}')
            local removed_models=0
            local removed_size=0
            for model in $installed_models; do
                local keep=false
                for keeper in $OLLAMA_KEEP_MODELS; do
                    if [ "$model" = "$keeper" ]; then
                        keep=true
                        break
                    fi
                done
                if ! $keep; then
                    if $RUN_PERF_TUNE; then
                        local model_size=$(ollama show "$model" --modelfile 2>/dev/null | awk '/^# Size:/ {print $3}')
                        run_or_dry ollama rm "$model"
                        log FIX "     Ollama-Modell entfernt: $model"
                        removed_models=$((removed_models + 1))
                    else
                        log STEP "     Ueberfluessig: $model [-P zum Loeschen]"
                        perf_warns=$((perf_warns + 1))
                    fi
                else
                    log STEP "     Behalten: $model"
                fi
            done
            # Wenn Ollama nur temporaer gestartet, wieder stoppen
            if ! $ollama_was_running; then
                pkill ollama 2>/dev/null
                log STEP "     Ollama-Server wieder gestoppt (RAM freigegeben)"
            fi
            [ "$removed_models" -gt 0 ] && {
                report_add FIX "Ollama: ${removed_models} Modelle entfernt"
                perf_fixes=$((perf_fixes + 1))
                ollama_list_invalidate
            }
        else
            log WARN "   Ollama-Server nicht erreichbar - Cleanup uebersprungen"
        fi
    else
        log STEP "   [15/16] Ollama Cleanup: uebersprungen (Config/nicht installiert)"
    fi

    # ── [16/16] RAM Purge ──
    if $PERF_RAM_PURGE && $NEEDS_SUDO; then
        log STEP "   [16/16] RAM Purge..."
        local free_before=$(vm_stat 2>/dev/null | awk '/Pages free:/ {gsub(/\./,"",$NF); print $NF}')
        if $RUN_PERF_TUNE; then
            run_or_dry sudo purge
            sleep 1
            local free_after=$(vm_stat 2>/dev/null | awk '/Pages free:/ {gsub(/\./,"",$NF); print $NF}')
            local pagesize=$(sysctl -n hw.pagesize 2>/dev/null || echo 16384)
            local freed_mb=$(( (${free_after:-0} - ${free_before:-0}) * $pagesize / 1048576 ))
            [ "$freed_mb" -lt 0 ] && freed_mb=0
            log FIX "   RAM Purge: ~${freed_mb} MB freigegeben"
            report_add FIX "RAM Purge: ~${freed_mb} MB freigegeben"
            perf_fixes=$((perf_fixes + 1))
        else
            log STEP "   RAM Purge verfuegbar (-P zum Ausfuehren)"
            perf_warns=$((perf_warns + 1))
        fi
    else
        log STEP "   [16/16] RAM Purge: uebersprungen (Config/kein sudo)"
    fi

    # ── Zusammenfassung + optionale AI-Analyse ──
    log INFO "   Performance: ${perf_fixes} Optimierungen, ${perf_warns} Empfehlungen"
    [ "$perf_fixes" -gt 0 ] && report_add FIX "Performance: ${perf_fixes} Optimierungen angewendet"
    [ "$perf_warns" -gt 0 ] && report_add WARN "Performance: ${perf_warns} Empfehlungen moeglich (-P)"

    # Bei vielen Problemen: Ollama um Analyse bitten
    if [ "$perf_warns" -gt 3 ] && ollama_available; then
        log HEAL "   AI-Performance-Analyse..."
        local perf_context="macOS Performance-Probleme: ${perf_warns} Warnungen."
        [ -n "$mem_hogs" ] && perf_context="${perf_context} Memory-Hogs: $(echo "$mem_hogs" | head -3 | tr '\n' '; ')."
        [ -n "$cpu_hogs" ] && perf_context="${perf_context} CPU-Hogs: $(echo "$cpu_hogs" | head -3 | tr '\n' '; ')."
        [ "${swap_used_perf:-0}" -gt 2048 ] 2>/dev/null && perf_context="${perf_context} Swap: ${swap_used_perf}MB."
        local perf_tip
        perf_tip=$(ollama_query "$(sanitize_for_prompt "$perf_context" 500)
Gib 3-5 konkrete macOS Performance-Tipps fuer dieses System. Nur Tipps, keine Erklaerungen. Deutsch. Keine <think>-Tags.")
        if [ -n "$perf_tip" ]; then
            log HEAL "   AI Performance-Tipps:"
            echo "$perf_tip" | while IFS= read -r line; do
                [ -n "$line" ] && log STEP "     $line"
            done
        fi
    fi
}

#############################
# 6b. SELF-HEALING PREFLIGHT
#############################

selfheal_preflight() {
    log INFO "Self-Healing Preflight Check..."

    if command_exists brew; then
        log STEP "   Pruefe Homebrew-Zustand..."
        if ! brew --prefix &>/dev/null; then
            log WARN "   Homebrew reagiert nicht"
            if ollama_available; then
                local diag
                diag=$(selfheal_analyze "brew-preflight" "brew --prefix returns error or hangs" "1")
                if [ -n "$diag" ] && [ "$diag" != "NOFIX" ]; then
                    selfheal_apply "brew-preflight" "$diag"
                    report_add HEALED "Homebrew via Preflight repariert"
                fi
            fi
        else
            log STEP "   Homebrew OK"
        fi
    fi

    log STEP "   Pruefe DNS..."
    if ! host google.com &>/dev/null 2>&1; then
        log WARN "   DNS-Aufloesung fehlgeschlagen"
        sudo dscacheutil -flushcache 2>/dev/null
        sudo killall -HUP mDNSResponder 2>/dev/null
        sleep 1
        if host google.com &>/dev/null 2>&1; then
            log FIX "   DNS nach Flush OK"
            report_add FIX "DNS-Cache geleert (Preflight)"
        fi
    else
        log STEP "   DNS OK"
    fi

    local disk_pct=$(df -h / | awk 'NR==2 {gsub(/%/,"",$5); print $5}')
    if [ "$disk_pct" -gt "$DISK_CRITICAL_THRESHOLD" ] 2>/dev/null; then
        log ERROR "   KRITISCH: Disk ${disk_pct}% voll!"
        log WARN "   Raeume Temp-Dateien auf..."
        rm -rf /private/var/tmp/* 2>/dev/null
        rm -rf "$HOME/Library/Caches"/* 2>/dev/null
        report_add HEALED "Notfall-Cleanup bei ${disk_pct}% Disk"
    elif [ "$disk_pct" -gt "$DISK_USAGE_THRESHOLD" ] 2>/dev/null; then
        log WARN "   Disk ${disk_pct}% belegt (Schwelle: ${DISK_USAGE_THRESHOLD}%)"
    else
        log STEP "   Disk OK (${disk_pct}%)"
    fi

    log INFO "   Preflight abgeschlossen"
}

#############################
# 7. SYSTEM BENCHMARK (Fix #53)
#############################

BENCHMARK_DIR="$MEISTER_DIR/benchmarks"
BENCHMARK_INTERVAL=86400  # 24h in Sekunden
mkdir -p "$BENCHMARK_DIR" 2>/dev/null

benchmark_should_run() {
    local last_file="$BENCHMARK_DIR/last_run"
    [ ! -f "$last_file" ] && return 0
    local last_ts=$(cat "$last_file" 2>/dev/null || echo 0)
    local now=$(date +%s)
    [ $((now - last_ts)) -ge "$BENCHMARK_INTERVAL" ]
}

# Fix #106: date +%s%N funktioniert nicht auf macOS (gibt "N" statt Nanosekunden)
# → perl oder gdate fuer Millisekunden-Praezision
_epoch_ms() {
    if command_exists gdate; then
        gdate +%s%N | cut -c1-13
    elif command_exists perl; then
        perl -MTime::HiRes=time -e 'printf "%d\n", time()*1000'
    else
        echo "$(date +%s)000"
    fi
}

benchmark_cpu() {
    # Single-Core: Pi-Berechnung via bc (1000 Stellen)
    local start=$(_epoch_ms)
    echo "scale=1000; 4*a(1)" | bc -l > /dev/null 2>&1
    local end=$(_epoch_ms)
    local ms=$(( end - start ))
    [ "$ms" -le 0 ] && ms=1
    echo "$ms"
}

benchmark_disk_write() {
    local tmpf="$BENCHMARK_DIR/.disktest_$$"
    local start=$(_epoch_ms)
    dd if=/dev/zero of="$tmpf" bs=1m count=256 2>/dev/null
    sync
    local end=$(_epoch_ms)
    rm -f "$tmpf"
    local ms=$(( end - start ))
    [ "$ms" -le 0 ] && ms=1
    local mbps=$(( 256 * 1000 / ms ))
    echo "$mbps"
}

benchmark_disk_read() {
    local tmpf="$BENCHMARK_DIR/.disktest_read_$$"
    dd if=/dev/zero of="$tmpf" bs=1m count=256 2>/dev/null
    sync
    purge 2>/dev/null || true
    local start=$(_epoch_ms)
    dd if="$tmpf" of=/dev/null bs=1m 2>/dev/null
    local end=$(_epoch_ms)
    rm -f "$tmpf"
    local ms=$(( end - start ))
    [ "$ms" -le 0 ] && ms=1
    local mbps=$(( 256 * 1000 / ms ))
    echo "$mbps"
}

benchmark_network() {
    # Fix #87: Latenz + DNS in EINEM curl-Aufruf statt zwei
    local curl_times
    curl_times=$(curl -so /dev/null -w "%{time_namelookup} %{time_connect}" \
        https://www.apple.com 2>/dev/null || echo "0 0")
    local dns_raw connect_raw
    read -r dns_raw connect_raw <<< "$curl_times"
    local lat_ms=$(echo "${connect_raw:-0} * 1000" | bc 2>/dev/null | cut -d. -f1)
    local dns_ms=$(echo "${dns_raw:-0} * 1000" | bc 2>/dev/null | cut -d. -f1)
    [ -z "$lat_ms" ] && lat_ms=0
    [ -z "$dns_ms" ] && dns_ms=0

    # Download-Speed: 10MB von Apple CDN
    local dl_speed="0"
    local dl_out
    dl_out=$(curl -so /dev/null -w "%{speed_download}" \
        "https://updates.cdn-apple.com/2019/cert/041-88431-20191011-3d8da658-dca4-4a5b-b67c-69e87e3571b2/InstallAssistant.pkg" \
        --max-time 10 --range 0-10485759 2>/dev/null || echo "0")
    if [ -n "$dl_out" ] && [ "$dl_out" != "0" ]; then
        dl_speed=$(echo "$dl_out / 1048576" | bc -l 2>/dev/null | cut -c1-5)
    fi
    [ -z "$dl_speed" ] && dl_speed="0"

    echo "${lat_ms} ${dns_ms} ${dl_speed}"
}

benchmark_memory() {
    local total_mb free_mb pressure swap_used_mb
    total_mb=$(sysctl -n hw.memsize 2>/dev/null | awk '{printf "%d", $1/1048576}')
    # Fix #87: vm_stat EINMAL aufrufen, beide Werte in einem awk extrahieren
    local pagesize=$(sysctl -n hw.pagesize 2>/dev/null || echo 16384)
    local free_pages inactive_pages
    read -r free_pages inactive_pages <<< $(vm_stat 2>/dev/null | awk '
        /Pages free:/ {gsub(/\./,"",$3); f=$3}
        /Pages inactive:/ {gsub(/\./,"",$3); i=$3}
        END {print f+0, i+0}')
    free_mb=$(( (${free_pages:-0} + ${inactive_pages:-0}) * pagesize / 1048576 ))
    # Memory Pressure (1=normal, 2=warn, 4=critical)
    pressure=$(sysctl -n kern.memorystatus_vm_pressure_level 2>/dev/null || echo "0")
    swap_used_mb=$(LC_ALL=C sysctl -n vm.swapusage 2>/dev/null | awk -F'[ =M]+' '{for(i=1;i<=NF;i++) if($i=="used") {gsub(/,/,".",$((i+1))); printf "%d", $(i+1)}}')
    [ -z "$swap_used_mb" ] && swap_used_mb=0

    echo "${total_mb} ${free_mb} ${pressure} ${swap_used_mb}"
}

benchmark_security() {
    local filevault firewall gatekeeper sip xprotect
    # FileVault
    if fdesetup status 2>/dev/null | grep -q "On"; then
        filevault="ON"
    else
        filevault="OFF"
    fi
    # Firewall
    local fw_state
    fw_state=$(/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null || echo "")
    if echo "$fw_state" | grep -qi "enabled"; then
        firewall="ON"
    else
        firewall="OFF"
    fi
    # Gatekeeper
    if spctl --status 2>/dev/null | grep -q "enabled"; then
        gatekeeper="ON"
    else
        gatekeeper="OFF"
    fi
    # SIP (System Integrity Protection)
    if csrutil status 2>/dev/null | grep -q "enabled"; then
        sip="ON"
    else
        sip="OFF"
    fi
    # Fix #88: XProtect Version via pkgutil statt system_profiler (~10s schneller)
    xprotect=$(pkgutil --pkg-info com.apple.pkg.XProtectPlistConfigData 2>/dev/null | awk '/version:/ {print $2}')
    [ -z "$xprotect" ] && xprotect=$(pkgutil --pkg-info com.apple.pkg.XProtectPayloads 2>/dev/null | awk '/version:/ {print $2}')
    [ -z "$xprotect" ] && xprotect="n/a"

    echo "${filevault} ${firewall} ${gatekeeper} ${sip} ${xprotect}"
}

benchmark_system_info() {
    local uptime_secs load1 load5 load15 thermal battery_pct battery_cycles battery_health
    # Uptime
    uptime_secs=$(sysctl -n kern.boottime 2>/dev/null | awk -F'[ ,=]+' '{for(i=1;i<=NF;i++) if($i=="sec") print $(i+1)}')
    if [ -n "$uptime_secs" ]; then
        local now=$(date +%s)
        uptime_secs=$((now - uptime_secs))
    else
        uptime_secs=0
    fi
    local uptime_days=$((uptime_secs / 86400))

    # Load Average
    read -r load1 load5 load15 <<< $(sysctl -n vm.loadavg 2>/dev/null | awk '{print $2, $3, $4}')
    [ -z "$load1" ] && load1="0" && load5="0" && load15="0"

    # Thermal (macOS Sequoia+)
    thermal=$(pmset -g therm 2>/dev/null | awk '/CPU_Speed_Limit/ {print $3}' || echo "100")
    [ -z "$thermal" ] && thermal="100"

    # Battery (nur MacBooks)
    battery_pct=""
    battery_cycles=""
    battery_health=""
    if pmset -g batt 2>/dev/null | grep -q "InternalBattery"; then
        battery_pct=$(pmset -g batt 2>/dev/null | grep -o '[0-9]*%' | head -1 | tr -d '%')
        # Fix #87: ioreg EINMAL aufrufen statt dreimal (~3s gespart)
        local ioreg_cache
        ioreg_cache=$(ioreg -rc AppleSmartBattery 2>/dev/null)
        # Fix: Nur Top-Level-Keys matchen (^ + Leerzeichen + "), nicht innerhalb BatteryData-Blob
        battery_cycles=$(echo "$ioreg_cache" | awk '/^[[:space:]]+"CycleCount" =/ {print $NF}')
        battery_health=$(echo "$ioreg_cache" | awk -F'"' '/^[[:space:]]+"BatteryHealth" =/ {print $4}')
        [ -z "$battery_health" ] && battery_health=$(echo "$ioreg_cache" | awk '/^[[:space:]]+"MaxCapacity" =/ {print $NF}')
    fi
    [ -z "$battery_pct" ] && battery_pct="-"
    [ -z "$battery_cycles" ] && battery_cycles="-"
    [ -z "$battery_health" ] && battery_health="-"

    echo "${uptime_days} ${load1} ${load5} ${load15} ${thermal} ${battery_pct} ${battery_cycles} ${battery_health}"
}

benchmark_save_json() {
    local ts="$1" cpu_ms="$2" disk_w="$3" disk_r="$4"
    local net_lat="$5" net_dns="$6" net_dl="$7"
    local mem_total="$8" mem_free="$9" mem_pressure="${10}" swap_mb="${11}"
    local fv="${12}" fw="${13}" gk="${14}" sip_val="${15}" xp="${16}"
    local up_days="${17}" l1="${18}" l5="${19}" l15="${20}" therm="${21}"
    local batt_pct="${22}" batt_cyc="${23}" batt_hp="${24}"
    local date_str=$(date +%Y-%m-%d)
    local json_file="$BENCHMARK_DIR/${date_str}.json"

    if command_exists jq; then
        jq -n \
            --arg ts "$ts" \
            --argjson cpu "$cpu_ms" \
            --argjson disk_w "$disk_w" \
            --argjson disk_r "$disk_r" \
            --argjson net_lat "$net_lat" \
            --argjson net_dns "$net_dns" \
            --arg net_dl "$net_dl" \
            --argjson mem_total "$mem_total" \
            --argjson mem_free "$mem_free" \
            --argjson mem_pressure "$mem_pressure" \
            --argjson swap "$swap_mb" \
            --arg filevault "$fv" \
            --arg firewall "$fw" \
            --arg gatekeeper "$gk" \
            --arg sip "$sip_val" \
            --arg xprotect "$xp" \
            --argjson uptime_days "$up_days" \
            --arg load1 "$l1" \
            --arg load5 "$l5" \
            --arg load15 "$l15" \
            --arg thermal "$therm" \
            --arg battery_pct "$batt_pct" \
            --arg battery_cycles "$batt_cyc" \
            --arg battery_health "$batt_hp" \
            '{timestamp:$ts, cpu_ms:$cpu, disk_write_mbps:$disk_w, disk_read_mbps:$disk_r,
              net_latency_ms:$net_lat, net_dns_ms:$net_dns, net_download_mbps:$net_dl,
              mem_total_mb:$mem_total, mem_free_mb:$mem_free, mem_pressure:$mem_pressure, swap_mb:$swap,
              security:{filevault:$filevault, firewall:$firewall, gatekeeper:$gatekeeper, sip:$sip, xprotect:$xprotect},
              uptime_days:$uptime_days, load:{l1:$load1, l5:$load5, l15:$load15},
              thermal:$thermal, battery:{pct:$battery_pct, cycles:$battery_cycles, health:$battery_health}}' \
            > "$json_file"
    else
        cat > "$json_file" << JSONEOF
{"timestamp":"$ts","cpu_ms":$cpu_ms,"disk_write_mbps":$disk_w,"disk_read_mbps":$disk_r,"net_latency_ms":$net_lat,"net_dns_ms":$net_dns,"net_download_mbps":"$net_dl","mem_total_mb":$mem_total,"mem_free_mb":$mem_free,"mem_pressure":$mem_pressure,"swap_mb":$swap_mb,"security":{"filevault":"$fv","firewall":"$fw","gatekeeper":"$gk","sip":"$sip_val","xprotect":"$xp"},"uptime_days":$up_days,"load":{"l1":"$l1","l5":"$l5","l15":"$l15"},"thermal":"$therm","battery":{"pct":"$batt_pct","cycles":"$batt_cyc","health":"$batt_hp"}}
JSONEOF
    fi
    echo "$json_file"
}

benchmark_compare() {
    local current_file="$1"
    # Letzten vorherigen Benchmark finden
    local prev_file
    prev_file=$(ls -1t "$BENCHMARK_DIR"/*.json 2>/dev/null | grep -v "$(basename "$current_file")" | head -1)
    [ -z "$prev_file" ] && { log STEP "   Erster Benchmark - kein Vergleich moeglich"; return; }

    if ! command_exists jq; then return; fi

    local prev_cpu=$(jq -r '.cpu_ms' "$prev_file" 2>/dev/null || echo 0)
    local curr_cpu=$(jq -r '.cpu_ms' "$current_file" 2>/dev/null || echo 0)
    local prev_dw=$(jq -r '.disk_write_mbps' "$prev_file" 2>/dev/null || echo 0)
    local curr_dw=$(jq -r '.disk_write_mbps' "$current_file" 2>/dev/null || echo 0)
    local prev_date=$(jq -r '.timestamp' "$prev_file" 2>/dev/null | cut -d' ' -f1)

    log STEP "   Vergleich mit $prev_date:"

    # CPU: niedriger = besser
    if [ "$prev_cpu" -gt 0 ] && [ "$curr_cpu" -gt 0 ]; then
        local cpu_diff=$(( (curr_cpu - prev_cpu) * 100 / prev_cpu ))
        if [ "$cpu_diff" -gt 20 ]; then
            log WARN "   CPU: ${curr_cpu}ms vs ${prev_cpu}ms (+${cpu_diff}% langsamer!)"
            report_add WARN "CPU-Benchmark ${cpu_diff}% langsamer als letzter Lauf"
        elif [ "$cpu_diff" -lt -10 ]; then
            log INFO "   CPU: ${curr_cpu}ms vs ${prev_cpu}ms (${cpu_diff}% schneller)"
        else
            log STEP "   CPU: ${curr_cpu}ms vs ${prev_cpu}ms (stabil)"
        fi
    fi

    # Disk Write: hoeher = besser
    if [ "$prev_dw" -gt 0 ] && [ "$curr_dw" -gt 0 ]; then
        local dw_diff=$(( (curr_dw - prev_dw) * 100 / prev_dw ))
        if [ "$dw_diff" -lt -30 ]; then
            log WARN "   Disk Write: ${curr_dw} MB/s vs ${prev_dw} MB/s (${dw_diff}% langsamer!)"
            report_add WARN "Disk-Write ${dw_diff}% langsamer als letzter Lauf"
        else
            log STEP "   Disk Write: ${curr_dw} MB/s vs ${prev_dw} MB/s"
        fi
    fi
}

module_benchmark() {
    if ! benchmark_should_run; then
        log INFO "Benchmark: Bereits heute gelaufen - ueberspringe"
        log STEP "   Naechster Benchmark in ~$((BENCHMARK_INTERVAL - ($(date +%s) - $(cat "$BENCHMARK_DIR/last_run" 2>/dev/null || echo 0)))) Sekunden"
        report_add SUCCESS "Benchmark: skip (bereits heute)"
        return
    fi

    log INFO "System-Benchmark & Security-Audit..."
    local ts=$(date +'%Y-%m-%d %H:%M:%S')

    # 1. CPU Benchmark
    log STEP "   CPU-Benchmark (Pi 1000 Stellen)..."
    local cpu_ms=$(benchmark_cpu)
    log STEP "   CPU: ${cpu_ms}ms"

    # 2. Disk I/O
    log STEP "   Disk-I/O Benchmark (256MB)..."
    local disk_w=$(benchmark_disk_write)
    local disk_r=$(benchmark_disk_read)
    log STEP "   Disk: Write ${disk_w} MB/s, Read ${disk_r} MB/s"

    # 3. Netzwerk
    log STEP "   Netzwerk-Benchmark..."
    local net_lat net_dns net_dl
    read -r net_lat net_dns net_dl <<< $(benchmark_network)
    log STEP "   Netz: Latenz ${net_lat}ms, DNS ${net_dns}ms, Download ${net_dl} MB/s"

    # 4. Memory
    log STEP "   Memory-Status..."
    local mem_total mem_free mem_pressure swap_mb
    read -r mem_total mem_free mem_pressure swap_mb <<< $(benchmark_memory)
    local mem_used=$((mem_total - mem_free))
    local mem_pct=$((mem_used * 100 / mem_total))
    local pressure_txt="normal"
    [ "$mem_pressure" -ge 2 ] 2>/dev/null && pressure_txt="WARNUNG"
    [ "$mem_pressure" -ge 4 ] 2>/dev/null && pressure_txt="KRITISCH"
    log STEP "   RAM: ${mem_used}/${mem_total} MB (${mem_pct}%), Pressure: ${pressure_txt}, Swap: ${swap_mb} MB"

    if [ "$mem_pressure" -ge 2 ] 2>/dev/null; then
        report_add WARN "Memory Pressure: ${pressure_txt} (Swap: ${swap_mb} MB)"
    fi
    if [ "$swap_mb" -gt 4096 ] 2>/dev/null; then
        report_add WARN "Hoher Swap-Verbrauch: ${swap_mb} MB"
    fi

    # 5. Security Audit
    log STEP "   Security-Audit..."
    local fv fw gk sip_status xp
    read -r fv fw gk sip_status xp <<< $(benchmark_security)
    log STEP "   FileVault: $fv | Firewall: $fw | Gatekeeper: $gk | SIP: $sip_status"
    log STEP "   XProtect: $xp"

    # Security-Warnungen
    [ "$fv" = "OFF" ] && { log WARN "   FileVault ist DEAKTIVIERT!"; report_add WARN "FileVault deaktiviert"; }
    [ "$fw" = "OFF" ] && { log WARN "   Firewall ist DEAKTIVIERT!"; report_add WARN "Firewall deaktiviert"; }
    [ "$gk" = "OFF" ] && { log WARN "   Gatekeeper ist DEAKTIVIERT!"; report_add WARN "Gatekeeper deaktiviert"; }
    [ "$sip_status" = "OFF" ] && { log WARN "   SIP ist DEAKTIVIERT!"; report_add WARN "SIP deaktiviert"; }

    # 6. System-Info
    log STEP "   System-Info..."
    local up_days l1 l5 l15 therm batt_pct batt_cyc batt_hp
    read -r up_days l1 l5 l15 therm batt_pct batt_cyc batt_hp <<< $(benchmark_system_info)
    log STEP "   Uptime: ${up_days} Tage | Load: ${l1}/${l5}/${l15} | Thermal: ${therm}%"
    if [ "$batt_pct" != "-" ]; then
        log STEP "   Batterie: ${batt_pct}% | Zyklen: ${batt_cyc} | Health: ${batt_hp}"
        if [ "$batt_pct" -lt 20 ] 2>/dev/null; then
            report_add WARN "Batterie niedrig: ${batt_pct}%"
        fi
    fi

    if [ "$up_days" -gt 30 ] 2>/dev/null; then
        log WARN "   System laeuft seit ${up_days} Tagen - Neustart empfohlen"
        report_add WARN "Uptime ${up_days} Tage - Neustart empfohlen"
    fi

    # 7. Ergebnisse speichern (JSON)
    local json_file
    json_file=$(benchmark_save_json "$ts" "$cpu_ms" "$disk_w" "$disk_r" \
        "$net_lat" "$net_dns" "$net_dl" \
        "$mem_total" "$mem_free" "$mem_pressure" "$swap_mb" \
        "$fv" "$fw" "$gk" "$sip_status" "$xp" \
        "$up_days" "$l1" "$l5" "$l15" "$therm" \
        "$batt_pct" "$batt_cyc" "$batt_hp")
    log STEP "   Gespeichert: $json_file"

    # 8. Vergleich mit letztem Lauf
    benchmark_compare "$json_file"

    # 9. Timestamp speichern
    date +%s > "$BENCHMARK_DIR/last_run"

    # 10. Alte Benchmarks aufraumen (>90 Tage)
    find "$BENCHMARK_DIR" -name "*.json" -mtime +90 -delete 2>/dev/null

    report_add SUCCESS "Benchmark: CPU ${cpu_ms}ms, Disk W:${disk_w}/R:${disk_r} MB/s, Net ${net_dl} MB/s"
    local sec_ok=0
    [ "$fv" = "ON" ] && sec_ok=$((sec_ok + 1))
    [ "$fw" = "ON" ] && sec_ok=$((sec_ok + 1))
    [ "$gk" = "ON" ] && sec_ok=$((sec_ok + 1))
    [ "$sip_status" = "ON" ] && sec_ok=$((sec_ok + 1))
    report_add SUCCESS "Security: ${sec_ok}/4 (FV:$fv FW:$fw GK:$gk SIP:$sip_status)"
}

#############################
# 8. MAIN
#############################

keep_sudo() {
    sudo -v
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
    SUDO_KEEPALIVE_PID=$!
}

# Fix #16: Run-History
save_history() {
    local history_file="$MEISTER_DIR/history.log"
    local end_ts=$(date +%s)
    local total_secs=$((end_ts - SCRIPT_START_TIME))
    local total_mins=$((total_secs / 60))
    local total_secs_rem=$((total_secs % 60))
    local ts=$(date +'%Y-%m-%d %H:%M:%S')
    local h_count h_ok h_fail h_cached h_secs
    read -r h_count h_ok h_fail h_cached h_secs < <(ollama_stat_read)
    echo "$ts | ${total_mins}m${total_secs_rem}s | OK:${#REPORT_SUCCESS[@]} FIX:${#REPORT_FIXED[@]} WARN:${#REPORT_WARNINGS[@]} ERR:${#REPORT_ERRORS[@]} HEAL:${#REPORT_HEALED[@]} | AI:${h_ok}/${h_count}(${h_cached}c)" >> "$history_file"
}

print_report() {
    local end_ts=$(date +%s)
    local total_secs=$((end_ts - SCRIPT_START_TIME))
    local total_mins=$((total_secs / 60))
    local total_secs_rem=$((total_secs % 60))

    echo ""
    echo -e "${BLUE}====================================================${NC}"
    echo -e "${BLUE}   MEISTER REPORT (v0.04)${NC}"
    echo -e "${BLUE}   Laufzeit: ${total_mins}m ${total_secs_rem}s${NC}"
    $DRY_RUN && echo -e "${YELLOW}   [DRY-RUN MODUS]${NC}"
    echo -e "${BLUE}====================================================${NC}"

    if [ ${#REPORT_SUCCESS[@]} -gt 0 ]; then
        echo -e "\n${GREEN}SUCCESS (${#REPORT_SUCCESS[@]}):${NC}"
        printf '  - %s\n' "${REPORT_SUCCESS[@]}"
    fi
    if [ ${#REPORT_FIXED[@]} -gt 0 ]; then
        echo -e "\n${CYAN}FIXED (${#REPORT_FIXED[@]}):${NC}"
        printf '  - %s\n' "${REPORT_FIXED[@]}"
    fi
    if [ ${#REPORT_HEALED[@]} -gt 0 ]; then
        echo -e "\n${MAGENTA}AI-HEALED via Ollama (${#REPORT_HEALED[@]}):${NC}"
        printf '  - %s\n' "${REPORT_HEALED[@]}"
    fi
    if [ ${#REPORT_WARNINGS[@]} -gt 0 ]; then
        echo -e "\n${YELLOW}WARNINGS (${#REPORT_WARNINGS[@]}):${NC}"
        printf '  - %s\n' "${REPORT_WARNINGS[@]}"
    fi
    if [ ${#REPORT_ERRORS[@]} -gt 0 ]; then
        echo -e "\n${RED}ERRORS (${#REPORT_ERRORS[@]}):${NC}"
        printf '  - %s\n' "${REPORT_ERRORS[@]}"
    fi
    if [ -n "$MSUPDATE_OUTPUT_LOG" ]; then
        echo -e "\n${BLUE}--- MS Update Detail ---${NC}"
        echo "$MSUPDATE_OUTPUT_LOG"
    fi

    # Fix #51: Ollama-Statistik im Report (dateibasiert)
    local o_count o_ok o_fail o_cached o_secs
    read -r o_count o_ok o_fail o_cached o_secs < <(ollama_stat_read)
    if [ "${o_count:-0}" -gt 0 ]; then
        echo -e "\n${MAGENTA}--- Ollama Statistik ---${NC}"
        echo "  Modell:  $OLLAMA_MODEL"
        echo "  Queries: $o_count (OK: $o_ok, Fehler: $o_fail, Cache: $o_cached)"
        local non_cached=$((o_count - o_cached))
        if [ "$non_cached" -gt 0 ] && [ "${o_secs:-0}" -gt 0 ]; then
            local avg=$((o_secs / non_cached))
            echo "  Dauer:   ${o_secs}s gesamt (~${avg}s/Query)"
        fi
    fi

    # Fix #80: Gesamt-Speicher-Summary aus FIXED-Eintraegen extrahieren
    local total_mb_freed=0
    for entry in "${REPORT_FIXED[@]}"; do
        local mb_val
        mb_val=$(echo "$entry" | grep -oE '[0-9]+ MB' | head -1 | awk '{print $1}')
        [ -n "$mb_val" ] && total_mb_freed=$((total_mb_freed + mb_val))
    done
    if [ "$total_mb_freed" -gt 0 ]; then
        echo -e "\n${GREEN}--- Speicher-Summary ---${NC}"
        if [ "$total_mb_freed" -gt 1024 ]; then
            local gb_freed=$(echo "scale=1; $total_mb_freed / 1024" | bc 2>/dev/null || echo "$((total_mb_freed / 1024))")
            echo "  Freigegeben: ~${gb_freed} GB (${total_mb_freed} MB)"
        else
            echo "  Freigegeben: ~${total_mb_freed} MB"
        fi
    fi

    echo -e "\n${BLUE}====================================================${NC}"
    echo "Log: $LOGFILE"
    echo "Config: $MEISTER_CONFIG"
}

health_dashboard() {
    echo -e "\n${MAGENTA}═══════════════════════════════════════${NC}"
    echo -e "${MAGENTA}  Self-Healing Status (v0.04)${NC}"
    echo -e "${MAGENTA}═══════════════════════════════════════${NC}"
    if ollama_available; then
        echo -e "  Ollama:  ${GREEN}online${NC} ($OLLAMA_MODEL)"
        local model_count=$(ollama_list_cached | awk 'NR>1' | wc -l | xargs)
        echo -e "  Modelle: ${model_count}"
        echo -e "  Timeout: ${OLLAMA_QUERY_TIMEOUT}s (+${OLLAMA_COLD_START_EXTRA}s Cold-Start)"
        echo -e "  Fallback: ${OLLAMA_FALLBACK_MODEL}"
        local cache_count=$(ls -1 "$MEISTER_DIR/cache/" 2>/dev/null | wc -l | xargs)
        echo -e "  Cache:   ${cache_count} Eintraege"
    else
        echo -e "  Ollama:  ${RED}offline${NC}"
    fi
    echo -e "  System:  $(get_system_context 2>/dev/null || echo 'n/a')"
    echo -e "  Disk:    $(df -h / | awk 'NR==2 {print $5}') belegt ($(df -h / | awk 'NR==2 {print $4}') frei)"
    local pc=$(ls -1 "$MEISTER_DIR/patches/" 2>/dev/null | wc -l | xargs)
    echo -e "  Patches: ${pc} gespeichert"
    if [ $pc -gt 0 ]; then
        echo -e "  Letzte:"
        ls -1t "$MEISTER_DIR/patches/" 2>/dev/null | head -5 | while IFS= read -r f; do
            echo -e "    - $f"
        done
    fi
    # Run History
    local history_file="$MEISTER_DIR/history.log"
    if [ -f "$history_file" ]; then
        local run_count=$(wc -l < "$history_file" | xargs)
        echo -e "  Runs:    ${run_count} gesamt"
        echo -e "  Letzte Laeufe:"
        tail -5 "$history_file" | while IFS= read -r line; do
            echo -e "    $line"
        done
    fi
    echo -e "  Config:  $MEISTER_CONFIG"
    # Letzter Benchmark
    local last_bench=$(ls -1t "$BENCHMARK_DIR"/*.json 2>/dev/null | head -1)
    if [ -n "$last_bench" ] && command_exists jq; then
        local b_date=$(basename "$last_bench" .json)
        local b_cpu=$(jq -r '.cpu_ms' "$last_bench" 2>/dev/null)
        local b_dw=$(jq -r '.disk_write_mbps' "$last_bench" 2>/dev/null)
        local b_dr=$(jq -r '.disk_read_mbps' "$last_bench" 2>/dev/null)
        local b_fv=$(jq -r '.security.filevault' "$last_bench" 2>/dev/null)
        local b_fw=$(jq -r '.security.firewall' "$last_bench" 2>/dev/null)
        local b_gk=$(jq -r '.security.gatekeeper' "$last_bench" 2>/dev/null)
        local b_sip=$(jq -r '.security.sip' "$last_bench" 2>/dev/null)
        echo -e "  ─── Benchmark ($b_date) ───"
        echo -e "  CPU:     ${b_cpu}ms | Disk: W:${b_dw}/R:${b_dr} MB/s"
        echo -e "  Security: FV:$b_fv FW:$b_fw GK:$b_gk SIP:$b_sip"
        local bench_count=$(ls -1 "$BENCHMARK_DIR"/*.json 2>/dev/null | wc -l | xargs)
        echo -e "  History: ${bench_count} Benchmarks gespeichert"
    fi
    echo -e "${MAGENTA}═══════════════════════════════════════${NC}"
}

# Fix #50: Fehlerbehandlung in ollama_summary
ollama_summary() {
    if ! ollama_available; then
        log STEP "   Ollama offline - keine AI-Zusammenfassung"
        return
    fi

    local total=$((${#REPORT_SUCCESS[@]} + ${#REPORT_FIXED[@]} + ${#REPORT_WARNINGS[@]} + ${#REPORT_ERRORS[@]} + ${#REPORT_HEALED[@]}))
    [ $total -eq 0 ] && return

    log HEAL "Erstelle AI-Zusammenfassung..."
    local summary_prompt="Du bist ein macOS Admin. Fasse diesen Wartungsbericht kurz zusammen (max 3 Saetze, Deutsch):
OK: ${REPORT_SUCCESS[*]:-keine}
Fixed: ${REPORT_FIXED[*]:-keine}
Warnings: ${REPORT_WARNINGS[*]:-keine}
Errors: ${REPORT_ERRORS[*]:-keine}
AI-Healed: ${REPORT_HEALED[*]:-keine}
Gib eine kurze Bewertung und ggf. empfohlene naechste Schritte. Keine <think>-Tags."

    local summary
    # Kein Cache fuer Summary (jeder Lauf hat andere Daten)
    summary=$(ollama_query "$summary_prompt" "false")
    if [ -n "$summary" ]; then
        echo ""
        echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${MAGENTA}  AI-Zusammenfassung (${OLLAMA_MODEL})${NC}"
        echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo "$summary" | while IFS= read -r line; do
            echo -e "  $line"
        done
        echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    else
        log WARN "   AI-Zusammenfassung fehlgeschlagen (Ollama-Query Timeout oder Fehler)"
        report_add WARN "AI-Zusammenfassung konnte nicht erstellt werden"
    fi
}

#############################
# 8. LOG-ANALYSE (Fix #27)
#############################

log_analysis() {
    local history_file="$MEISTER_DIR/history.log"
    [ ! -f "$history_file" ] && return
    local run_count=$(wc -l < "$history_file" | xargs)
    [ "$run_count" -lt 3 ] && return

    log INFO "Log-Analyse: Pruefe wiederkehrende Probleme..."

    # Warnings und Errors aus letzten 5 Runs zaehlen
    local recent_warns=""
    if [ -f "$LOGFILE" ]; then
        recent_warns=$(grep -E "^.* - (WARN|ERROR) - " "$LOGFILE" 2>/dev/null | \
            sed 's/^.* - \(WARN\|ERROR\) - //' | sort | uniq -c | sort -rn | head -10)
    fi

    # Auch .old Log einbeziehen
    if [ -f "${LOGFILE}.old" ]; then
        local old_warns=$(grep -E "^.* - (WARN|ERROR) - " "${LOGFILE}.old" 2>/dev/null | \
            sed 's/^.* - \(WARN\|ERROR\) - //' | sort | uniq -c | sort -rn | head -10)
        if [ -n "$old_warns" ]; then
            recent_warns=$(echo -e "${recent_warns}\n${old_warns}" | sort -rn | head -10)
        fi
    fi

    if [ -n "$recent_warns" ]; then
        local recurring=$(echo "$recent_warns" | awk '$1 >= 3 {$1=""; print}' | sed 's/^ //')
        if [ -n "$recurring" ]; then
            log WARN "   Wiederkehrende Probleme erkannt:"
            echo "$recurring" | while IFS= read -r line; do
                [ -n "$line" ] && log STEP "     - $line"
            done
            report_add WARN "Wiederkehrende Probleme erkannt (siehe Log)"

            # Ollama um Analyse bitten
            if ollama_available; then
                local safe_recurring=$(sanitize_for_prompt "$recurring" 500)
                local analysis
                analysis=$(ollama_query "Diese macOS-Wartungsprobleme treten wiederholt auf:
${safe_recurring}
Gib eine kurze Analyse (max 3 Saetze) und konkrete Loesungsvorschlaege. Deutsch.")
                if [ -n "$analysis" ]; then
                    log HEAL "   AI-Analyse wiederkehrender Probleme:"
                    echo "$analysis" | while IFS= read -r line; do
                        [ -n "$line" ] && log STEP "     $line"
                    done
                fi
            fi
        else
            log STEP "   Keine wiederkehrenden Probleme"
        fi
    fi
}

#############################
# 9. NOTIFICATIONS (Fix #28, #29)
#############################

# Fix #28: terminal-notifier mit Fallback
send_notification() {
    local title="$1"
    local message="$2"
    local subtitle="${3:-}"

    if command_exists terminal-notifier; then
        local tn_args=(-title "$title" -message "$message" -group "meister")
        [ -n "$subtitle" ] && tn_args+=(-subtitle "$subtitle")
        # Clickable: oeffnet Logfile
        tn_args+=(-open "file://$LOGFILE")
        terminal-notifier "${tn_args[@]}" 2>/dev/null
    else
        local osa_msg="$message"
        [ -n "$subtitle" ] && osa_msg="$subtitle: $message"
        osascript -e "display notification \"$osa_msg\" with title \"$title\"" 2>/dev/null
    fi
}

# Fix #29: Pushover-Benachrichtigung
send_pushover() {
    [ -z "$PUSHOVER_USER" ] || [ -z "$PUSHOVER_TOKEN" ] && return
    local title="$1"
    local message="$2"
    local priority="${3:-0}"

    curl -sf --max-time 10 \
        --form-string "token=$PUSHOVER_TOKEN" \
        --form-string "user=$PUSHOVER_USER" \
        --form-string "title=$title" \
        --form-string "message=$message" \
        --form-string "priority=$priority" \
        https://api.pushover.net/1/messages.json >/dev/null 2>&1

    if [ $? -eq 0 ]; then
        log STEP "   Pushover-Benachrichtigung gesendet"
    else
        log WARN "   Pushover-Benachrichtigung fehlgeschlagen"
    fi
}

# Report-Zusammenfassung als String
build_report_summary() {
    local summary="OK:${#REPORT_SUCCESS[@]} FIX:${#REPORT_FIXED[@]} WARN:${#REPORT_WARNINGS[@]} ERR:${#REPORT_ERRORS[@]} HEAL:${#REPORT_HEALED[@]}"
    local end_ts=$(date +%s)
    local total_mins=$(( (end_ts - SCRIPT_START_TIME) / 60 ))
    echo "Meister v0.04 | ${total_mins}min | $summary"
}

send_report_notification() {
    local summary=$(build_report_summary)
    local err_count=${#REPORT_ERRORS[@]}
    local heal_count=${#REPORT_HEALED[@]}

    # Lokale Notification
    if [ "$REPORT_NOTIFY" = "local" ] || [ "$REPORT_NOTIFY" = "all" ]; then
        local subtitle=""
        [ $err_count -gt 0 ] && subtitle="${err_count} Fehler!"
        [ $heal_count -gt 0 ] && subtitle="${subtitle} ${heal_count} AI-Fixes"
        send_notification "Meister" "$summary" "$subtitle"
    fi

    # Pushover
    if [ "$REPORT_NOTIFY" = "pushover" ] || [ "$REPORT_NOTIFY" = "all" ]; then
        local priority=0
        [ $err_count -gt 0 ] && priority=1
        local detail="$summary"
        if [ $err_count -gt 0 ]; then
            detail="${detail}\nErrors: $(printf '%s, ' "${REPORT_ERRORS[@]}")"
        fi
        if [ $heal_count -gt 0 ]; then
            detail="${detail}\nHealed: $(printf '%s, ' "${REPORT_HEALED[@]}")"
        fi
        send_pushover "Meister Report" "$detail" "$priority"
    fi
}

#############################
# 10. LAUNCHAGENT (Fix #30)
#############################

install_launchagent() {
    local script_path=$(cd "$(dirname "$0")" && pwd)/$(basename "$0")
    local plist_path="$HOME/Library/LaunchAgents/com.meister.maintenance.plist"
    local label="com.meister.maintenance"

    # Schedule bestimmen
    local interval_secs=604800  # default: weekly
    local calendar_day=""
    case "$LAUNCHAGENT_SCHEDULE" in
        daily)   interval_secs=86400 ;;
        weekly)  interval_secs=604800 ;;
        monthly) calendar_day="<key>Day</key><integer>1</integer>" ;;
    esac

    log INFO "Installiere LaunchAgent ($LAUNCHAGENT_SCHEDULE)..."
    log STEP "   Script: $script_path"
    log STEP "   Plist:  $plist_path"

    # Bestehenden Agent stoppen
    if launchctl list 2>/dev/null | grep -q "$label"; then
        launchctl unload "$plist_path" 2>/dev/null
        log STEP "   Bestehender Agent gestoppt"
    fi

    mkdir -p "$HOME/Library/LaunchAgents"

    if [ "$LAUNCHAGENT_SCHEDULE" = "monthly" ]; then
        cat > "$plist_path" << PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${label}</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>${script_path}</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Day</key>
        <integer>1</integer>
        <key>Hour</key>
        <integer>10</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <key>StandardOutPath</key>
    <string>${MEISTER_DIR}/launchagent.log</string>
    <key>StandardErrorPath</key>
    <string>${MEISTER_DIR}/launchagent_err.log</string>
    <key>RunAtLoad</key>
    <false/>
</dict>
</plist>
PLISTEOF
    else
        cat > "$plist_path" << PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${label}</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>${script_path}</string>
    </array>
    <key>StartInterval</key>
    <integer>${interval_secs}</integer>
    <key>StandardOutPath</key>
    <string>${MEISTER_DIR}/launchagent.log</string>
    <key>StandardErrorPath</key>
    <string>${MEISTER_DIR}/launchagent_err.log</string>
    <key>RunAtLoad</key>
    <false/>
</dict>
</plist>
PLISTEOF
    fi

    launchctl load "$plist_path" 2>/dev/null
    if launchctl list 2>/dev/null | grep -q "$label"; then
        log FIX "LaunchAgent installiert und geladen"
        log INFO "   Schedule: $LAUNCHAGENT_SCHEDULE"
        log INFO "   Deinstallieren: launchctl unload $plist_path && rm $plist_path"
        echo ""
        echo -e "${GREEN}LaunchAgent erfolgreich installiert!${NC}"
        echo -e "  Schedule:      $LAUNCHAGENT_SCHEDULE"
        echo -e "  Plist:         $plist_path"
        echo -e "  Log:           $MEISTER_DIR/launchagent.log"
        echo -e "  Deinstallieren: launchctl unload $plist_path"
    else
        log ERROR "LaunchAgent konnte nicht geladen werden"
        echo -e "${RED}LaunchAgent Installation fehlgeschlagen!${NC}"
    fi
}

# ── Args (Fix #37: -a fuer alle Module) ──
while getopts ":aAXMTSCLOhcHnIPG" opt; do
  case $opt in
    a) RUN_CLAMAV=true; CLEAN_XCODE=true; RUN_MONOLINGUAL=true; EMPTY_TRASH=true
       RUN_SUDO_TASKS=true; CLEAN_CACHES=true; LIST_LARGE_FILES=true; RUN_PERF_TUNE=true; RUN_GIT_REPOS=true; NEEDS_SUDO=true ;;
    G) RUN_GIT_REPOS=true ;;
    P) RUN_PERF_TUNE=true; NEEDS_SUDO=true ;;
    A) RUN_CLAMAV=true; NEEDS_SUDO=true ;;
    X) CLEAN_XCODE=true ;;
    M) RUN_MONOLINGUAL=true ;;
    T) EMPTY_TRASH=true ;;
    S) RUN_SUDO_TASKS=true; NEEDS_SUDO=true ;;
    C) CLEAN_CACHES=true; NEEDS_SUDO=true ;;
    L) LIST_LARGE_FILES=true ;;
    O) RUN_LMSTUDIO_COPY=true ;;
    c) CLAMAV_ONLY=true; RUN_CLAMAV=true; NEEDS_SUDO=true ;;
    H) SHOW_HEALTH=true ;;
    n) DRY_RUN=true ;;
    I) INSTALL_LAUNCHAGENT=true ;;
    h) cat << 'HELPEOF'
meister2026.sh - macOS Maintenance, Update & Self-Healing

VERWENDUNG:
  meister [FLAGS]

GRUNDMODI:
  (ohne Flags)   Standard-Wartung (Brew, macOS, Office, Ollama, Deep Clean, Performance, Benchmark)
  -a             Alle optionalen Module aktivieren (= -AXMTSCLP)
  -n             Dry-Run: zeigt alle Aenderungen, fuehrt nichts aus
  -H             Health Dashboard anzeigen (kein Wartungslauf)
  -P             Performance-Tuning anwenden (DNS, TCP, Kernel, GUI, Spotlight)

OPTIONALE MODULE:
  -A             ClamAV Malware-Scan (braucht sudo)
  -X             Xcode DerivedData loeschen
  -M             Monolingual installieren (Sprachpakete entfernen)
  -T             Papierkorb leeren
  -S             Sudo-Tasks: periodic scripts, DNS-Flush, RAM-Purge
  -C             User & System Caches loeschen (braucht sudo)
  -L             Grosse Dateien auflisten (keine Loeschung)
  -O             LM Studio Modell-Sync
  -G             Git Repos: unpushed Commits pushen + Backup nach iCloud

ADMINISTRATION:
  -I             LaunchAgent installieren (taegl./woechentl./monatl.)
  -c             Nur ClamAV-Scan (ueberspringt alle anderen Module)

PERFORMANCE (automatisch analysiert, -P wendet Fixes an):
  DNS-Optimierung (Cloudflare/Google), TCP-Buffer, Kernel-Limits,
  SSD TRIM/SMART, Spotlight-Exclusions, Memory/CPU-Hogs killen,
  WindowServer, Swap-Analyse, Service-Audit, GUI-Animationen,
  Power Management, Login Items entfernen, LaunchAgents deaktivieren,
  Ollama Model Cleanup, RAM Purge

DEEP CLEAN (automatisch bei jedem Lauf):
  System-Logs, alte Downloads (DMG/PKG/ZIP), Orphaned Preferences,
  Broken Plists, Mail-Attachments, alte Screenshots, TM-Snapshots,
  Launch Services DB, Spotlight, Recent Items, Duplikate, iOS-Backups,
  Login Items, npm/pip/yarn/gem Caches, CocoaPods/SPM/Carthage,
  Docker, Parallels-Logs, Font/QuickLook-Cache, Quarantine-Attribute

GIT REPOS (-G aktiviert Push + Backup):
  Alle Repos unter Documents/Projekte scannen (maxdepth 5),
  unpushed Commits automatisch pushen, uncommitted Changes warnen,
  tar.gz-Backup aller Repos nach iCloud Drive, alte Backups aufraeumen

BENCHMARK (max 1x/24h):
  CPU, Disk I/O, Netzwerk, RAM, Security-Audit (FileVault/Firewall/SIP)

KONFIGURATION:
  ~/.meister/config      Einstellungen (Modell, Timeouts, Module an/aus)
  ~/.meister/meister.log Logfile
  ~/.meister/benchmarks/ Benchmark-Historie (JSON)
  ~/.meister/cache/      Ollama Query-Cache

BEISPIELE:
  meister                Standard-Wartung
  meister -a             Alle Module (inkl. ClamAV, Caches, Trash)
  meister -n -a          Dry-Run: zeige alles ohne Aenderungen
  meister -H             Nur Health Dashboard
  meister -I             LaunchAgent fuer automatische Wartung
  meister -c             Nur Malware-Scan
  meister -G             Git Repos pushen + iCloud Backup
  meister -n -G          Dry-Run: zeige was gepusht/gesichert wuerde
HELPEOF
       exit 0 ;;
    \?) log ERROR "Unbekannte Option: -$OPTARG"; exit 1 ;;
  esac
done

# ── START ──
rotate_logs
acquire_lock

echo -e "${BOLD}${BLUE}"
echo "  ╔══════════════════════════════════════════╗"
echo "  ║        MEISTER v0.04                     ║"
echo "  ║   macOS Maintenance & Self-Healing       ║"
$DRY_RUN && echo "  ║   [DRY-RUN MODUS]                        ║"
echo "  ╚══════════════════════════════════════════╝"
echo -e "${NC}"

log INFO "Meister v0.04 gestartet ($(date))"
$DRY_RUN && log WARN "DRY-RUN: Keine Aenderungen werden vorgenommen"
log STEP "   Logfile: $LOGFILE"
[ -f "$MEISTER_CONFIG" ] && log STEP "   Config: $MEISTER_CONFIG geladen"
log STEP "   Flags: CLAMAV=$RUN_CLAMAV XCODE=$CLEAN_XCODE MONO=$RUN_MONOLINGUAL TRASH=$EMPTY_TRASH SUDO=$RUN_SUDO_TASKS CACHE=$CLEAN_CACHES LARGE=$LIST_LARGE_FILES LMS=$RUN_LMSTUDIO_COPY PERF=$RUN_PERF_TUNE GIT=$RUN_GIT_REPOS DRY=$DRY_RUN NOTIFY=$REPORT_NOTIFY"

# Fix #41: Zentraler Ollama-Starter + Fix #45: Modell-Check
if ollama_available || ensure_ollama_running ""; then
    log INFO "Ollama: online (${OLLAMA_MODEL})"
    local_models=$(ollama_list_cached | awk 'NR>1 {print $1}' | tr '\n' ', ')
    log STEP "   Modelle: ${local_models:-keine}"
    # Fix #45: Pruefen ob konfiguriertes Modell verfuegbar ist
    ensure_ollama_model
else
    log WARN "Ollama: nicht verfuegbar - kein AI-Heal"
    OLLAMA_ENABLED=false
fi

if $SHOW_HEALTH; then health_dashboard; release_lock; exit 0; fi
if $INSTALL_LAUNCHAGENT; then install_launchagent; release_lock; exit 0; fi

# Sudo immer anfordern (brew cask, migration, etc. brauchen es)
if ! $DRY_RUN; then
    log INFO "Requesting Sudo (brew cask + migration brauchen root)..."
    if sudo -v; then
        keep_sudo
        log INFO "   Sudo OK"
    else
        log WARN "Sudo verweigert - einige Operationen koennten fehlschlagen"
        report_add WARN "Sudo nicht verfuegbar"
    fi
fi

# Modul-Anzahl berechnen
if $CLAMAV_ONLY; then
    MODULE_TOTAL=2
else
    MODULE_TOTAL=13
    $RUN_CLAMAV && MODULE_TOTAL=$((MODULE_TOTAL + 1))
    $RUN_SUDO_TASKS && MODULE_TOTAL=$((MODULE_TOTAL + 1))
fi

# Preflight
section_header "Self-Healing Preflight"
module_timer_start
selfheal_preflight
module_timer_stop "Preflight"

if check_net; then
    if $CLAMAV_ONLY; then
        run_module_safe "ClamAV" module_clamav
    else
        run_module_safe "Homebrew"       module_homebrew
        run_module_safe "App Migration"  module_migration
        run_module_safe "App Store"      module_mas
        run_module_safe "MS Office"      module_office
        run_module_safe "Ollama Models"  module_ollama
        run_module_safe "macOS System"   module_system
        run_module_safe "Cleanup"        module_cleanup
        run_module_safe "Deep Clean"     module_deepclean
        run_module_safe "Performance"    module_performance
        run_module_safe "Git Repos"      module_git_repos
        run_module_safe "Benchmark"      module_benchmark

        $RUN_CLAMAV && run_module_safe "ClamAV" module_clamav

        if $RUN_SUDO_TASKS; then
            section_header "System Maintenance (sudo)"
            module_timer_start
            log INFO "Starte periodic scripts..."
            log STEP "   periodic daily..."
            run_or_dry sudo periodic daily
            log STEP "   periodic weekly..."
            run_or_dry sudo periodic weekly
            log STEP "   periodic monthly..."
            run_or_dry sudo periodic monthly
            log INFO "   DNS-Cache flush..."
            run_or_dry sudo dscacheutil -flushcache
            report_add FIX "Ran periodic scripts & DNS flush"
            module_timer_stop "System Maintenance"
        fi
    fi
else
    log ERROR "Abbruch: Kein Internet"
fi

log_analysis
ollama_summary
print_report
save_history
send_report_notification
release_lock

# Fix #38: Exit-Code 1 bei Errors
[ ${#REPORT_ERRORS[@]} -gt 0 ] && exit 1
exit 0
