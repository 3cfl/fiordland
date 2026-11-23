[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '

[[ -r /usr/share/fiordland/bashrc ]] && . /usr/share/fiordland/bashrc
