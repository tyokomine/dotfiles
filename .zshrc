# Path to your oh-my-zsh configuration.
ZSH=$HOME/.oh-my-zsh

# Set name of the theme to load.
# Look in ~/.oh-my-zsh/themes/
# Optionally, if you set this to "random", it'll load a random theme each
# time that oh-my-zsh is loaded.
ZSH_THEME="gozilla"

# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

# Set to this to use case-sensitive completion
# CASE_SENSITIVE="true"

# Comment this out to disable weekly auto-update checks
# DISABLE_AUTO_UPDATE="true"

# Uncomment following line if you want to disable colors in ls
# DISABLE_LS_COLORS="true"

# Uncomment following line if you want to disable autosetting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment following line if you want red dots to be displayed while waiting for completion
# COMPLETION_WAITING_DOTS="true"

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
plugins=(git)

source $ZSH/oh-my-zsh.sh

# 全コマンドで correct 機能を無効化
unsetopt correctall
# Customize to your needs...
alias tmux="TERM=xterm-256color tmux -u"
# "v"でデフォルトのviを立ち上げる
alias v="vim -u NONE --noplugin"
alias vi="vim"

case "$OSTYPE" in
	# BSD (contains Mac)
darwin*)
# "o"でopen
alias o="open"
alias be="bundle exec"
export PATH=$PATH:/usr/local/share/npm/bin
export PATH=/usr/local/sbin:$PATH
export GOROOT=/usr/local/Cellar/go/1.1.1
export PATH="$HOME/.exenv/bin:$PATH"
#rbenv setting
eval "$(rbenv init -)"
eval "$(exenv init -)"

export PATH="$HOME/.ndenv/bin:$PATH"
eval "$(ndenv init -)"

# python
export PATH=$HOME/Library/Python/2.7/bin:$PATH
;;
esac

# tmux list-commands | sed -e 's/ .*$//' よりリストを取得している
 _tmux() {
     compadd attach-session bind-key break-pane capture-pane choose-buffer choose-client choose-list choose-session choose-tree choose-window clear-history clock-mode command-prompt confirm-before copy-mode delete-buffer detach-client display-message display-panes find-window has-session if-shell join-pane kill-pane kill-server kill-session kill-window last-pane last-window link-window list-buffers list-clients list-commands list-keys list-panes list-sessions list-windows load-buffer lock-client lock-server lock-session move-pane move-window new-session new-window next-layout next-window paste-buffer pipe-pane previous-layout previous-window refresh-client rename-session rename-window resize-pane respawn-pane respawn-window rotate-window run-shell save-buffer select-layout select-pane select-window send-keys send-prefix server-info set-buffer set-environment set-option set-window-option show-buffer show-environment show-messages show-options show-window-options source-file split-window start-server suspend-client swap-pane swap-window switch-client unbind-key unlink-window
}
compdef _tmux tmux
case "$OSTYPE" in
  linux*)
 	 export PATH=/home/homepage/.nodebrew/current/bin:/usr/local/bin:/bin:/usr/bin:/home/homepage/bin:/usr/local/sbin:/usr/sbin:/sbin:/home/homepage/bin
 	 nodebrew use default
 	 phpbrew use php-5.4.12
	 # ssh-agent zsh
	 # ssh-add ~/.ssh/id_dsa
 	 ;;
esac

# ランダムな色のリンゴマークを出すよ！！
PROMPT=$'%{\e[$[32+$RANDOM % 5]m%}%{$fg_bold[green]%}%p %{$fg[cyan]%}%c %{$fg_bold[blue]%}$(git_prompt_info)%{$fg_bold[blue]%} % %{$reset_color%}'

#バイナリ開いちゃったよ！そんな時はbclear
alias bclear="echo -e '\026\033c'"

#楽ちん検索
function agvim () {
  vim $(ag $@ | peco --query "$LBUFFER" | awk -F : '{print "-c " $2 " " $1}')
}

### s[Enter]でssh
alias s='ssh $(grep -iE "^host[[:space:]]+[^*]" ~/.ssh/config|peco|awk "{print \$2}")'

#### branch絞り込んでcheckout
alias copeco='git checkout `git branch | peco | sed -e "s/\* //g" | awk "{print \$1}"`'
[[ -s /Users/yokominetatsuki/.tmuxinator/scripts/tmuxinator ]] && source /Users/yokominetatsuki/.tmuxinator/scripts/tmuxinator
export EDITOR=/usr/bin/vim
alias pong='perl -nle '\''print "display notification \"$_\" with title \"Terminal\""'\'' | osascript'

function peco-select-history() {
	local tac
	if which tac > /dev/null; then
		tac="tac"
	else
		tac="tail -r"
	fi
	BUFFER=$(\history -n 1 | \
		eval $tac | \
		peco --query "$LBUFFER")
	CURSOR=$#BUFFER
	zle clear-screen
}
zle -N peco-select-history
bindkey '^g' peco-select-history

function cdgem() {
local gem_name=$(bundle list | sed -e 's/^ *\* *//g' | peco | cut -d \  -f 1)
if [ -n "$gem_name" ]; then
	local gem_dir=$(bundle show ${gem_name})
	echo "cd to ${gem_dir}"
	cd ${gem_dir}
fi
}

#
# # The next line updates PATH for the Google Cloud SDK.
# if [ -f /Users/yokominetatsuki/Downloads/google-cloud-sdk/path.zsh.inc ]; then
#   source '/Users/yokominetatsuki/Downloads/google-cloud-sdk/path.zsh.inc'
# fi
#
# # The next line enables shell command completion for gcloud.
# if [ -f /Users/yokominetatsuki/Downloads/google-cloud-sdk/completion.zsh.inc ]; then
#   source '/Users/yokominetatsuki/Downloads/google-cloud-sdk/completion.zsh.inc'
# fi
export PATH="/usr/local/opt/mysql@5.6/bin:$PATH"
export PKG_CONFIG_PATH=/usr/local/Cellar/imagemagick@6/6.9.11-11/lib/pkgconfig