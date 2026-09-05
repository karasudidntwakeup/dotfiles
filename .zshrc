if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
# ── Prompt (plain zsh) ───────────────────────
source ~/github/powerlevel10k/powerlevel10k.zsh-theme
zmodload zsh/datetime
autoload -Uz vcs_info
zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:git:*' formats '(%F{green}%b%f)'
zstyle ':vcs_info:git:*' actionformats '(%F{yellow}%b%f|%a)'
typeset -gi __cmd_start=$EPOCHSECONDS
#function __prompt_start() { __cmd_start=$EPOCHSECONDS }
#function __prompt_precmd() {
#  local ret=$?
#  vcs_info
#  PS1=$'\n%F{red}❯ %F{yellow}❯ %F{green}❯%f %F{cyan}%~%f'
#  [[ -n $vcs_info_msg_0_ ]] && PS1+=" $vcs_info_msg_0_"
#  if (( ret )); then PS1+=$' %F{red}❯%f '; else PS1+=$' %F{green}❯%f '; fi
#  RPROMPT=''
#  (( ret )) && RPROMPT+="%F{red}✘ $ret %f"
#  local d=$(( EPOCHSECONDS - __cmd_start ))
#  (( d > 3 )) && RPROMPT+="%F{yellow}${d}s%f "
#  [[ -n $jobstates ]] && RPROMPT+="%F{cyan}%j jobs%f"
#}
preexec_functions+=(__prompt_start)
precmd_functions+=(__prompt_precmd)
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
autoload -U compinit; compinit
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
##
#PS1="%B%{$fg[red]%}[%{$fg[yellow]%}%n%{$fg[green]%}@%{$fg[blue]%}%M %{$fg[magenta]%}%~%{$fg[red]%}]%{$reset_color%}   $%b "

#ZSH_THEME="powerlevel10k"

# ── Shell options ─────────────────────────
setopt autocd
setopt interactive_comments

# History in cache directory:
HISTSIZE=10000000
SAVEHIST=10000000
HISTFILE=~/.zsh_history
HISTDUP=erase
#encoding
set encoding=utf-8
LANG=en_US.UTF-8 
#PATH
#export CHAFA_FORMAT=sixel
#export TERM=foot
export EDITOR=nvim
export PATH="$PATH:$HOME/.npm-global/bin"
export PATH="$PATH:/sbin:/usr/sbin:usr/local/sbin"
export PATH="${PATH}:${HOME}/.local/bin/"
export PATH="${PATH}:${HOME}/.cargo/bin"
export OLLAMA_NOPRUNE=true
export XDG_SESSION_TYPE=wayland
export SDL_VIDEODRIVER=wayland
export QT_QPA_PLATFORM=wayland

#alias
alias backup-keys='sudo rsync -rv --delete --exclude="S.gpg-agent*" --exclude="S.keyboxd*" ~/.gnupg ~/.password-store /mnt/'
alias nightmode='gammastep -m wayland -P -O 4500'
alias cp='cp -a'
alias cal='calcurse'
alias cat='bat'
alias z='zathura'
alias sudo='doas'
alias tree='eza --tree --icons --sort=newest --color=always'
alias lst='tree -L 2 -u -g  -d'
alias u='topgrade'
alias i='doas pacman -S '
alias r='doas pacman -Rnscu '
alias lta='eza --tree --icons --sort=newest'
alias ls=' eza  --icons --color=always --group-directories-first --classify --sort=newest'
alias l='eza -al --icons --color=always --group-directories-first --sort=newest'
alias sl='eza --icons --sort=newest'
alias sxiv='nsxiv'
alias 00='loginctl poweroff'
alias 01='loginctl reboot'
alias x='dbus-run-session niri --session'
alias ip='ip --color=auto'
alias netstat='/usr/bin/grc --colour=auto netstat'
alias df='/usr/bin/grc --colour=auto df'
alias curl='/usr/bin/grc --colour=auto curl'
alias free='/usr/bin/grc --colour=auto free'
alias tail='/usr/bin/grc --colour=auto tail'
alias make='/usr/bin/grc --colour=auto make'
alias head='/usr/bin/grc --colour=auto head'
alias ifconfig='/usr/bin/grc --colour=auto ifconfig'
alias uptime='/usr/bin/grc --colour=auto uptime'
alias rec='LIBVA_DRIVER_NAME=iHD wl-screenrec -m 60 --codec avc --low-power=off --no-damage -b "20 MB" -f ~/Videos/rec.mp4'
alias lsof='/usr/bin/grc --colour=auto lsof'
alias lspci='/usr/bin/grc --colour=auto lspci'
alias lsblk='/usr/bin/grc --colour=auto lsblk'
alias mount='/usr/bin/grc --colour=auto mount'
alias blkid='/usr/bin/grc --colour=auto blkid'
alias env='/usr/bin/grc --colour=auto env'
alias grep='grep -i --color=auto'
alias rsync='rsync -abrv --suffix='date +%F_%H-%M-%S''    
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
yt-x() { open-in-herdr yt-x yt-x "$@" }
alias yt='yt-x'
opencode() { open-in-herdr opencode opencode "$@" }
wp-tui() { open-in-herdr wp-tui wp-tui "$@" }
alias ytd='yt-dlp  -f "bestvideo[height<=1080]+bestaudio/best[height<=1080]" --audio-quality 0'
alias ytdm='yt-dlp -f "bestaudio[ext=m4a]","bestaudio[ext=webm]" -x '
alias v='nvim'
alias timer='tclock timer -d 20m -M'
alias lf='yazi'
alias fzf='fzf --preview "bat --color=always   {}"'
alias sxiv-t="imv \$(ls | fzf)"


# --- ripgrep sane defaults ---
alias rg='rg --pretty --smart-case'

# --- git colors ---
git config --global color.ui auto

# --- diff with color (colordiff or delta) ---
command -v delta >/dev/null && git config --global core.pager "delta"
command -v colordiff >/dev/null && alias diff='colordiff'

# --- fd (better find) ---
command -v fdfind >/dev/null && alias fd='fdfind'

#eval
eval "$(zoxide init --cmd cd zsh)"
eval "$(tv init zsh)"
#variables
unsetopt BEEP
source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh 
source ~/github/somewhere/fzf-tab.plugin.zsh
source $HOME/.config/television/shell/integration.zsh
source ~/github/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
. "$HOME/.local/bin/env"
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

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
export PNPM_HOME="/home/karasu/.local/share/pnpm"
export PATH="$PNPM_HOME:$PATH"
# pnpm
export PNPM_HOME="/home/karasu/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME/bin:"*) ;;
  *) export PATH="$PNPM_HOME/bin:$PATH" ;;
esac
# pnpm end

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
