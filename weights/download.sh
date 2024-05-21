parent=$(dirname $0)

download_model() {
    mkdir -p $2 && wget -NP $2 ${1:-./}
}

__download_default() {
    download_model https://github.com/ONNC/onnc-tutorial/blob/master/models/lenet/lenet.onnx $parent/lenet5-fp32
    download_model https://github.com/onnx/models/blob/main/validated/vision/classification/inception_and_googlenet/googlenet/model/googlenet-12.onnx $parent/googlenet-fp32
    download_model https://github.com/onnx/models/blob/main/validated/vision/classification/inception_and_googlenet/googlenet/model/googlenet-12-int8.onnx $parent/googlenet-int8
    download_model https://github.com/onnx/models/blob/main/validated/vision/classification/squeezenet/model/squeezenet1.0-12.onnx $parent/squeezenet-fp32
    download_model https://github.com/onnx/models/blob/main/validated/vision/classification/squeezenet/model/squeezenet1.0-12-int8.onnx $parent/squeezenet-int8
}

if [[ $# -eq 0 ]]; then
    __download_default
else
    download_model $@
fi
