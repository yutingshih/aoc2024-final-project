from dataclasses import dataclass

# config
DATA_SIZE = 2  # Byte
BUS_BANDWIDTH = 4  # Byte

SPAD_ACCESS_TIME = 1
GLB_ACCESS_TIME = 6 * SPAD_ACCESS_TIME
DRAM_ACCESS_TIME = 200 * SPAD_ACCESS_TIME
print(f"Using DATA_SIZE = {DATA_SIZE}")

######################################################################################################
# N: number of ifmaps/ofmaps
# M: number of filters
# H/W: ifmap height/width
# R/S: filter height/width
# E/F: ofmap height/width
# U: stride
#  ----------------------------------------------------------------------------------------------
# m: ofmap channels in global buffer
# n: number of ifmaps in a pass
# e: width of PE-set
# p: number of filters in a pass
# q: (ifmap or filter) channels in a pass
# r: number of PE sets for different (ifmap/filter) channels
# t: number of PE sets for different filters
#  ----------------------------------------------------------------------------------------------
#  Naming Convention
# *_per_pass: compute / storage size required per pass
# *_per_layer: compute / storage size required per layer
# *_per_glb: compute / storage size required per global buffer load
######################################################################################################


@dataclass
class ConvParam:
    N: int = 1  # number of ifmaps
    W: int = 224  # ifmap W
    H: int = 224  # ifmap H
    R: int = 11  # filter W
    S: int = 11  # filter H
    E: int = 55  # ofmap W
    F: int = 55  # ofmap H
    C: int = 3  # input(ifmap) channel
    M: int = 96  # output(ofmap) channel / num of filter
    U: int = 1  # stride


@dataclass
class HardwareParam:
    pe_array_w: int = 14
    pe_array_h: int = 12
    ifmap_spad: int = 12
    filter_spad: int = 224
    psum_spad: int = 24
    global_buffer: int = 0


@dataclass
class MappingParam:
    n: int = 1  # number of ifmaps in a pass
    e: int = 7  # width of PE-set

    r: int = 1  # number of PE sets for different (ifmap/filter) channels
    q: int = 4  # ifmap/filter channel in a pass

    p: int = 16  # number of filters in a pass
    t: int = 1  # number of PE sets for different filters
    m: int = 96  # ofmap channels in global buffer

    rt: int = 0  # r * t (intermediate value in the mapping optimization procedure)


