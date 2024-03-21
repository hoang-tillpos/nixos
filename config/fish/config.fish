if status is-interactive
    # Commands to run in interactive sessions can go here
end

# fish alias vim for nvim, and oldvim for vim
abbr -a vim nvim
abbr -a oldvim vim



# start up starship for fish
eval (starship init fish)
direnv hook fish | source

