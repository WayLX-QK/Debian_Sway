#!/usr/bin/env bash
set -euo pipefail

BASHRC="$HOME/.bashrc"

add_block() {
    local marker="$1"
    local block="$2"

    if grep -qF "$marker" "$BASHRC"; then
        echo "ℹ️ $marker already present in $BASHRC"
    else
        echo "$block" >> "$BASHRC"
        echo "✅ Added $marker to $BASHRC"
    fi
}

# --- Blocks ---
EZA_ALIASES=$(cat <<'EOF'

# --- eza aliases ---
alias ls='eza --color=auto --icons=auto'
alias eza='eza --color=auto --icons=auto'
alias ll='eza -l'
alias la='eza -lah'
alias lt='eza -T'
EOF
)

HISTORY_BLOCK=$(cat <<'EOF'

# --- Live shared bash history across sessions ---
HISTCONTROL=ignoreboth:erasedups
HISTSIZE=100000
HISTFILESIZE=200000
shopt -s histappend
PROMPT_COMMAND="history -a; history -c; history -r; $PROMPT_COMMAND"
EOF
)

UPDATE_ALIASES=$(cat <<'EOF'

# --- update and clean aliases ---
alias update='sudo apt update && sudo apt upgrade -y'
alias clean='sudo apt autoremove -y && sudo apt autoclean'
EOF
)

# --- Menu ---
echo "Which configs would you like to add to your ~/.bashrc?"
read -rp "Add eza aliases? (y/n) " ans
[[ $ans == [Yy]* ]] && add_block "eza aliases" "$EZA_ALIASES"

read -rp "Add live shared history config? (y/n) " ans
[[ $ans == [Yy]* ]] && add_block "Live shared bash history" "$HISTORY_BLOCK"

read -rp "Add update/clean aliases? (y/n) " ans
[[ $ans == [Yy]* ]] && add_block "update and clean aliases" "$UPDATE_ALIASES"

# Reload bashrc if interactive
if [[ $- == *i* ]]; then
    # shellcheck source=/dev/null
    source "$BASHRC"
    echo "🔄 Reloaded $BASHRC"
fi
