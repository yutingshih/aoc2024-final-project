dir=~/mount/pytorch-1.9.1
if [[ ! -d $dir ]]; then
    ../docker.sh get
fi
cd $dir
pip3 install -r requirements.txt

export CFLAGS="-mfpu=neon -D__NEON__"
export USE_CUDA=0
export USE_CUDNN=0
export BUILD_TEST=0
export USE_MKLDNN=0
export USE_DISTRIBUTED=0

sudo apt update
sudo apt install -y ninja-build

python3 setup.py build
python3 setup.py bdist_wheel

wheel=dist/torch-1.9.0a0+gitdfbd030-cp36-cp36m-linux_armv7l.whl
if [[ -f $wheel ]]; then
    echo $wheel successfully built
else
    echo $wheel build failed
fi
