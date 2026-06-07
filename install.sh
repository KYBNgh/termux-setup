#!/data/data/com.termux/files/usr/bin/env bash
# Depends on: bash git stow

set -u

# Default packages to remove
rm_pkgs=(net-tools inetutils nano dos2unix patch)

# Selection set. See add_* functions
# including: (base utils dev virt fun gui multimedia)
use=(base utils)

# apt parameters
# "-y" for no confirmation, "--no-install-recommends" for not install recommend packages
apt_flags="-y "

# Clone one's dotfiles using https 
# HTTP : https://github.com/username/dotfiles.git
# SSH  : git@github.com:username/dotfiles.git
dotfiles_url=""

println() {
    printf "$@\n"
}

err() {
    local red='\033[0;31m'
    local rst='\033[0m'
    println "${red}error${rst}: $*" >&2
}

check_termux() {
    if [[ "$PREFIX" != *termux* ]]; then
        err "not in termux."
        exit 2
    fi
}

ins_pkg() {
    packages+=("$@")
}

set_main_mirror() {

    println
    println "Changing main repository to tuna mirror..."
    println

    sed -i 's@^\(deb.*stable main\)$@#\1\ndeb https://mirrors.tuna.tsinghua.edu.cn/termux/apt/termux-main stable main@' $PREFIX/etc/apt/sources.list
    apt update
}

set_x11_mirror() {

    println
    println "Changing x11-repo repository to tuna mirror..."
    println

    apt install "$apt_flags" x11-repo 
    sed -i 's@^\(deb.*x11 main\)$@#\1\ndeb https://mirrors.tuna.tsinghua.edu.cn/termux/apt/termux-x11 x11 main @' $PREFIX/etc/apt/sources.list.d/x11.list
    apt update
}

force_upgrade() {
    # Force override existing configuration
    yes | apt upgrade

    # Change the mirror back
    set_main_mirror
}

remove_pkgs() {
    println "Removing default packages..."
    println ""
    apt purge "$apt_flags" "${rm_pkgs[@]}"
}

select_packages() {
    packages=()
    
    if [[ " ${use[*]} " =~ " gui " ]]; then
        set_x11_mirror
    fi

    for tag in "${use[@]}"; do
        local func="add_${tag}"

        if declare -f "$func" >/dev/null 2>&1; then
            println "Adding packages set: $tag"
            "$func"
        else
            err "unknown package group: ${tag} (function ${func} not found)"
            exit 1
        fi
    done
}

install_packages() {
    if [ "$apt_flags" = "yes" ]; then
        apt install "$apt_flags" "${packages[@]}"
    else
        apt install "$apt_flags" "${packages[@]}"
    fi
}

cleanup() {
    println
    println "Cleaning up"
    println
    apt autopurge "$apt_flags"
    apt clean
}

deploy_dir() {
    mkdir -v ~/{doc,git}
    ln -svn "$PREFIX"/tmp ~/tmp
    
    termux-setup-storage
    rm -fv "$HOME"/storage/*
    rmdir "$HOME"/storage
    ln -svn /storage/emulated/0/0-core "$HOME"/core
    ln -svn /storage/emulated/0/Download "$HOME"/dls
    
}

deploy_dotfiles() {
    # You may want to change it if your repo is "dotfiles.git"
    local dotfiles_dir="~/git/my_config"
    git clone "$dotfiles_url" "$dotfiles_dir"

    (
        # Another dotfiles repo
        cd "$dotfiles_dir"
        stow -v -t ~ . --adopt

        # This is me!
        cd "$HOME"/git/termux-setup
        stow -v -t /data/data/com.termux termux-bin
        stow -v -t /data/data/com.termux/files/usr/share/bash-completion termux-completions
    )

    termux-reload-settings
}

# Selection sets
add_base() {
    ins_pkg "vim"
    ins_pkg "git"
    ins_pkg "stow"
    ins_pkg "bash-completion"
}

add_utils() {
    ins_pkg "tree"
    ins_pkg "bat"
    ins_pkg "openssh"
    ins_pkg "rsync"
    ins_pkg "lf"
    ins_pkg "ncdu"
    ins_pkg "tmux"
    ins_pkg "fzf"
    ins_pkg "gnupg"
    ins_pkg "termux-api"
}

add_dev() {
  # Too large, comment it out
  # ins_pkg "nodejs"
  # ins_pkg "python"
  # ins_pkg "openjdk-25"
    ins_pkg "build-essential"
    ins_pkg "neovim"
    ins_pkg "yazi"
    ins_pkg "zsh"
    ins_pkg "zsh-completions"
    ins_pkg "starship"
}

add_virt() {
  # Do you want x86_64 ? It is too slow in android
  # ins_pkg "qemu-system-x86_64-headless"
    ins_pkg "qemu-system-aarch64-headless"
    ins_pkg "qemu-utils"
    ins_pkg "proot"
    ins_pkg "proot-distro"
}

add_fun() {
    ins_pkg "fastfetch"
    ins_pkg "fortune"
}

add_gui() {
  # For test, it might need configuration
    ins_pkg "termux-x11-nightly"
    ins_pkg "mesa-vulkan-icd-freedreno"
    ins_pkg "vulkan-loader-android"

    ins_pkg "xorg-xrandr"
    ins_pkg "pulseaudio"
    ins_pkg "xfce4"
    ins_pkg "xfce4-terminal"
    ins_pkg "thunar"
}

add_multimedia() {
    ins_pkg "ffmpeg"
    ins_pkg "yt-dlp"
    ins_pkg "mpv"
}

main() {
    check_termux
    
    remove_pkgs
    
    set_main_mirror
    force_upgrade
    
    select_packages
    install_packages
    
    cleanup
    
    deploy_dir
    deploy_dotfiles
}
main
