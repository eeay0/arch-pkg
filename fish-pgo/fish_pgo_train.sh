#!/usr/bin/env bash
# =============================================================================
# fish_pgo_train.sh — PGO training workload for fish shell
#
# Usage:
#   chmod +x fish_pgo_train.sh
#   ./fish_pgo_train.sh [path/to/fish]
#
# If no path is given, it auto-detects the cargo-pgo instrumented binary.
# =============================================================================

set -euo pipefail

# ── Resolve fish binary ───────────────────────────────────────────────────────

if [[ -n "${1:-}" ]]; then
    FISH="$1"
else
    # cargo-pgo puts the instrumented binary here (adjust triple if needed)
    TRIPLE=$(rustc -vV 2>/dev/null | awk '/host:/{print $2}')
    FISH="./target/${TRIPLE}/release/fish"
fi

if [[ ! -x "$FISH" ]]; then
    echo "ERROR: fish binary not found at: $FISH"
    echo "       Run 'cargo pgo build' first, or pass the path as an argument."
    exit 1
fi

echo "==> Using fish binary: $FISH"
echo "==> Training started at: $(date)"
echo

# Helper — run a fish snippet with a 5s timeout, print what's being exercised
run() {
    local label="$1"
    local code="$2"
    printf "  [train] %-45s" "$label..."
    if timeout 5s "$FISH" -c "$code" > /dev/null 2>&1; then
        echo "ok"
    else
        local exit_code=$?
        if [[ $exit_code -eq 124 ]]; then
            echo "TIMEOUT (skipped)"
        else
            echo "skip"
        fi
    fi
}

# ── 1. STARTUP / INIT ─────────────────────────────────────────────────────────
echo "── 1. Startup & init"
for i in $(seq 1 20); do
    "$FISH" -c 'exit' > /dev/null 2>&1
done
echo "  [train] Cold starts (x20)                               ok"

# ── 2. BUILTINS ───────────────────────────────────────────────────────────────
echo "── 2. Builtins"
run "echo"              'echo hello world'
run "echo -n"           'echo -n no newline'
run "printf"            'printf "%s %d\n" hello 42'
run "status"            'status'
run "status is-login"   'status is-login'
run "status fish-path"  'status fish-path'
run "pwd"               'pwd'
run "cd + pushd/popd"   'cd /tmp; cd /usr; cd -'
run "set local"         'set -l x 1 2 3; echo $x'
run "set global"        'set -g myvar hello; echo $myvar'
run "set erase"         'set -l tmp foo; set -e tmp'
run "set -q"            'set -l v 1; set -q v; echo $status'
run "count"             'count a b c d e'
run "contains"          'contains b a b c'
run "functions -a"      'functions -a'
run "functions -q"      'functions -q fish_prompt'
run "builtin -n"        'builtin -n'
run "command -v"        'command -v ls'
run "command -a"        'command -a cat'
run "type"              'type ls'
run "which"             'which cat'
run "jobs"              'jobs'
run "history"           'history | head -5'
run "history search"    'history search echo'
run "abbr --list"       'abbr --list'

# ── 3. STRING BUILTIN ─────────────────────────────────────────────────────────
echo "── 3. string"
run "string length"         'string length hello'
run "string length -q"      'string length -q ""'
run "string sub"            'string sub -s 2 -l 3 "hello"'
run "string split"          'string split , "a,b,c,d"'
run "string split0"         'printf "a\0b\0c" | string split0'
run "string join"           'string join - a b c'
run "string join0"          'string join0 a b c | string split0'
run "string trim"           'string trim "  hello  "'
run "string trim --left"    'string trim --left "  hi"'
run "string trim --right"   'string trim --right "hi  "'
run "string lower"          'string lower "HELLO WORLD"'
run "string upper"          'string upper "hello world"'
run "string repeat"         'string repeat -n 5 "ab"'
run "string reverse"        'string reverse "hello"'
run "string pad"            'string pad -w 10 "hi"'
run "string match glob"     'string match "foo*" foobar foobaz'
run "string match -r"       'string match -r "(\d+)" "abc123def"'
run "string match -ra"      'string match -ra "\w+" "hello world fish"'
run "string replace"        'string replace foo bar "foo baz foo"'
run "string replace -r"     'string replace -r "(\w+)" "[$1]" "hello world"'
run "string replace -ra"    'string replace -ra "o" "0" "foo boo zoo"'
run "string collect"        'printf "a\nb\nc\n" | string collect'
run "string escape"         'string escape "hello world & more"'
run "string unescape"       'string unescape "hello\\tworld"'

