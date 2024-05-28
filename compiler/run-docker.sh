topdir=$(dirname $(realpath $0))/projects
mkdir -p $topdir

try-pull() {
    image=$1
    [[ $(docker images | grep $image) ]] \
    && echo Docker image $image exists \
    || docker pull $image
}

try-clone() {
    repo_url=$1
    repo_dir=$2
    [[ -d $repo_dir ]] \
    && echo Git repository $repo_dir exists \
    || git clone $repo_url $repo_dir
}

usage() {
cat << EOF
run-docker.sh <command>

command:
    help    print this help message
    onnc    run a Docker container for ONNC compiler
    nvvp    run a Docker container for NVDLA virtual platform (VP)

EOF
}

run-onnc () {
    try-pull onnc/onnc-community
    try-clone https://github.com/ONNC/onnc.git $topdir/onnc
    try-clone https://github.com/ONNC/onnc-tutorial.git $topdir/onnc-tutorial
    docker run -ti --rm --cap-add=SYS_PTRACE --hostname=aoc2024 \
        -v $topdir/onnc:/onnc/onnc \
        -v $topdir/onnc-tutorial:/tutorial \
        -v $(pwd)/scripts:/scripts \
        -v $topdir/workspace:/workspace \
        onnc/onnc-community
}

run-nvvp() {
    try-pull onnc/vp
    try-clone https://github.com/ONNC/onnc-tutorial.git $topdir/onnc-tutorial
    docker run -ti --rm --hostname=aoc2024 \
        -v $topdir/onnc-tutorial:/tutorial \
        -v $(pwd)/scripts:/scripts \
        -v $topdir/workspace:/workspace \
        onnc/vp
}

case $1 in
    onnc)
        run-onnc
        ;;
    nvvp)
        run-nvvp
        ;;
    help | --help | -h)
        usage
        ;;
    *)
        echo unknown command: $@
        usage
        ;;
esac
