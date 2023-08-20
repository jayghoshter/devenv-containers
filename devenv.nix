# Standard devenv container with utils to support nvim and tmux. This was an
# experiment in understanding nix and pkgs.dockerTools, as well as the sort of
# dependencies I have baked in to my default tools. It's a bit bloated at 1.23GB
# image size, but that's the nature of nixpkgs. Further trimming would require
# package overrides to remove unnecessary/optional dependencies.

# Build and load it using `$(nix-build devenv.nix) | docker load`
# Run container with
#   `docker run -it devenv:latest`                            # zinit
#   `docker run -it -e LOAD_ZINIT=false devenv:bare`          # No zinit
#   `docker run -it /bin/nvim`                                # nvim

# dotfiles git SHA256 can be obtained with
# `nix-prefetch-url --unpack --print-path https://github.com/jayghoshter/dotfiles/archive/refs/heads/master.zip`

# TODO: Check out flakes for this

{ pkgs ? import <nixpkgs> { }
, pkgsLinux ? import <nixpkgs> { system = "x86_64-linux"; }
}:

let

  dots = pkgs.stdenv.mkDerivation {
    name = "dots";
    version = "0.1";

    # NOTE: For cache effects set nix.conf option `tarball-ttl = 0`
    src = builtins.fetchGit {
      url = "https://github.com/jayghoshter/dotfiles";
      ref = "master";
    };

    dontConfigure = true;
    dontBuild = true;
    # dontInstall = true;
    dontFixup = true;

    # HACK: dumps my dotfiles into /dots
    # We later copy and chown+chmod files to have rw access.
    installPhase = ''
      mkdir -p $out/dots
      cp -r . $out/dots
    '';

  };

  tpm = pkgs.stdenv.mkDerivation{
    name = "tpm";
    version = "0.1";

    src = builtins.fetchGit {
      url = "https://github.com/tmux-plugins/tpm";
      ref = "master";
    };

    installPhase = ''
      mkdir -p $out/home/user/.tmux/plugins/tpm
      cp -r . $out/home/user/.tmux/plugins/tpm
    '';
  };

  zinit-preload = pkgs.stdenv.mkDerivation {
    # Preload some of the zinit plugins I use to save time at runtime

    name = "zinit-preload";
    version = "0.1";

    srcs = [
      (builtins.fetchGit {
        name = "zinit";
        url="https://github.com/zdharma-continuum/zinit";
        ref = "main";
      })
      (builtins.fetchGit{
        name = "sindresorhus---pure";
        url = "https://github.com/sindresorhus/pure";
        ref = "main";
      })
      (builtins.fetchGit{
        name = "Aloxaf---fzf-tab";
        url = "https://github.com/Aloxaf/fzf-tab";
        ref = "master";
      })
      (builtins.fetchGit{
        name = "zdharma-continuum---fast-syntax-highlighting";
        url = "https://github.com/zdharma-continuum/fast-syntax-highlighting";
        ref = "master";
      })
      (builtins.fetchGit{
        name = "zsh-users---zsh-completions";
        url = "https://github.com/zsh-users/zsh-completions";
        ref = "master";
      })
      (builtins.fetchGit{
        name = "zsh-users---zsh-autosuggestions";
        url = "https://github.com/zsh-users/zsh-autosuggestions";
        ref = "master";
      })
    ];

    sourceRoot = "zinit";

    installPhase = ''
      mkdir -p $out/home/user/.zinit/bin
      cp -r . $out/home/user/.zinit/bin
      shopt -s dotglob
      mkdir -p $out/home/user/.zinit/plugins
      cp -r ../* $out/home/user/.zinit/plugins
    '';

  };

in pkgs.dockerTools.streamLayeredImage rec {
  name = "devenv";
  tag = "latest";
  created = "now";

  contents = with pkgs; [
    bashInteractive
    btop
    bzip2
    cacert
    cmake
    coreutils
    curl
    dockerTools.binSh
    dockerTools.usrBinEnv
    dots
    fd
    file
    fzf
    gawk
    gcc
    gh
    git
    gnugrep
    gnumake
    gnused
    gnutar
    gzip
    iconv
    lazygit
    moreutils
    neovim
    nnn
    openssl
    ripgrep
    tmux
    tpm
    tzdata
    unzip
    xclip
    zsh
    zinit-preload
    ncdu
  ];

  fakeRootCommands = ''
      # Hack to get dotfiles to work
      # Copy contents of dots into home and modify permissions
      mkdir -p ./home/user
      shopt -s dotglob
      cp -rL ${dots}/dots/* ./home/user
      chown --recursive 1000:1000 ./home/user
      chmod --recursive u+rw ./home/user

      # /tmp is needed by some programs
      mkdir -p ./tmp
      chmod 777 ./tmp
  '';

  config = {
    User = "1000:1000";
    Entrypoint = [ "${pkgs.zsh}/bin/zsh" ];
    # Cmd = [ "-h" ];
    WorkingDir = "/home/user";
    Env = [
      "TZ=Europe/Berlin"
      "TZDIR=/share/zoneinfo"
      "TERM=xterm-256color"
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      "HOME=/home/user"
      "SHELL=${pkgs.zsh}/bin/zsh"
      "PURE_PROMPT_SYMBOL=❯❯"
      "PURE_PROMPT_VICMD_SYMBOL=❮❮"
      # "LOAD_ZINIT=false"
    ];
  };
}
