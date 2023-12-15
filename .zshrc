# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
neofetch
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
 source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Enable colors and change prompt:
autoload -U colors && colors	# Load colors


autoload -U up-line-or-beginning-search
autoload -U down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey "^[[A" up-line-or-beginning-search
bindkey "^[[B" down-line-or-beginning-search

##
my-backward-delete-word() {
    local WORDCHARS=${WORDCHARS/\//}
    zle backward-delete-word
}
zle -N my-backward-delete-word
bindkey '^W' my-backward-delete-word

export WORDCHARS='*?_-.[]~&;!#$%^(){}<>'

bindkey "^[[1;5C" forward-word
bindkey "^[[1;5D" backward-word
##

PS1="%B%{$fg[red]%}[%{$fg[yellow]%}%n%{$fg[green]%}@%{$fg[blue]%}%M %{$fg[magenta]%}%~%{$fg[red]%}]%{$reset_color%}$%b "

setopt autocd		# Automatically cd into typed directory.
setopt interactive_comments
zstyle ':completion:*' menu select
# History in cache directory:
HISTSIZE=10000000
SAVEHIST=10000000
HISTFILE=~/.zsh_history



zstyle ':completion:*' matcher-list '' 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'
autoload -Uz compinit && compinit
#
set encoding=utf-8

#
export PATH="${PATH}:${HOME}/.cache/wal/colors.sh"
export PATH="/home/karasu/.cargo/bin:$PATH"
export ZSH="$HOME/.oh-my-zsh"
export PATH="${PATH}:${HOME}/.local/bin/"
#
alias tree='exa --tree'
alias ls='exa --colour -l --icons'
alias q='tgpt'
alias y='yay -Syyu'
alias nnn='nnn -e'
alias rec=' ffmpeg -f x11grab -i :0.0 -f pulse -i alsa_output.usb-C-Media_Electronics_Inc._USB_Audio_Device-00.analog-stereo.monitor   -ac 2 recording.mp4'
alias l.='ls -d .* --color=auto'
alias i='sudo pacman -S'
alias r='sudo pacman -Rnsc'
alias 00='poweroff'
alias 01='reboot'
alias u='sudo pacman -Syyu'
alias x='startx'
alias h='htop'
alias nnn='nnn -r -d -C -e -t 120'
alias c='sudo pacman -Rns $(pacman -Qdtq) && sudo pacman -Sc'
alias youtube='ytfzf'
alias t='telegram-send '
alias l='ls -al'
#variables


unsetopt BEEP

export OPENAI_API_KEY=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
#source /usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme
source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh 
# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

