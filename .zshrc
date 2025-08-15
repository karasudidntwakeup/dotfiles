# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
 source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi
# Enable colors and change prompt:
autoload -U colors && colors	# Load colors
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
PS1="%B%{$fg[red]%}[%{$fg[yellow]%}%n%{$fg[green]%}@%{$fg[blue]%}%M %{$fg[magenta]%}%~%{$fg[red]%}]%{$reset_color%}   $%b "

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
alias u='sudo pacman -Syyu'
alias yu='yay -Syyu'
alias lta='eza --tree --icons --sort=newest'
alias ls=' eza -l --icons --color=always --group-directories-first'
alias l='eza -al --color=always --group-directories-first'
alias sl='eza --icons --sort=newest'
export LESS='-R --use-color -Dd+r$Du+b$'
alias rec='ffmpeg -f x11grab -r  -i :0.0 -f pulse -i alsa_output.usb-C-Media_Electronics_Inc._USB_Audio_Device-00.analog-stereo.monitor  -ac 2 recording.mp4'
alias sxiv='nsxiv'
alias 00='sudo poweroff'
alias 01='sudo reboot'
alias x='startx'
alias h='hyprland'
alias ip='ip --color=auto'
alias grep='grep -i --color=auto'
alias cat='bat'
alias xbacklight='sudo xbacklight'
alias rsync='rsync -rPavh'
alias yt='yt-dlp  -f "bestvideo[height<=1080]+bestaudio/best[height<=1080]" --audio-quality 0'
alias v='nvim'
alias timer='tclock timer -d 20m -M'
alias lf='yazi'
alias fzf='fzf --preview="bat --color=always {}"'

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
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
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
