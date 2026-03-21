# ~/.bashrc — managed by dotfiles repo (~/dotfiles)
# Edit source at: ~/dotfiles/home/.bashrc

# ── OpenSpec completions ──────────────────────────────────────────────────────
if [ -d "$HOME/.local/share/bash-completion/completions" ]; then
  for f in "$HOME/.local/share/bash-completion/completions"/*; do
    [ -f "$f" ] && . "$f"
  done
fi

# ── System bashrc ─────────────────────────────────────────────────────────────
[ -f /etc/bashrc ] && . /etc/bashrc

# ── PATH ──────────────────────────────────────────────────────────────────────
if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]; then
  PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi
export PATH

# ── History ───────────────────────────────────────────────────────────────────
HISTCONTROL=ignoreboth
shopt -s histappend
HISTSIZE=700000
HISTFILESIZE=700000

# ── Oh My Bash ────────────────────────────────────────────────────────────────
export OSH="$HOME/.oh-my-bash"
OSH_THEME="font"
ENABLE_CORRECTION="true"
COMPLETION_WAITING_DOTS="true"
DISABLE_UNTRACKED_FILES_DIRTY="true"
OMB_USE_SUDO=true
OMB_PROMPT_SHOW_PYTHON_VENV=true

completions=(git ssh go npm pip3 pip system tmux)
aliases=(general)
plugins=(git progress pyenv xterm)

source "$OSH/oh-my-bash.sh"

shopt -s checkwinsize
shopt -s autocd

# ── Mise ──────────────────────────────────────────────────────────────────────
eval "$("$HOME/.local/bin/mise" activate bash 2>/dev/null || mise activate bash)"

# Python managed by mise (python = "3.13" in ~/.config/mise/config.toml)
# uv handles isolated script environments (e.g. ttgo2.py)

# ── Bun globals (bun version managed by mise; globals installed via bun add -g) ──
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# ── pnpm ──────────────────────────────────────────────────────────────────────
export PNPM_HOME="$HOME/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac

# ── Other PATH additions ───────────────────────────────────────────────────────
export PATH="$HOME/.opencode/bin:$PATH"
export PATH="$HOME/.claude/scripts:$PATH"
export PATH="$PATH:$HOME/.lmstudio/bin"

# ── Env ───────────────────────────────────────────────────────────────────────
export GPG_TTY=$(tty)
export LANGUAGE="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"
export LC_CTYPE="en_US.UTF-8"
export LANG="en_US.UTF-8"
export QT_SCREEN_SCALE_FACTORS="1;1"
export NODE_OPTIONS="--max-old-space-size=8192"
export DJANGO_SETTINGS_MODULE="config.settings.development_local"

# ── FZF ───────────────────────────────────────────────────────────────────────
eval "$(fzf --bash 2>/dev/null || true)"

# ── Zoxide ────────────────────────────────────────────────────────────────────
eval "$(zoxide init bash --no-cmd 2>/dev/null || true)"

# ── Mise local bin env ────────────────────────────────────────────────────────
[ -f "$HOME/.local/share/../bin/env" ] && . "$HOME/.local/share/../bin/env"

# ── Aliases ───────────────────────────────────────────────────────────────────
alias python="python3"
alias py="python"
alias pym="python manage.py"
alias buildw="npm run build-watch"
alias git-z='git reset --soft HEAD~'
alias ignore="git update-index --assume-unchanged"
alias unignore="git update-index --no-assume-unchanged"
alias code_="code-insiders --user-data-dir=$HOME/.code-insiders"
alias claude-dev="devcontainer exec --workspace-folder . claude --dangerously-skip-permissions"
alias dev="devcontainer up --workspace-folder $HOME/valormm && devcontainer exec --workspace-folder $HOME/valormm zsh"

# ── DNS management ────────────────────────────────────────────────────────────
dns-clear() {
  echo "Clearing DNS cache..."
  sudo systemctl restart dnsmasq
  sudo resolvectl flush-caches 2>/dev/null || true
  echo "DNS cache cleared."
}

dns-seansoft() {
  echo "Switching DNS to Seansoft server..."
  sudo sed -i '3s/^#\+//' /etc/dnsmasq.d/mineraltech.conf
  sudo sed -i '4s/^address/#address/' /etc/dnsmasq.d/mineraltech.conf
  dns-clear
}

dns-local() {
  echo "Switching DNS to local (127.0.0.1)..."
  sudo sed -i '3s/^address/#address/' /etc/dnsmasq.d/mineraltech.conf
  sudo sed -i '4s/^#\+//' /etc/dnsmasq.d/mineraltech.conf
  dns-clear
}

# ── PostgreSQL btrfs snapshots ────────────────────────────────────────────────
pg-backup() {
  local backup_name="${1:-default}"
  local target_path="/volumes/postgres.$backup_name"
  if [ -e "$target_path" ]; then
    echo "Warning: $backup_name exists — overwriting..."
    sudo btrfs subvolume delete "$target_path"
  fi
  docker stop postgresGlen 2>/dev/null || true
  sudo btrfs subvolume snapshot -r /volumes/postgres.active "$target_path"
  docker start postgresGlen
  echo "Backup created: $target_path"
}

pg-restore() {
  local source_name="${1:-default}"
  docker stop postgresGlen 2>/dev/null || true
  sudo btrfs subvolume delete /volumes/postgres.active
  sudo btrfs subvolume snapshot "/volumes/postgres.$source_name" /volumes/postgres.active
  docker start postgresGlen
  echo "Restored from: $source_name"
}

# ── User-specific bashrc.d ────────────────────────────────────────────────────
if [ -d ~/.bashrc.d ]; then
  for rc in ~/.bashrc.d/*; do
    [ -f "$rc" ] && . "$rc"
  done
fi
unset rc

# ── Secrets (API keys, tokens — NOT tracked in git) ──────────────────────────
[ -f "$HOME/.bashrc.secrets" ] && . "$HOME/.bashrc.secrets"
