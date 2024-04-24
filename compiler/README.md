# System Software

There is a helper script `run-docker.sh` to help you set up the environment, use the following command to see the usage.

```shell
./run-docker.sh help
```

## Compiler

Start a Docker container for ONNC compiler

```shell
./run-docker.sh onnc
```

```shell
# In ONNC container, build ONNC compiler.
/scripts/build-onnc.sh
```

## Runtime

Start a Docker container for NVDLA virtual platform (VP)

```shell
./run-docker.sh nvvp
```
