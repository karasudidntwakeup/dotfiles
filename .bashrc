#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '
bind 'set bell-style none'
export PATH="${PATH}:${HOME}/.local/bin/"

source ~/.bash_aliases
