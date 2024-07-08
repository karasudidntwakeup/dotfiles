# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
 source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi
# Enable colors and change prompt:
autoload -U colors && colors	# Load colors
local WORDCHARS='*?_[]~=&;!#$%^(){}<>?'
#
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
autoload -U up-line-or-beginning-search
autoload -U down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
##
PS1="%B%{$fg[red]%}[%{$fg[yellow]%}%n%{$fg[green]%}@%{$fg[blue]%}%M %{$fg[magenta]%}%~%{$fg[red]%}]%{$reset_color%}  $%b "
#
setopt autocd		# Automatically cd into typed directory.
setopt interactive_comments
zstyle ':completion:*' menu select
# History in cache directory:
HISTSIZE=10000000
SAVEHIST=10000000
HISTFILE=~/.zsh_history
#
zstyle ':completion:*' matcher-list '' 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'
autoload -Uz compinit && compinit
#
set encoding=utf-8
LANG=en_US.UTF-8 
#
export PATH="$PATH:/sbin:/usr/sbin:usr/local/sbin"
export PATH="${PATH}:${HOME}/.local/bin/"
export PATH="${PATH}:${HOME}/.cargo/bin"
alias u='sudo xbps-install -Su'
alias lta='eza --tree --icons --sort=newest'
alias ls='eza --icons --sort=newest'
alias sl='eza --icons --sort=newest'
alias nnn='nnn -e'
alias rec='ffmpeg -y -f x11grab  -i :0.0  ~/howto/output.mp4'
alias sxiv='nsxiv'
alias l='ls -d .* --color=auto'
alias 00='sudo poweroff'
alias 01='sudo reboot'
alias x='startx'
alias h='htop'
alias nnn='nnn -r -d -C -e -t 120'
alias v='nvim'
alias youtube='youtube -D'
alias ipc='ip -c addr  show'
alias cat='bat -p'
#eval
eval "$(zoxide init zsh)"

#variables
unsetopt BEEP
source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh 
# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
source ~/.p10k.zsh
source ~/powerlevel10k/powerlevel9k.zsh-theme
source /home/karasu/github/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
