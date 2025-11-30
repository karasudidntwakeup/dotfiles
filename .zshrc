# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
export NO_AT_BRIDGE=1
setopt extended_glob
#if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
 #source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
#fi
# Enable colors and change prompt:
autoload -U colors && colors	# Load colors
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
autoload -U up-line-or-beginning-search
autoload -U down-line-or-beginning-search
autoload -U compinit; compinit
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
##
#PS1="%B%{$fg[red]%}[%{$fg[yellow]%}%n%{$fg[green]%}@%{$fg[blue]%}%M %{$fg[magenta]%}%~%{$fg[red]%}]%{$reset_color%}   $%b "

#ZSH_THEME="powerlevel10k"
#
setopt autocd		# Automatically cd into typed directory.
setopt interactive_comments
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'eza --color $realpath'
zstyle ':completion:*' menu select
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza --color $realpath'
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
export PATH="$PATH:/sbin:/usr/sbin:usr/local/sbin"
export PATH="${PATH}:${HOME}/.local/bin/"
export PATH="${PATH}:${HOME}/.cargo/bin"
export OLLAMA_NOPRUNE=true
export MANPAGER="sh -c 'col -bx | bat -l man -p'"
#alias
alias gpt='tgpt'
alias z='zathura'
alias tree='eza --tree --icons --sort=newest --color=always'
alias u='sudo pacman -Syyu ; paru -Syyu --noconfirm'
alias i='sudo pacman -S '
alias r='sudo pacman -Rnscu '
alias lta='eza --tree --icons --sort=newest'
alias ls=' eza  --icons --color=always --group-directories-first'
alias l='eza -al --color=always --group-directories-first --sort=newest'
alias sl='eza --icons --sort=newest'
export LESS='-R --use-color -Dd+r$Du+b$'
alias sxiv='nsxiv'
alias 00='sudo poweroff'
alias 01='sudo reboot'
alias x='niri'
alias ip='ip --color=auto'
alias grep='grep -i --color=auto'
alias cat='bat'
alias rsyncex='rsync -avh --no-perms --no-owner --no-group --no-times --progress --partial --inplace --append-verify '
alias rsync='rsync -avh --progress --partial --inplace --append-verify '
alias yt='gophertube'
alias ytd='yt-dlp  -f "bestvideo[height<=1080]+bestaudio/best[height<=1080]" --audio-quality 0'
alias ytdm='yt-dlp -f "bestaudio[ext=m4a]","bestaudio[ext=webm]" -x '
alias v='nvim'
alias timer='tclock timer -d 20m -M'
alias lf='yazi'
alias y='yazi'
alias fzf='fzf --preview="bat --color=always {}"'
alias sxiv='imv'
alias sxiv-t="imv \$(ls | fzf)"


#eval
eval "$(zoxide init --cmd cd zsh)"
eval "$(fzf --zsh)"
#variables
unsetopt BEEP
source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh 
source ~/github/somewhere/fzf-tab.plugin.zsh
# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
#source ~/github/powerlevel10k/powerlevel10k.zsh-theme
source ~/github/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
#[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
## [Completion]
## Completion scripts setup. Remove the following line to uninstall
## [/Completion]
# Start tmux automatically if it's not already running
# # Only run in interactive shells
# if [[ $- == *i* ]]; then
#     if command -v tmux &> /dev/null && [ -z "$TMUX" ]; then
#         tmux attach-session -t default || tmux new-session -s default
#     fi
# fi
 if [ "$TERM" = "linux" ]; then
	printf %b '\e[40m' '\e[8]' # set default background to color 0 'dracula-bg'
	printf %b '\e[37m' '\e[8]' # set default foreground to color 7 'dracula-fg'
	printf %b '\e]P0282a36'    # redefine 'black'          as 'dracula-bg'
	printf %b '\e]P86272a4'    # redefine 'bright-black'   as 'dracula-comment'
	printf %b '\e]P1ff5555'    # redefine 'red'            as 'dracula-red'
	printf %b '\e]P9ff7777'    # redefine 'bright-red'     as '#ff7777'
	printf %b '\e]P250fa7b'    # redefine 'green'          as 'dracula-green'
	printf %b '\e]PA70fa9b'    # redefine 'bright-green'   as '#70fa9b'
	printf %b '\e]P3f1fa8c'    # redefine 'brown'          as 'dracula-yellow'
	printf %b '\e]PBffb86c'    # redefine 'bright-brown'   as 'dracula-orange'
	printf %b '\e]P4bd93f9'    # redefine 'blue'           as 'dracula-purple'
	printf %b '\e]PCcfa9ff'    # redefine 'bright-blue'    as '#cfa9ff'
	printf %b '\e]P5ff79c6'    # redefine 'magenta'        as 'dracula-pink'
	printf %b '\e]PDff88e8'    # redefine 'bright-magenta' as '#ff88e8'
	printf %b '\e]P68be9fd'    # redefine 'cyan'           as 'dracula-cyan'
	printf %b '\e]PE97e2ff'    # redefine 'bright-cyan'    as '#97e2ff'
	printf %b '\e]P7f8f8f2'    # redefine 'white'          as 'dracula-fg'
	printf %b '\e]PFffffff'    # redefine 'bright-white'   as '#ffffff'
	clear
fi
#### ------------------------------


. "$HOME/.local/bin/env"
#source ~/powerlevel10k/powerlevel10k.zsh-theme
# .zshrc
fpath+=($HOME/.zsh/pure)
# Enable Pure prompt
autoload -U promptinit; promptinit
prompt pure

