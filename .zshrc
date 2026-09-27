if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
# ── Prompt (plain zsh) ───────────────────────
source ~/github/powerlevel10k/powerlevel10k.zsh-theme
export NO_AT_BRIDGE=1
setopt extended_glob
# Enable colors and change prompt:
setopt COMBINING_CHARS
# custom colors


################ 
my-backward-delete-word () {
    local WORDCHARS='~!#$%^&*(){}[]<>?+;'
    WORDCHARS=${WORDCHARS//\/[&.;]}
    zle backward-delete-word
 }
zle -N my-backward-delete-word
bindkey    '\e^?' my-backward-delete-word
bindkey '^H' backward-kill-word     # Ctrl+Backspace
#################################3
bindkey "^[[1;5C" forward-word
bindkey "^[[1;5D" backward-word
#
bindkey "^A" vi-beginning-of-line
bindkey "^E" vi-end-of-line
bindkey "^[[A" up-line-or-beginning-search
bindkey "^[[B" down-line-or-beginning-search
# Skip forward/back a word with opt-arrow
bindkey "\e[1;3D" backward-word     # ⌥←
bindkey "\e[1;3C" forward-word      # ⌥→
bindkey "^[[1;9D" beginning-of-line # cmd+←
bindkey "^[[1;9C" end-of-line       # cmd+→
#
bindkey '^K' kill-line
#
autoload -U up-line-or-beginning-search
autoload -U down-line-or-beginning-search
autoload -U compinit
# Cache completions: only rebuild dump once a day, else use cache (faster startup)
if [[ -n ${ZDOTDIR:-$HOME}/.zcompdump(#qN.mh+24) ]]; then
  compinit -d ${ZDOTDIR:-$HOME}/.zcompdump
else
  compinit -C -d ${ZDOTDIR:-$HOME}/.zcompdump
fi
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
##
#PS1="%B%{$fg[red]%}[%{$fg[yellow]%}%n%{$fg[green]%}@%{$fg[blue]%}%M %{$fg[magenta]%}%~%{$fg[red]%}]%{$reset_color%}   $%b "
# ── Shell options ─────────────────────────
setopt autocd
setopt interactive_comments

# History in cache directory:
HISTSIZE=10000000
SAVEHIST=10000000
HISTFILE=~/.zsh_history
setopt HIST_IGNORE_ALL_DUPS HIST_REDUCE_BLANKS HIST_IGNORE_SPACE SHARE_HISTORY

#PATH
#export CHAFA_FORMAT=sixel
#export TERM=foot
export EDITOR=nvim
typeset -U path PATH
path+=("$HOME/.npm-global/bin" /sbin /usr/sbin /usr/local/sbin "$HOME/.local/bin" "$HOME/.cargo/bin" "$HOME/go/bin")
export PATH
export OLLAMA_NOPRUNE=true
export XDG_SESSION_TYPE=wayland
export SDL_VIDEODRIVER=wayland
export QT_QPA_PLATFORM=wayland

#alias
alias backup-keys='sudo rsync -rv --delete --exclude="S.gpg-agent*" --exclude="S.keyboxd*" ~/.gnupg ~/.password-store /run/media/$USER/External/'
alias nightmode='gammastep -m wayland -P -O 4500'
alias cp='\rsync -av --progress'
alias mv='\rsync -av --progress --remove-source-files'
alias cat='bat'
alias z='zathura'
alias sudo='doas'
alias tree='eza --tree --icons --sort=newest --color=always'
alias u='topgrade'
alias i='doas pacman -S '
alias r='doas pacman -Rnscu '
alias ls='eza --icons --color=always --group-directories-first --sort=newest'
alias l='eza -al --icons --color=always --group-directories-first --sort=newest'
alias sxiv='nsxiv'
alias 00='doas poweroff'
alias 01='doas reboot'
alias m='dbus-run-session niri --session'
alias x='dbus-run-session mango'
alias ip='ip --color=auto'
alias df='df -h'
alias free='free -h'
alias rec='LIBVA_DRIVER_NAME=iHD wl-screenrec -m 60 --codec avc --low-power=off --no-damage -b "20 MB" -f ~/Videos/rec.mp4'
alias rsync='rsync -av --progress'
# run a command in a focused tab of the persistent herdr session
# falls back to running it directly when already inside herdr or when herdr isn't running
open-in-herdr() {
  local label="$1"; shift
  if [[ -n "$HERDR_ENV" ]] || ! herdr status >/dev/null 2>&1; then
    command "$@"
    return
  fi
  local pane
  pane=$(herdr tab create --label "$label" --cwd "$PWD" --focus | jq -r '.result.root_pane.pane_id // empty')
  if [[ -n "$pane" ]]; then
    herdr pane run "$pane" "$@"
  else
    command "$@"
  fi
}
alias yt='yt-x'
opencode() { open-in-herdr opencode opencode "$@" }
wp-tui() { open-in-herdr wp-tui wp-tui "$@" }
alias ytd='yt-dlp  -f "bestvideo[height<=1080]+bestaudio/best[height<=1080]" --audio-quality 0'
alias ytdm='yt-dlp -f "bestaudio[ext=m4a]","bestaudio[ext=webm]" -x '
alias v='nvim'
alias fzf='fzf --preview "bat --color=always {}"'


# --- ripgrep replaces grep (same engine, grep-like vs rich output) ---
alias rg='rg --pretty --smart-case'
alias grep='rg --smart-case --no-heading --color=auto'

command -v colordiff >/dev/null && alias diff='colordiff'

# --- colors for man / less / everything (native, no grc, no systemd) ---
export CLICOLOR=1
export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'
# less with colors (less >= 581 supports --use-color)
export LESS='-R -M -i -j10 --use-color -Dd+r -Du+b -DS+ky -DP+kg -DE+ky -DW+ky'
export MANPAGER='less -R --use-color -Dd+r -Du+b'
export MANROFFOPT='-c'
# keep man + bat in sync (bat config uses base16, follows terminal)
export BAT_THEME='base16'
alias dmesg='dmesg --color=always'

# --- fd (better find) ---
command -v fdfind >/dev/null && alias fd='fdfind'

#eval
if (( $+commands[zoxide] )); then
  eval "$(zoxide init --cmd cd zsh)"
fi
if (( $+commands[tv] )); then
  eval "$(tv init zsh)"
fi
#variables
unsetopt BEEP
[[ -r ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && \
  source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
[[ -r ~/github/somewhere/fzf-tab.plugin.zsh ]] && \
  source ~/github/somewhere/fzf-tab.plugin.zsh
[[ -r $HOME/.local/bin/env ]] && . "$HOME/.local/bin/env"
## [Completion]
## Completion scripts setup. Remove the following line to uninstall
## [/Completion]
# Start tmux automatically if it's not already running
# # Only run in interactive shells
 #if [[ $- == *i* ]]; then
     #if command -v tmux &> /dev/null && [ -z "$TMUX" ]; then
         #tmux attach-session -t default || tmux new-session -s default
   #fi
#fi
###############

#### ------------------------------


#yazi
function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	yazi "$@" --cwd-file="$tmp"
	if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
		builtin cd -- "$cwd"
	fi
	rm -f -- "$tmp"
}

# nvm (lazy-loaded only if installed; ~/.nvm missing right now so this is a no-op)
export NVM_DIR="$HOME/.nvm"
if [[ -s "$NVM_DIR/nvm.sh" ]]; then
  nvm() { unset -f nvm node npm npx 2>/dev/null; source "$NVM_DIR/nvm.sh"; nvm "$@" }
  node() { unset -f nvm node npm npx 2>/dev/null; source "$NVM_DIR/nvm.sh"; node "$@" }
  npm() { unset -f nvm node npm npx 2>/dev/null; source "$NVM_DIR/nvm.sh"; npm "$@" }
  npx() { unset -f nvm node npm npx 2>/dev/null; source "$NVM_DIR/nvm.sh"; npx "$@" }
fi
export PNPM_HOME="$HOME/.local/share/pnpm"
path=("$PNPM_HOME/bin" "$PNPM_HOME" "${path[@]}")

# opencode
export PATH=/home/karasu/.opencode/bin:$PATH

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

. "$HOME/.atuin/bin/env"

eval "$(atuin init zsh)"

# restore normal up-arrow history (skip atuin's up-arrow takeover)
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[OA' up-line-or-beginning-search

# kill ctrl+down / ctrl+pagedown completely (no-op widget)
__nop() { : }
zle -N __nop
bindkey '^[[1;5B' __nop    # ctrl+down
bindkey '\eO5B'   __nop    # ctrl+down (application cursor mode)
bindkey '^[[6;5~' __nop    # ctrl+pagedown
bindkey '\e[6^'   __nop    # ctrl+pagedown (rxvt)

# convert a single video to best-quality a www live wallpaper
alias mp4towall='~/.local/bin/mp4towall'

if [[ -r ~/github/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
  source ~/github/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# Auto-heal stale DBUS_SESSION_BUS_ADDRESS (e.g. shells inherited from
# herdr/long-lived parents across niri restarts via dbus-run-session).
# If the socket in the current address is gone, re-derive it from niri.
if [[ -n "$DBUS_SESSION_BUS_ADDRESS" ]]; then
  _dbus_sock="${DBUS_SESSION_BUS_ADDRESS#*path=}"
  _dbus_sock="${_dbus_sock%%,*}"
  if [[ "$_dbus_sock" == unix:* || ! -S "$_dbus_sock" ]]; then
    for _niri_pid in ${(f)"$(pgrep -x niri 2>/dev/null)"}; do
      if [[ -r "/proc/$_niri_pid/environ" ]]; then
        _fresh_addr="$(tr '\0' '\n' < "/proc/$_niri_pid/environ" 2>/dev/null | sed -n 's/^DBUS_SESSION_BUS_ADDRESS=//p')"
        if [[ -n "$_fresh_addr" ]]; then
          _fresh_sock="${_fresh_addr#*path=}"
          _fresh_sock="${_fresh_sock%%,*}"
          if [[ -S "$_fresh_sock" ]]; then
            export DBUS_SESSION_BUS_ADDRESS="$_fresh_addr"
            break
          fi
        fi
      fi
    done
    unset _niri_pid _fresh_addr _fresh_sock
  fi
  unset _dbus_sock
fi

