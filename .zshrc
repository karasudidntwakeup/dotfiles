# Enable colors and change prompt:
nekofetch.sh
autoload -U colors && colors	# Load colors
PS1="%B%{$fg[red]%}[%{$fg[yellow]%}%n%{$fg[red]%}@%{$fg[blue]%}%M %{$fg[magenta]%}%~%{$fg[red]%}]%{$reset_color%}$%b "
setopt autocd		# Automatically cd into typed directory.
autoload -U compinit
zstyle ':completion:*' menu select
zmodload zsh/complist
compinit
stty stop undef		# Disable ctrl-s to freeze terminal.
setopt interactive_comments

# History in cache directory:
HISTSIZE=10000000
SAVEHIST=10000000

#
set encoding=utf-8

#
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh


export ZSH="$HOME/.oh-my-zsh"
export PATH="${PATH}:${HOME}/.cache/wal/colors.sh"
export PATH="${PATH}:${HOME}/.local/bin/"
source $ZSH/oh-my-zsh.sh

alias ls='exa --colour -l --icons'
alias q='tgpt'
alias y='yay -Syyu'
alias nnn='nnn -e'
alias rec=' ffmpeg -f x11grab -i :0.0 -f pulse -i alsa_output.usb-C-Media_Electronics_Inc._USB_Audio_Device-00.analog-stereo.monitor   -ac 2 recording.mkv'
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
#variables


unsetopt BEEP


export OPENAI_API_KEY=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
