# ~/.bash_profile — managed by dotfiles (~/dotfiles)

# Source .bashrc (handles all env setup)
[ -f ~/.bashrc ] && . ~/.bashrc

# ── Pyenv (login shell) ───────────────────────────────────────────────────────
export PYENV_ROOT="$HOME/.pyenv"
[[ -d "$PYENV_ROOT/bin" ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init - bash 2>/dev/null || true)"

# ── Volta (login shell) ───────────────────────────────────────────────────────
export VOLTA_HOME="$HOME/.volta"
export PATH="$VOLTA_HOME/bin:$PATH"

# ── Bun (login shell) ─────────────────────────────────────────────────────────
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# ── LM Studio CLI ─────────────────────────────────────────────────────────────
export PATH="$PATH:$HOME/.lmstudio/bin"

# ── Mise env ──────────────────────────────────────────────────────────────────
[ -f "$HOME/.local/share/../bin/env" ] && . "$HOME/.local/share/../bin/env"
