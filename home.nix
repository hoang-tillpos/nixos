{ config, pkgs, ... }:

{
  # TODO please change the username & home directory to your own
  home.username = "hle";
  home.homeDirectory = "/home/hle";

  # link the configuration file in current directory to the specified location in home directory
  # home.file.".config/i3/wallpaper.jpg".source = ./wallpaper.jpg;

  # link all files in `./scripts` to `~/.config/i3/scripts`
  # home.file.".config/i3/scripts" = {
  #   source = ./scripts;
  #   recursive = true;   # link recursively
  #   executable = true;  # make all files executable
  # };

  # encode the file content in nix configuration file directly
  # home.file.".xxx".text = ''
  #     xxx
  # '';

  # set cursor size and dpi for 4k monitor
  #xresources.properties = {
  #  "Xcursor.size" = 16;
  #  "Xft.dpi" = 172;
  #};


  # Packages that should be installed to the user profile.
  home.packages = with pkgs; [
    # os stuff
    appimage-run
    
    # scripting and run-time
    git
    go
    python312
    bun
    direnv
    lazygit
    nodejs
    yarn-berry
    
    
    #dev stuff
    awscli2
    kubectl
    
    #terminals
    fish
    alacritty
    starship
    #bash
    #warp-terminal 
    
    # hyprland stuff
    waybar
    wlogout 
    hyprlock
    hyprshot
    swaynotificationcenter
    swayidle
    pavucontrol
    libnotify
    pamixer
    

    # code editor
    #vscode
    neovim
    postman
    obsidian
    gh
    insomnia
    
    #comms
    slack
    
    #browser
    google-chrome
    
    #
    libreoffice
    calibre
 
    # here is some command line tools I use frequently
    # feel free to add your own or remove some of them

    neofetch
    nnn # terminal file manager

    # archives
    zip
    xz
    unzip
    p7zip

    # utils
    ripgrep # recursively searches directories for a regex pattern
    jq # A lightweight and flexible command-line JSON processor
    yq-go # yaml processer https://github.com/mikefarah/yq
    eza # A modern replacement for ‘ls’
    fzf # A command-line fuzzy finder
    fd # find files for neovim telescope
    unar #the unzip

    # networking tools
    mtr # A network diagnostic tool
    iperf3
    dnsutils  # `dig` + `nslookup`
    ldns # replacement of `dig`, it provide the command `drill`
    aria2 # A lightweight multi-protocol & multi-source command-line download utility
    socat # replacement of openbsd-netcat
    nmap # A utility for network discovery and security auditing
    ipcalc  # it is a calculator for the IPv4/v6 addresses

    # misc
    cowsay
    file
    which
    tree
    gnused
    gnutar
    gawk
    zstd
    gnupg

    # nix related
    #
    # it provides the command `nom` works just like `nix`
    # with more details log output
    nix-output-monitor

    # productivity
    hugo # static site generator
    glow # markdown previewer in terminal

    btop  # replacement of htop/nmon
    iotop # io monitoring
    iftop # network monitoring

    # system call monitoring
    strace # system call monitoring
    ltrace # library call monitoring
    lsof # list open files

    # system tools
    sysstat
    lm_sensors # for `sensors` command
    ethtool
    pciutils # lspci
    usbutils # lsusb
    
    #hyprland stuff
    wofi
    # 
    
  ];

  programs.vscode = {
    enable = true;
    package = pkgs.vscode.fhs;
    profiles.default.extensions = with pkgs.vscode-extensions; [
      golang.go
      dbaeumer.vscode-eslint
      esbenp.prettier-vscode
      bierner.markdown-mermaid
      yzhang.markdown-all-in-one
      sumneko.lua
      ms-pyright.pyright
      ms-python.vscode-pylance
      ms-python.black-formatter
      njpwerner.autodocstring
      skyapps.fish-vscode
      mads-hartmann.bash-ide-vscode
      davidanson.vscode-markdownlint
      graphql.vscode-graphql-syntax
      redhat.vscode-yaml
      bbenoist.nix
      wholroyd.jinja
      github.github-vscode-theme
    ] ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [
     {
        name = "codeium";
        publisher = "Codeium";
        version = "1.14.1";
        sha256 = "sha256-aUEXL6JNpOncqdDyReaG7C7+mmNPC+mDuAsBeabTLeE=";
     }
    ];

  };

  #configuring xsession + i3
  #xsession = {
   # enable = true;
    #windowManager.command = "i3";
  #};
  

  # basic configuration of git, please change to your own
  #programs.git = {
  #  enable = true;
  #  userName = "Hoang Le";
  #  userEmail = "hoang.b.le.au@gmail.com";
  #};

  # starship - an customizable prompt for any shell
  #programs.starship = {
  #  enable = true;
  #  # custom settings
  #  settings = {
  #    add_newline = false;
  #    aws.disabled = true;
  #    gcloud.disabled = true;
  #    line_break.disabled = true;
  #  };
  #};

  # alacritty - a cross-platform, GPU-accelerated terminal emulator
  #programs.alacritty = {
  #  enable = true;
  #  # custom settings
  #  settings = {
  #    env.TERM = "xterm-256color";
  #    font = {
  #      size = 12;
  #      #draw_bold_text_with_bright_colors = true;
  #    };
  #    scrolling.multiplier = 5;
  #    selection.save_to_clipboard = true;
  #  };
  #};

  #programs.bash = {
    #enable = true;
    #enableCompletion = true;
    # TODO add your custom bashrc here
    #bashrcExtra = ''
    #  export PATH="$PATH:$HOME/bin:$HOME/.local/bin:$HOME/go/bin"
    #'';

    # set some aliases, feel free to add more or remove some
    #shellAliases = {
    #  #k = "kubectl";
    #  urldecode = "python3 -c 'import sys, urllib.parse as ul; print(ul.unquote_plus(sys.stdin.read()))'";
    #  urlencode = "python3 -c 'import sys, urllib.parse as ul; print(ul.quote_plus(sys.stdin.read()))'";
    #};
  #};

  # This value determines the home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update home Manager without changing this value. See
  # the home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "23.11";

  # Let home Manager install and manage itself.
  programs.home-manager.enable = true;
}
