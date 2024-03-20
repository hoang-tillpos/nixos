# remove all configs and create symlinks instead
#
ls ./config/ | xargs -I {} bash --verbose -c "rm --verbose -rf ~/.config/{} && ln --verbose -s $(pwd)/config/{} ~/.config/{}"
