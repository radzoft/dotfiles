# ~/.bash_profile — managed by dotfiles (~/dotfiles)

# Source .bashrc (handles all env setup)
[ -f ~/.bashrc ] && . ~/.bashrc

# Python managed by mise — no pyenv needed

# ── Bun globals (login shell) ────────────────────────────────────────────────
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# ── LM Studio CLI ─────────────────────────────────────────────────────────────
export PATH="$PATH:$HOME/.lmstudio/bin"

# ── Mise env ──────────────────────────────────────────────────────────────────
[ -f "$HOME/.local/share/../bin/env" ] && . "$HOME/.local/share/../bin/env"
