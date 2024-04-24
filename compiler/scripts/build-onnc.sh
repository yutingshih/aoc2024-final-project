# build_mode=normal  # for release
# build_mode=dbg     # for debug
# build_mode=rgn     # for regression test
# build_mode=opt     # for optimized

usage() {
cat << EOF
build-onnc.sh <command>

command:
    help            print this help message
    build [mode]    build ONNC compiler; mode = {normal, dbg, rgn, opt} (default: normal)
    remove [mode]   remove ONNC compiler; mode = {normal, dbg, rgn, opt} (default: normal)
    rebuild [mode]  rebuild ONNC compiler; mode = {normal, dbg, rgn, opt} (default: normal)

EOF
}

build() {
    mode=${1:-normal}
    mkdir /onnc/onnc-umbrella/build-$mode
    cd /onnc/onnc-umbrella/build-$mode
    smake -j $(nproc) install
    cd /onnc/onnc-umbrella
    ssync && ./build.cmake.sh $mode
}

remove() {
    mode=${1:-normal}
    rm -rf /onnc/onnc-umbrella/install-$mode
}

rebuild() {
    remove
    build $@
}

case $1 in
    build)
        build
        ;;
    remove)
        remove
        ;;
    rebuild)
        rebuild
        ;;
    help | --help | -h)
        usage
        ;;
    *)
        echo unknown command: $@
        usage
        ;;
esac
