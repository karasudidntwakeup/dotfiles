# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
 source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi
# Enable colors and change prompt:
autoload -U colors && colors	# Load colors
local WORDCHARS='*?_[]~=&;!#$%^(){}<>?'
# Make zsh autocomplete with up arrow
autoload -Uz history-search-end
zle -N history-beginning-search-backward-end history-search-end
zle -N history-beginning-search-forward-end history-search-end
bindkey "$terminfo[kcuu1]" history-beginning-search-backward-end
bindkey "$terminfo[kcud1]" history-beginning-search-forward-end
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
PS1="%B%{$fg[red]%}[%{$fg[yellow]%}%n%{$fg[green]%}@%{$fg[blue]%}%M %{$fg[magenta]%}%~%{$fg[red]%}]%{$reset_color%} $%b "
#
setopt autocd		# Automatically cd into typed directory.
setopt interactive_comments
zstyle ':completion:*' menu select
# History in cache directory:
HISTSIZE=10000000
SAVEHIST=10000000
HISTFILE=~/.zsh_history
#Completion
zstyle ':completion:*' matcher-list '' 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'
autoload -Uz compinit && compinit
#Encoding
set encoding=utf-8
LANG=en_US.UTF-8 
#Pathes
export PATH="$PATH:/sbin:/usr/sbin:usr/local/sbin"
export PATH="${PATH}:${HOME}/.local/bin/"
export PATH="${PATH}:${HOME}/.cargo/bin"
#Aliases
alias sudo='doas'
alias ll='exa --tree --icons --sort=newest'
alias ls='exa --icons --sort=newest'
alias la='ls -al'
alias nnn='nnn -e'
alias rec='ffmpeg -y -f x11grab  -i :0.0  ~/howto/output.mp4'
alias sxiv='nsxiv'
alias l='ls -d .* --color=auto'
alias 00=' poweroff'
alias 01=' reboot'
alias x='startx'
alias h='htop'
alias nnn='nnn -r -d -C -e -t 120'
alias v='nvim'
alias vim='nvim'
alias youtube='ytfzf -D'
#variables
unsetopt BEEP
# Extentions
source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh 
source /home/karasu/github/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
source ~/.p10k.zsh
source ~/powerlevel10k/powerlevel10k.zsh-theme
