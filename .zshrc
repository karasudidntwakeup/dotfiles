# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
PROMPT='%F{red}❯%F{yellow}❯%F{green}❯ %F{white}%~ %f'
export NO_AT_BRIDGE=1
setopt extended_glob
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
 source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi
# Enable colors and change prompt:
setopt COMBINING_CHARS
# custom colors


################ 
my-backward-delete-word () {
    local WORDCHARS='~!#$%^&*(){}[]<>?+;'
    zle backward-delete-word
 }
zle -N my-backward-delete-word
bindkey    '\e^?' my-backward-delete-word
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
zstyle ':fzf-tab:*' fzf-flags \
  --height=80% \
  --layout=reverse \
  --border=rounded \
  --border \
  --info=hidden \
  --info=inline \
  --prompt='❯ ' \
  --pointer='▶ ' \
  --marker='✓ ' \
  --no-separator \
  --height=30%


# History in cache directory:
HISTSIZE=10000000
SAVEHIST=10000000
HISTFILE=~/.zsh_history
HISTDUP=erase
#encoding
set encoding=utf-8
LANG=en_US.UTF-8 
#PATH
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
alias x='dbus-run-session niri'
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
alias lsof='/usr/bin/grc --colour=auto lsof'
alias lspci='/usr/bin/grc --colour=auto lspci'
alias lsblk='/usr/bin/grc --colour=auto lsblk'
alias mount='/usr/bin/grc --colour=auto mount'
alias blkid='/usr/bin/grc --colour=auto blkid'
alias env='/usr/bin/grc --colour=auto env'
alias grep='grep -i --color=auto'
alias rsync='rsync -abrv --suffix='date +%F_%H-%M-%S''    
alias yt='yt-x'
alias ytd='yt-dlp  -f "bestvideo[height<=1080]+bestaudio/best[height<=1080]" --audio-quality 0'
alias ytdm='yt-dlp -f "bestaudio[ext=m4a]","bestaudio[ext=webm]" -x '
alias v='nvim'
alias timer='tclock timer -d 20m -M'
alias lf='yazi'
alias fzf='fzf --preview "bat --color=always   {}"'
alias sxiv-t="imv \$(ls | fzf)"


export LESS_TERMCAP_mb=$'\e[1;32m'     # begin blink
export LESS_TERMCAP_md=$'\e[1;34m'     # begin bold (headings)
export LESS_TERMCAP_me=$'\e[0m'        # reset bold/blink
export LESS_TERMCAP_so=$'\e[01;33m'    # begin standout (status bar)
export LESS_TERMCAP_se=$'\e[0m'        # reset standout
export LESS_TERMCAP_us=$'\e[1;4;31m'   # begin underline
export LESS_TERMCAP_ue=$'\e[0m'        # reset underline
export GROFF_NO_SGR=1                  # needed on some distros (Debian/Ubuntu)
command -v batcat >/dev/null && alias bat='batcat'
export BAT_THEME="Dracula"          # or: TwoDark, gruvbox-dark, Monokai Extended
export BAT_STYLE="numbers,changes,header"

export CLICOLOR=1
export LS_COLORS="$(vivid generate dracula 2>/dev/null)"   # optional, needs 'vivid'
alias ls='ls --color=auto'
alias ll='ls -lah --color=auto'
command -v exa >/dev/null && alias ls='exa --color=auto --icons' && alias ll='exa -lah --color=auto --icons' && alias lt='exa --tree --color=auto --icons'


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
source ~/github/powerlevel10k/powerlevel10k.zsh-theme
source ~/github/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
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
