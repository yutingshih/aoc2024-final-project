


# Quantize Onnx Model

## 1. Environment
[Neural-Compressor](https://github.com/intel/neural-compressor) 

An open-source Python library supporting popular model compression techniques on all mainstream deep learning frameworks (TensorFlow, PyTorch, ONNX Runtime, and MXNet)



    git clone https://github.com/intel/neural-compressor.git

    <!-- squeenet -->
    cd neural-compressor/examples/onnxrt/image_recognition/onnx_model_zoo/squeezenet/quantization/ptq_static
    <!-- googlenet -->
    cd neural-compressor/examples/onnxrt/image_recognition/onnx_model_zoo/googlenet/quantization/ptq_static

    pip install neural-compressor
    pip install -r requirements.txt

## 2. Prepare Model
Using SqueezeNet as an example:

    python prepare_model.py --output_model='squeezenet1.0-12.onnx'


## 3. Prepare Dataset

    Download dataset [ILSVR2012 validation Imagenet dataset](http://www.image-net.org/challenges/LSVRC/2012).

    Download label:

    wget http://dl.caffe.berkeleyvision.org/caffe_ilsvrc12.tar.gz
    tar -xvzf caffe_ilsvrc12.tar.gz val.txt


## 4. Run Quantization

-  Quantization Setting
    - [Class PostTrainingQuantConfig](https://github.com/intel/neural-compressor/blob/7120dd4909599b228692415732688b3d5e77206d/neural_compressor/config.py#L1202)
    - [Quantization md](https://github.com/intel/neural-compressor/blob/master/docs/source/quantization.md)
    
    Config.json
    ```
    //op_type_dict: Tuning constraints on optype-wise  for advance user to reduce tuning space.
    //User can specify the quantization config by op type:
    {
        "Conv": {
            "weight": {
                "dtype": [
                    "int8"
                ],
                "scheme": [
                    "sym"
                ],
                "granularity": [
                    "per_channel"
                ]
            },
            "activation": {
                "dtype": [
                    "int8"
                ],
                "scheme": [
                    "sym"
                ],
                "granularity": [
                    "per_tensor"
                ]
            }
        },
        "Linear": {
            "weight": {
                "dtype": [
                    "int8"
                ],
                "scheme": [
                    "sym"
                ],
                "granularity": [
                    "per_channel"
                ]
            },
            "activation": {
                "dtype": [
                    "int8"
                ],
                "scheme": [
                    "sym"
                ],
                "granularity": [
                    "per_tensor"
                ]
            }
        }
    }

    ```

    Modify main.py to read the quantization settings from Config.json:

    ```python=
    from neural_compressor import quantization, PostTrainingQuantConfig
    import json
    with open('config.json', 'r') as f:
        op_name_dict = json.load(f)

    config = PostTrainingQuantConfig(quant_format=args.quant_format, op_name_dict=op_name_dict)

    q_model = quantization.fit(model, config, calib_dataloader=dataloader,
             eval_func=eval)

    q_model.save(args.output_model)
    ```


    Quantize model with QLinearOps:

    ```bash=
    bash run_quant.sh --input_model=path/to/model \  # model path as *.onnx
                       --dataset_location=/path/to/imagenet \
                       --label_path=/path/to/val.txt \
                       --output_model=path/to/save
    ```