# ── 4. MATH ───────────────────────────────────────────────────────────────────
echo "── 4. math"
run "basic arithmetic"      'math "1 + 2 * 3 - 4 / 2"'
run "floats"                'math "3.14159 * 2^10"'
run "modulo"                'math "17 % 5"'
run "functions"             'math "sin(3.14/2) + cos(0)"'
run "log/exp"               'math "log(100) + exp(1)"'
run "floor/ceil"            'math "floor(3.7) + ceil(3.2)"'
run "abs"                   'math "abs(-42)"'
run "min/max"               'math "min(3,1,4,1,5) + max(3,1,4,1,5)"'
run "bitwise AND"           'math "0xFF & 0x0F"'
run "bitwise OR"            'math "0xF0 | 0x0F"'
run "hex output"            'math -s0 --base=16 "255"'
run "octal output"          'math -s0 --base=8 "255"'

# ── 5. PATH BUILTIN ───────────────────────────────────────────────────────────
echo "── 5. path"
run "path basename"         'path basename /usr/local/bin/fish'
run "path dirname"          'path dirname /usr/local/bin/fish'
run "path extension"        'path extension /etc/fish/config.fish'
run "path change-extension" 'path change-extension .bak /etc/config.fish'
run "path normalize"        'path normalize /usr/../usr/./local'
run "path join"             'path join /usr local bin fish'
run "path split"            'path split /usr/local/bin'
run "path is -d"            'path is -d /tmp'
run "path is -f"            'path is -f /etc/hostname'
run "path filter"           'path filter -d /tmp /nonexistent'
run "path resolve"          'path resolve /etc/hostname'

# ── 6. CONTROL FLOW ───────────────────────────────────────────────────────────
echo "── 6. Control flow"
run "if/else"               'if test 1 -lt 2; echo yes; else; echo no; end'
run "if/else if"            'set x 5; if test $x -lt 3; echo low; else if test $x -lt 7; echo mid; else; echo high; end'
run "while"                 'set i 0; while test $i -lt 10; set i (math $i + 1); end; echo $i'
run "for list"              'for x in a b c d e; echo $x; end'
run "for range"             'for i in (seq 1 10); math $i ^ 2; end'
run "switch/case"           'switch foo; case bar; echo bar; case foo; echo foo; case "*"; echo other; end'
run "break"                 'for i in 1 2 3; if test $i = 2; break; end; end'
run "continue"              'for i in 1 2 3 4 5; if test $i = 3; continue; end; echo $i; end'
run "return"                'function myfn; return 42; end; myfn; echo $status'
run "and/or"                'true && echo yes; false || echo fallback'
run "not"                   'not false; echo $status'

# ── 7. FUNCTIONS ──────────────────────────────────────────────────────────────
echo "── 7. Functions"
run "define + call"         'function greet; echo "Hello, $argv[1]!"; end; greet World'
run "argv"                  'function sum; math $argv[1] + $argv[2]; end; sum 3 7'
run "multiple return vals"  'function pair; echo one; echo two; end; set a (pair); echo $a'
run "recursive"             'function fib; if test $argv[1] -le 1; echo $argv[1]; return; end; math (fib (math $argv[1] - 1)) + (fib (math $argv[1] - 2)); end; fib 8'
run "variadic"              'function mycat; for a in $argv; echo $a; end; end; mycat x y z'
run "description"           'function documented --description "test fn"; echo ok; end; functions documented'
run "erase function"        'function tmp_fn; echo x; end; functions -e tmp_fn'
run "function -q"           'function -q fish_prompt'

