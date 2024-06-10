from analytical_model import *

from torchinfo import summary
import torch

model = torch.hub.load('pytorch/vision:v0.10.0', 'squeezenet1_0', pretrained=True)
model.eval()

x = summary(model, input_size=(1,3,224,224), col_names = ["input_size", "output_size", "kernel_size", "num_params"], depth=10,verbose = 0) # depth 開10, 挖到最深
x = str(x)
print(x)

x = x.split("\n")
x = [i for i in x if "Conv" in i]
x = [i for i in x if "--" not in i]

def parse(s):
    name = "Conv2d:" + s.split("Conv2d:", maxsplit=1)[1].split("[", maxsplit=1)[0].strip()
    s = s.split("Conv2d:", maxsplit=1)[1].split("[", maxsplit=1)[1]
    ifmap = s.split("]", maxsplit=1)[0].strip()
    ifmap = [int(i) for i in ifmap.split(',')]
    s = s.split("]", maxsplit=1)[1].split("[", maxsplit=1)[1]
    ofmap = s.split("]", maxsplit=1)[0].strip()
    ofmap = [int(i) for i in ofmap.split(',')]
    s = s.split("]", maxsplit=1)[1].split("[", maxsplit=1)[1]
    kernel = s.split("]", maxsplit=1)[0].strip()
    kernel = [int(i) for i in kernel.split(',')]
    return name,ifmap,ofmap,kernel

for i in x:
    print(parse(i))
    
print("[Total Conv2d] ",len(x))
print("--------------------------------------------------------")


from matplotlib import pyplot as plt


glb_total_size = []
glb_ifmap_size = [] 
glb_filter_size = [] 
glb_ofmap_size = [] 
glb_access = []
dram_access = []


for tt,i in enumerate(x):
    name,ifmap,ofmap,kernel = parse(i)
    (N,C,H,W) = ifmap
    (N,M,E,F) = ofmap
    (R,S) = kernel
    U = (W-S)/(F+1)
    if R ==3:
        conv = Analyzer_Conv(
            name=name,
            convparam=ConvParam(1, W, H, R, S, E, F, C, M, U),
            hardwareparam=HardwareParam(),
            mapping=MappingParam(1, 28, 1, 4, 16, 1, 16, 0),
        )
    elif R == 1:
        conv = Analyzer_Conv(
            name=name,
            convparam=ConvParam(1, W, H, R, S, E, F, C, M, U),
            hardwareparam=HardwareParam(),
            mapping=MappingParam(1, 28, 3, 4, 16, 1, 16, 0),
        )
    elif R == 7:
        conv = Analyzer_Conv(
        name=name,
        convparam=ConvParam(1, W, H, R, S, E, F, C, M, U),
        hardwareparam=HardwareParam(),
        mapping=MappingParam(1, 14, 1, 4, 16, 1, 16, 0),
    )
    print(conv.test_info())
    
    
    glb_total_size.append(conv.glb_total_size)
    glb_ifmap_size.append(conv.glb_ifmap_size_per_pass) 
    glb_filter_size.append(conv.glb_filter_size_per_pass) 
    glb_ofmap_size.append(conv.glb_ofmap_size_per_pass) 
    glb_access.append(conv.glb_access_count_per_layer)
    dram_access.append(conv.dram_access_count_per_layer)

def plot_fig(data, name):
    data = [d/1024 for d in data]
    plt.figure()
    plt.title(name.replace("_"," "))
    plt.bar(range(len(data)),data)
    plt.xlabel("Conv2D Layer Index")
    plt.ylabel("Memory Usage (KiB)")
    plt.savefig("./"+name+".png")


plot_fig(glb_total_size, "squeezenet_glb_total_size")
plot_fig(glb_ifmap_size, "squeezenet_glb_ifmap_size")
plot_fig(glb_filter_size, "squeezenet_glb_filter_size")
plot_fig(glb_ofmap_size, "squeezenet_glb_ofmap_size")
plot_fig(glb_access, "squeezenet_glb_access")
plot_fig(dram_access, "squeezenet_dram_access")


plt.figure()
plt.title("GLB access vs DRAM access")
plt.bar(range(len(glb_access)),glb_access,alpha=0.5,label = "GLB access")
plt.bar(range(len(dram_access)),dram_access,alpha=0.5,label = "DRAM access")
plt.xlabel("Conv2D Layer Index")
plt.ylabel("Memory Usage (KiB)")
plt.legend()
plt.savefig("./squeezenet_GLB_access_vs_DRAM_access.png")
