# Path to your oh-my-zsh configuration.
ZSH=$HOME/.oh-my-zsh

# Set name of the theme to load.
# Look in ~/.oh-my-zsh/themes/
# Optionally, if you set this to "random", it'll load a random theme each
# time that oh-my-zsh is loaded.
ZSH_THEME="skaro"

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

# Customize to your needs...
alias tmux="TERM=xterm-256color tmux -u"
# "v"でデフォルトのviを立ち上げる
alias v="vim -u NONE --noplugin"
alias vi="vim"
# tmux list-commands | sed -e 's/ .*$//' よりリストを取得している
 _tmux() {
     compadd attach-session bind-key break-pane capture-pane choose-buffer choose-client choose-list choose-session choose-tree choose-window clear-history clock-mode command-prompt confirm-before copy-mode delete-buffer detach-client display-message display-panes find-window has-session if-shell join-pane kill-pane kill-server kill-session kill-window last-pane last-window link-window list-buffers list-clients list-commands list-keys list-panes list-sessions list-windows load-buffer lock-client lock-server lock-session move-pane move-window new-session new-window next-layout next-window paste-buffer pipe-pane previous-layout previous-window refresh-client rename-session rename-window resize-pane respawn-pane respawn-window rotate-window run-shell save-buffer select-layout select-pane select-window send-keys send-prefix server-info set-buffer set-environment set-option set-window-option show-buffer show-environment show-messages show-options show-window-options source-file split-window start-server suspend-client swap-pane swap-window switch-client unbind-key unlink-window
     }
     compdef _tmux tmux
