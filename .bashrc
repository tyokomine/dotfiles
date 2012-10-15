# .bashrc

# User specific aliases and functions

alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
alias vi='/usr/bin/vim'

# Source global definitions
if [ -f /etc/bashrc ]; then
	. /etc/bashrc
fi

source /usr/local/rvm/scripts/rvm
export GEM_HOME=/usr/local/lib/ruby/gems/
