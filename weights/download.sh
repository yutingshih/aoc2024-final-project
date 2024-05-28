parent=$(dirname $0)
onnx_model_zoo=https://github.com/onnx/models/raw/main/validated

download_model() {
    mkdir -p $2 && wget -NP $2 ${1:-./}
}

__download_default() {
    download_model https://github.com/ONNC/onnc-tutorial/raw/master/models/lenet/lenet.onnx $parent/lenet5-fp32
    download_model $onnx_model_zoo/vision/classification/inception_and_googlenet/googlenet/model/googlenet-9.onnx $parent/googlenet-fp32
    download_model $onnx_model_zoo/vision/classification/squeezenet/model/squeezenet1.0-9.onnx $parent/squeezenet-fp32
}

if [[ $# -eq 0 ]]; then
    __download_default
else
    download_model $@
fi
