image=yutingshih/aoc-sw:0.2.0
container=pynq-z2

pytorch_dir=mount/pytorch-1.9.1
torchvision_dir=mount/torchvision-0.10.1

build_docker() {
    docker build -t $image -f ./Dockerfile --platform linux/arm/v7 .
}

run_docker() {
    if [[ -z "$(docker ps -a | grep $container)" ]]; then
        docker run -it --name $container --hostname $container -v $PWD/mount:/root/mount --platform linux/arm/v7 $image
    elif [[ -z "$(docker ps | grep $container)" ]]; then
        echo container $container exists but is not running
        docker start -ai $container
    else
        echo container $container is running
        docker attach $container
    fi
}

download_pytorch() {
    dir=${1:-$pytorch_dir}
    [[ -d $dir ]] && {
        echo $dir exists
    } || {
        mkdir -p mount
        git clone https://github.com/pytorch/pytorch $dir
        cd $dir
        git checkout refs/tags/v1.9.1
        git submodule sync
        git submodule update --init --recursive
    }
}

download_torchvision() {
    dir=${1:-$torchvision_dir}
    whl=$dir/torchvision-0.10.0a0%2Bca1a620-cp36-cp36m-linux_armv7l.whl
    [[ -f $whl ]] && {
        echo $whl exists
    } || {
        mkdir -p $dir
        wget -P $dir https://github.com/sterngerlach/pytorch-pynq-builds/blob/master/armv7l-pynq-2.6-torchvision/torchvision-0.10.0a0%2Bca1a620-cp36-cp36m-linux_armv7l.whl
    }
}

try_remove() {
    dir=$1

    printf "removing $dir ... "
    [[ -d $dir ]] || {
	echo not found
    	return 0
    }

    printf "Are you sure? [yes|no] "
    read yes
    [[ $yes == 'yes' ]] && {
        rm -rf $dir
        echo ">> $(tput setaf 1)$dir$(tput sgr0) was removed"
    } || {
        echo ">> $(tput setaf 2)$dir$(tput sgr0) is keeped"
    }
}

remove_pytorch() {
    dir=${1:-$pytorch_dir}
    try_remove $dir
}

remove_torchvision() {
    dir=${1:-$torchvision_dir}
    try_remove $dir
}

help() {
    echo -e "
Usage: $0 COMMAND

Commands:
    build       Build docker image for PYNQ-Z2 FPGA board with PYNQ Linux 2.6.0
    run         Run docker container for PYNQ-Z2 FPGA board with PYNQ Linux 2.6.0
    get         Download source code of non-official porting of PyTorch and Torchvision for PYNQ-Z2
    remove      Remove the PyTorch and Torchvision repositories
    help        Print this help message
    "
}

case $1 in
    build)
        build_docker
        ;;
    run)
        run_docker
        ;;
    get)
        download_pytorch
        download_torchvision
        ;;
    remove)
        remove_pytorch
        remove_torchvision
        ;;
    help)
        help
        ;;
    *)
        echo unknoun command \"$@\"
        help
        ;;
esac
