#/ push config to home
ls ./config/ | xargs -I {} cp --verbose -rf ./config/{} ~/.config/