class Analyzer_Conv:
    cnt = 0

    def __init__(
        self,
        name=None,
        convparam=ConvParam(),
        hardwareparam=HardwareParam(),
        mapping=MappingParam(),
    ) -> None:
        self.name = name if name is not None else f"mapping_{Analyzer_Conv.cnt}"
        self.convparam = convparam
        self.hardwareparam = hardwareparam
        self.mapping = mapping
        Analyzer_Conv.cnt += 1

    # --------------------------------------------------------------
    # Space property - Scratch pad
    @property
    def filter_used(self):
        return self.mapping.q * self.convparam.S * self.mapping.p

    @property
    def ifmap_used(self):
        return self.mapping.q * self.convparam.S

    @property
    def psum_used(self):
        return self.mapping.p

    # Memory property - Global Buffer Size
    @property
    def filter_channel_per_pass(self):
        return self.mapping.q * self.mapping.r

    @property
    def ifmap_channel_per_pass(self):
        return self.mapping.q * self.mapping.r

    @property
    def glb_ifmap_size_per_pass(self):
        return (
            DATA_SIZE
            * self.mapping.n
            * self.ifmap_channel_per_pass
            * ((self.mapping.e - 1) * self.convparam.U + self.convparam.R)
            * self.convparam.W
        )

    @property
    def glb_filter_size_per_pass(self):
        return (
            DATA_SIZE
            * (self.mapping.p * self.mapping.t)
            * self.filter_channel_per_pass
            * self.convparam.R
            * self.convparam.S
        )

    @property
    def glb_ofmap_size_per_pass(self):
        return (
            DATA_SIZE
            * self.mapping.n
            * self.mapping.m
            * self.mapping.e
            * self.convparam.F
        )

    # Summary - space
    @property
    def glb_total_size(self):
        glb_total = 0
        glb_total += self.glb_ifmap_size_per_pass
        glb_total += self.glb_filter_size_per_pass
        glb_total += self.glb_ofmap_size_per_pass
        return glb_total

    @property
    def glb_size_legal(self):
        return self.glb_total_size <= self.hardwareparam.global_buffer

    @property
    def spad_size_legal(self):
        return {
            "ifmap": self.ifmap_used <= self.hardwareparam.ifmap_spad,
            "filter": self.filter_used <= self.hardwareparam.filter_spad,
            "psum": self.psum_used <= self.hardwareparam.psum_spad,
        }

    # --------------------------------------------------------------
    # DRAM - Global buffer data movement
    @property
    def ifmap_dram_glb_rounds_per_layer(self):
        c = (self.convparam.C - 1) // self.ifmap_channel_per_pass + 1
        h = (self.convparam.E - 1) // self.mapping.e + 1
        return c * h

    @property
    def filter_dram_glb_rounds_per_layer(self):
        c = (self.convparam.C - 1) // self.filter_channel_per_pass + 1
        n = (self.convparam.M - 1) // (self.mapping.p * self.mapping.t) + 1
        return c * n

    @property
    def ofmap_dram_glb_rounds_per_layer(self):
        c = (self.convparam.M - 1) // self.mapping.m + 1
        h = (self.convparam.E - 1) // self.mapping.e + 1
        return c * h

    # Global buffer - Spad data movement
    @property
    def ifmap_passes_per_glb(self):
        return 1

    @property
    def filter_passes_per_glb(self):
        return 1

    @property
    def ofmap_passes_per_glb(self):
        return 1

    # Time property
    @property
    def dram_access_count_per_layer(self):
        t = self.ifmap_dram_glb_rounds_per_layer * self.glb_ifmap_size_per_pass
        t += self.filter_dram_glb_rounds_per_layer * self.glb_filter_size_per_pass
        t += self.ofmap_dram_glb_rounds_per_layer * self.glb_ofmap_size_per_pass
        return t * DATA_SIZE

    @property
    def glb_access_count_per_layer(self):
        t = (
            self.ifmap_dram_glb_rounds_per_layer * self.glb_ifmap_size_per_pass
        )  # move multi-channel in once
        t += self.filter_dram_glb_rounds_per_layer * self.glb_filter_size_per_pass
        t += self.ofmap_dram_glb_rounds_per_layer * self.glb_ofmap_size_per_pass
        return t * DATA_SIZE

    # Summary - time
    @property
    def memory_access_time(self):
        # origin
        t0 = (
            self.convparam.N
            * (self.convparam.R * self.convparam.S * self.convparam.C)
            * self.convparam.E
            * self.convparam.F
            * self.convparam.M
            * 2
        )  # read filter & ifmap
        t0 += (
            self.convparam.N * self.convparam.E * self.convparam.F * self.convparam.M
        )  # write ofmap
        t0 = t0 * DATA_SIZE / BUS_BANDWIDTH * DRAM_ACCESS_TIME
        # this architecture
        t1 = self.dram_access_count_per_layer + self.glb_access_count_per_layer
        return (t0, t1, t1 / t0)  # ratio

    # represent
    def __repr__(self) -> str:
        s = "[Memory Requirement]\n"
        s += f"[Name]\t{self.name}\n"
        s += "===============================\n"
        s += f"[glb_ifmap]\t {self.glb_ifmap_size_per_pass/1024:10.1f} KiB\n"
        s += f"[glb_filter]\t {self.glb_filter_size_per_pass/1024:10.1f} KiB\n"
        s += f"[glb_ofmap]\t {self.glb_ofmap_size_per_pass/1024:10.1f} KiB\n"
        s += f"[glb_total]\t {self.glb_total_size/1024:10.1f} KiB\n"
        return s

    def test_info(self) -> str:
        s = f"[Name]\t{self.name}\t"
        s += f"[glb_ifmap]\t {self.glb_ifmap_size_per_pass/1024:10.1f} KiB "
        s += f"[glb_filter]\t {self.glb_filter_size_per_pass/1024:10.1f} KiB "
        s += f"[glb_ofmap]\t {self.glb_ofmap_size_per_pass/1024:10.1f} KiB "
        s += f"[glb_total]\t {self.glb_total_size/1024:10.1f} KiB "
        s += f"[glb_access]\t {self.glb_access_count_per_layer/(2**20):5.1f} MB "
        s += f"[dram_access]\t {self.dram_access_count_per_layer/(2**20):5.1f} MB "
        return s


