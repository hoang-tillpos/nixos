# pull config from home
ls ./config/ | xargs -I {} cp -rf ~/.config/{} ./config/
