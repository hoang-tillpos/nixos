if status is-interactive
    # Commands to run in interactive sessions can go here
end

# start up starship for fish
eval (starship init fish)
direnv hook fish | source