"""
class Mapper_Conv:
    cnt = 0

    def __init__(
        self,
        name=None,
        convparam=ConvParam(),
        hardwareparam=HardwareParam(),
    ) -> None:
        self.name = name if name is not None else f"mapping_{Mapper_Conv.cnt}"
        self.convparam = Analyzer_Conv(
            self.name, convparam, hardwareparam, MappingParam()
        )
        Mapper_Conv.cnt += 1

    # Mapping process (Legalize)
    def run_mapping(self):
        # assume n = 1
        self.mapping.n = 1
        # find e, r*t
        hw_strips = self.hardwareparam.pe_array_h // self.convparam.R
        self.mapping.e = self.hardwareparam.pe_array_w * hw_strips
        if self.convparam.E < self.mapping.e:
            rt_avaiable = self.mapping.e // self.convparam.E
            self.mapping.e = self.convparam.E

        # find p*q
        # filter_spad size > S*p(filters)*q(channels)
        # ifmap_spad size > S*q(channels)
        pq_avaiable = self.hardwareparam.filter_spad // self.convparam.S
        q_avaiable = self.hardwareparam.filter_spad // self.convparam.S

        # find

    # Generate mapping property
    def gen_mapping(self):
        pe_set_mapping_ = [
            (self.convparam.R, self.mapping.e),
        ] * (self.convparam.E // self.mapping.e)
        r = self.convparam.E % self.mapping.e
        if r != 0:
            pe_set_mapping_.append((self.convparam.R, r))

        w = self.hardwareparam.pe_array_w
        pe_set_mapping = []
        for R, e in pe_set_mapping_:
            x = [
                (R, w),
            ] * (e // w)
            r = e % w
            if r != 0:
                x.append((R, r))
            pe_set_mapping.append(x)

        for i in pe_set_mapping:
            print(i)
"""


def test():
   
    conv1 = Analyzer_Conv(
        name="Alexnet.conv1",
        convparam=ConvParam(1, 227, 227, 11, 11, 55, 55, 3, 96, 4),
        hardwareparam=HardwareParam(),
        mapping=MappingParam(1, 7, 1, 1, 16, 2, 96, 0),
    )

    conv2 = Analyzer_Conv(
        name="Alexnet.conv2",
        convparam=ConvParam(1, 31, 31, 5, 5, 27, 27, 48, 256, 1),
        hardwareparam=HardwareParam(),
        mapping=MappingParam(1, 27, 1, 2, 16, 1, 64, 0),
    )

    conv3 = Analyzer_Conv(
        name="Alexnet.conv3",
        convparam=ConvParam(1, 15, 15, 3, 3, 13, 13, 256, 384, 1),
        hardwareparam=HardwareParam(),
        mapping=MappingParam(4, 13, 1, 4, 16, 4, 64, 0),
    )

    conv4 = Analyzer_Conv(
        name="Alexnet.conv4",
        convparam=ConvParam(1, 15, 15, 3, 3, 13, 13, 192, 384, 1),
        hardwareparam=HardwareParam(),
        mapping=MappingParam(4, 13, 2, 3, 16, 2, 64, 0),
    )

    conv5 = Analyzer_Conv(
        name="Alexnet.conv5",
        convparam=ConvParam(1, 15, 15, 3, 3, 13, 13, 192, 256),
        hardwareparam=HardwareParam(),
        mapping=MappingParam(4, 13, 2, 3, 16, 2, 64, 0),
    )

    # print(conv1)
    # print(conv2)
    # print(conv3)

    print(conv1.test_info())
    print(conv2.test_info())
    print(conv3.test_info())
    print(conv4.test_info())
    print(conv5.test_info())


if __name__ == "__main__":
    test()