# ── 8. VARIABLES & SCOPING ────────────────────────────────────────────────────
echo "── 8. Variables & scoping"
run "list variable"         'set fruits apple banana cherry; echo $fruits[2]'
run "list slice"            'set a 1 2 3 4 5; echo $a[2..4]'
run "list count"            'set a x y z; echo (count $a)'
run "list append"           'set -l a 1 2; set -a a 3 4; echo $a'
run "list prepend"          'set -l a 3 4; set -p a 1 2; echo $a'
run "nested expansion"      'set key PATH; echo $$key | string split : | head -3'
run "string interpolation"  'set name fish; echo "Hello $name shell"'
run "brace expansion"       'echo {a,b,c}{1,2,3}'
run "tilde expansion"       'echo ~/test | string match "*test"'
run "env vars"              'echo $HOME $USER $SHELL'
run "status vars"           'echo $status $pipestatus'

# ── 9. COMMAND SUBSTITUTION & PIPES ───────────────────────────────────────────
echo "── 9. Command substitution & pipes"
run "basic subst"           'echo (math 2 + 2)'
run "nested subst"          'echo (string upper (string repeat -n 3 ab))'
run "pipe"                  'echo -e "c\na\nb" | sort'
run "pipe chain"            'seq 1 20 | string match -r "[02468]$" | wc -l'
run "stderr redirect"       'echo err >&2; echo ok'
run "redirect to file"      'echo hello > /tmp/fish_pgo_test.txt; cat /tmp/fish_pgo_test.txt; rm /tmp/fish_pgo_test.txt'
run "append redirect"       'echo line1 > /tmp/fish_pgo_a.txt; echo line2 >> /tmp/fish_pgo_a.txt; cat /tmp/fish_pgo_a.txt; rm /tmp/fish_pgo_a.txt'
run "process substitution"  'diff (echo a | psub) (echo a | psub); echo $status'
run "pipestatus"            'true | false | true; echo $pipestatus'

# ── 10. TEST / CONDITIONALS ───────────────────────────────────────────────────
echo "── 10. test"
run "test -n"               'test -n "hello"; echo $status'
run "test -z"               'test -z ""; echo $status'
run "test -eq"              'test 5 -eq 5; echo $status'
run "test -ne"              'test 5 -ne 6; echo $status'
run "test -lt/gt"           'test 3 -lt 5; echo $status'
run "test -f"               'test -f /etc/hostname; echo $status'
run "test -d"               'test -d /tmp; echo $status'
run "test -e"               'test -e /usr/bin; echo $status'
run "test -r"               'test -r /etc/hostname; echo $status'
run "test -s"               'test -s /etc/hostname; echo $status'
run "[ ] syntax"            '[ 1 -eq 1 ]; echo $status'

# ── 11. COMPLETIONS (cold-path exercise) ──────────────────────────────────────
echo "── 11. Completions infrastructure"
run "complete -l list"      'complete -C "git " | head -5'
run "complete -C echo"      'complete -C "echo --" | head -5'
run "complete -C ls"        'complete -C "ls --" | head -5'
run "complete -C cd"        'complete -C "cd /" | head -5'
run "complete -C set"       'complete -C "set -" | head -5'

# ── 12. MISC / REAL-WORLD PATTERNS ────────────────────────────────────────────
echo "── 12. Misc & real-world patterns"
run "read"                  'echo "hello" | read line; echo $line'
run "read -l list"          'echo "a b c" | read -la words; echo $words'
run "read -d delimiter"     'echo "a,b,c" | read -d , first rest; echo $first'
run "random"                'math (random 1 100) \>= 1'
run "seq"                   'set nums (seq 1 5); math (string join + $nums)'
run "time"                  'time echo hello'
run "isatty"                'isatty stdin; echo $status'
run "string + math combo"   'set nums 3 1 4 1 5 9; math (string join + $nums)'
run "glob expansion"        'for f in /etc/*.conf; echo $f; break; end'
run "semicolon chain"       'echo a; echo b; echo c'
run "multiline string"      'set s "line one\nline two\nline three"; echo $s'
run "universal var"         'set -U _pgo_test_var 42; echo $_pgo_test_var; set -Ue _pgo_test_var'
run "fish_indent"           'echo "if true\necho hi\nend" | fish_indent'

# ── Done ─────────────────────────────────────────────────────────────────────
echo
echo "==> Training complete at: $(date)"
echo "==> Now run: cargo pgo optimize"
