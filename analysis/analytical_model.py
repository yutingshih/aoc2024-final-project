from dataclasses import dataclass, asdict
import pandas as pd

# config
DATA_SIZE = 1  # Byte
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

    def to_dict(self):
        return {k: str(v) for k, v in asdict(self).items()}


@dataclass
class HardwareParam:
    pe_array_w: int = 14
    pe_array_h: int = 12
    ifmap_spad: int = 12
    filter_spad: int = 224
    psum_spad: int = 24
    global_buffer: int = 100 * 1024

    def to_dict(self):
        return {k: str(v) for k, v in asdict(self).items()}


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

    def to_dict(self):
        return {k: str(v) for k, v in asdict(self).items()}


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
        # tiling
        n = self.convparam.N / self.mapping.n
        c = self.convparam.C / self.ifmap_channel_per_pass
        e = self.convparam.E / self.mapping.e
        return n * c * e

    @property
    def filter_dram_glb_rounds_per_layer(self):
        # tiling 
        m = self.convparam.M / (self.mapping.p * self.mapping.t)
        c = self.convparam.C / self.filter_channel_per_pass
        # repeat
        e = self.convparam.E / self.mapping.e
        n = self.convparam.N / self.mapping.n
        return n * c * m * e

    @property
    def ofmap_dram_glb_rounds_per_layer(self):
        # tiling
        n = self.convparam.N / self.mapping.n
        m = self.convparam.M / self.mapping.m
        e = self.convparam.E / self.mapping.e
        return n * m * e

    # Global buffer - Spad data movement
    @property
    def ifmap_glb_access_per_layer(self):
        # tiling
        n = self.convparam.N / self.mapping.n
        c = self.convparam.C / self.ifmap_channel_per_pass
        e = self.convparam.E / self.mapping.e
        # repeat
        m = self.convparam.M / (self.mapping.p * self.mapping.t) # filter
        return n * c * e * m

    @property
    def filter_glb_access_per_layer(self):
        # tiling 
        m = self.convparam.M / (self.mapping.p * self.mapping.t)
        c = self.convparam.C / self.filter_channel_per_pass
        # repeat
        e = self.convparam.E / self.mapping.e
        n = self.convparam.N / self.mapping.n
        return c * m * e * n 

    @property
    def ofmap_glb_access_per_layer(self):
        # tiling
        n = self.convparam.N / self.mapping.n
        m = self.convparam.M / self.mapping.m
        e = self.convparam.E / self.mapping.e
        # repeat
        c = (self.convparam.C / self.filter_channel_per_pass) * 2 - 1
        return n * m * e * c

    # Time property
    @property
    def dram_access_count_per_layer(self):
        a = self.ifmap_dram_glb_rounds_per_layer * self.glb_ifmap_size_per_pass
        b = self.filter_dram_glb_rounds_per_layer * self.glb_filter_size_per_pass
        c = self.ofmap_dram_glb_rounds_per_layer * self.glb_ofmap_size_per_pass
        return a + b + c

    @property
    def glb_access_count_per_layer(self):
        a = self.ifmap_glb_access_per_layer * self.glb_ifmap_size_per_pass
        b = self.filter_glb_access_per_layer * self.glb_filter_size_per_pass
        c = self.ofmap_glb_access_per_layer * self.glb_ofmap_size_per_pass
        return a + b + c

    # Summary - num of MACs
    @property
    def MACs_per_layer(self):
        pe = self.ifmap_used * self.convparam.F + 1
        pe_set = self.convparam.R * self.convparam.E
        c = self.convparam.C / self.ifmap_channel_per_pass
        return pe * pe_set * c * self.convparam.N * self.convparam.M * self.mapping.r

    # represent
    def __repr__(self) -> str:
        s = f"[Name] {self.name} "
        s += f"[glb_ifmap] {self.glb_ifmap_size_per_pass/1024:5.1f} KiB "
        s += f"[glb_filter] {self.glb_filter_size_per_pass/1024:5.1f} KiB "
        s += f"[glb_ofmap] {self.glb_ofmap_size_per_pass/1024:5.1f} KiB "
        s += f"[glb_total] {self.glb_total_size/1024:5.1f} KiB "
        s += f"[MACs] {self.MACs_per_layer/(10**9):3.2f} G "
        return s

    def test_info(self) -> str:
        s = f"[Name] {self.name} "
        s += f"[glb_ifmap] {self.glb_ifmap_size_per_pass/1024:7.3f} KiB "
        s += f"[glb_filter] {self.glb_filter_size_per_pass/1024:7.3f} KiB "
        s += f"[glb_ofmap] {self.glb_ofmap_size_per_pass/1024:7.3f} KiB "
        s += f"[glb_total] {self.glb_total_size/1024:7.3f} KiB "
        s += f"[MACs] {self.MACs_per_layer/(10**9):5.2f} G "
        s += f"[glb_access] {self.glb_access_count_per_layer/(2**20):7.3f} MB "
        s += f"[dram_access] {self.dram_access_count_per_layer/(2**20):7.3f} MB "
        return s

    def to_list(self):
        return [
            self.name,
            self.glb_ifmap_size_per_pass / 1024,
            self.glb_filter_size_per_pass / 1024,
            self.glb_ofmap_size_per_pass / 1024,
            self.glb_total_size / 1024,
            self.MACs_per_layer / (10**9),
            self.glb_access_count_per_layer / (2**20),
            self.dram_access_count_per_layer / (2**20),
        ]


class Mapper_Conv:
    cnt = 0

    def __init__(
        self,
        name=None,
        convparam=ConvParam(),
        hardwareparam=HardwareParam(),
    ) -> None:
        self.name = name if name is not None else f"mapping_{Mapper_Conv.cnt}"
        self.conv_analyzer = Analyzer_Conv(
            self.name, convparam, hardwareparam, MappingParam()
        )
        Mapper_Conv.cnt += 1

    # Mapping process (Legalize)
    def run_mapping(self):
        # assume n = 1, p = 16
        self.conv_analyzer.mapping.n = 4
        self.conv_analyzer.mapping.p = 16
        # find e, r*t
        m_available_list = range(self.conv_analyzer.mapping.p, self.conv_analyzer.convparam.M+1, self.conv_analyzer.mapping.p)
        m_available_list = [m for m in m_available_list if self.conv_analyzer.convparam.M%m == 0]

        pq_available = (
            self.conv_analyzer.hardwareparam.filter_spad
            // self.conv_analyzer.convparam.S
        )
        q_available = (
            self.conv_analyzer.hardwareparam.ifmap_spad
            // self.conv_analyzer.convparam.S
        )
        q_available = q_available if q_available < pq_available // self.conv_analyzer.mapping.p else pq_available // self.conv_analyzer.mapping.p 
        hw_strips = (
            self.conv_analyzer.hardwareparam.pe_array_h
            // self.conv_analyzer.convparam.R
        )
        e_available = self.conv_analyzer.hardwareparam.pe_array_w * hw_strips
        e_available_list = [
            self.conv_analyzer.hardwareparam.pe_array_w // 2,
        ] + list(range(self.conv_analyzer.hardwareparam.pe_array_w, e_available + 1, self.conv_analyzer.hardwareparam.pe_array_w))
        e_available_list.reverse()

        print("[pq_available] ", pq_available)
        print("[q_available ] ", q_available)
        print("[e_available] ", e_available)
        print("[e_available_list] ", e_available_list)
        print("[m_available_list] ", m_available_list)

        e_valid = False
        possible_solutions = []
        for e in e_available_list:
            if e_valid:
                break
            self.conv_analyzer.mapping.e = e
            if self.conv_analyzer.convparam.E < self.conv_analyzer.mapping.e:
                self.conv_analyzer.mapping.e = self.conv_analyzer.convparam.E
            rt_available = e_available // self.conv_analyzer.mapping.e 
            for m in m_available_list:
                for q in range(1, q_available + 1):
                    for r in range(1, rt_available + 1):
                        t_available = rt_available // r
                        for t in range(1, t_available + 1):
                            self.conv_analyzer.mapping.q = q
                            self.conv_analyzer.mapping.m = m
                            self.conv_analyzer.mapping.r = r
                            self.conv_analyzer.mapping.t = t
                            if (
                                self.conv_analyzer.glb_size_legal
                                and self.conv_analyzer.spad_size_legal
                            ):
                                info = self.conv_analyzer.to_list()
                                mapping_info_dict = self.conv_analyzer.mapping.to_dict()
                                latency = (
                                    self.conv_analyzer.glb_access_count_per_layer
                                    * GLB_ACCESS_TIME
                                    + self.conv_analyzer.dram_access_count_per_layer
                                    * DRAM_ACCESS_TIME
                                )
                                possible_solutions.append(
                                    info
                                    + list(mapping_info_dict.values())
                                    + [
                                        latency,
                                    ]
                                )
                                e_valid = True
        df = pd.DataFrame(
            possible_solutions,
            columns=[
                "Name",
                "GLB ifmap(KiB)",
                "GLB filter(KiB)",
                "GLB psum(KiB)",
                "GLB total(KiB)",
                "MACs (G)",
                "GLB access (MiB)",
                "Dram access (MiB)",
            ]
            + list(mapping_info_dict.keys())
            + [
                "latency",
            ],
        )
        
        df.sort_values(
            "latency", ascending=True, ignore_index=True, inplace=True
        )
        df.sort_values(
            "GLB total(KiB)", ascending=False, ignore_index=True, inplace=True
        )
        df.to_csv("./dump.csv")
        print(df)

    # Generate mapping property
    """
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


def test_mapper():
    batch_size = 4
    conv1 = Mapper_Conv(
        name="Alexnet.conv3",
        convparam=ConvParam(batch_size, 15, 15, 3, 3, 13, 13, 256, 384, 1),
        hardwareparam=HardwareParam(),
    )
    conv1.run_mapping()


def test_analyzer():

    batch_size = 4

    conv1 = Analyzer_Conv(
        name="Alexnet.conv1",
        convparam=ConvParam(batch_size, 227, 227, 11, 11, 55, 55, 3, 96, 4),
        hardwareparam=HardwareParam(),
        mapping=MappingParam(1, 7, 1, 1, 8, 2, 16, 0),
    )

    conv2 = Analyzer_Conv(
        name="Alexnet.conv2",
        convparam=ConvParam(batch_size, 31, 31, 5, 5, 27, 27, 48, 256, 1),
        hardwareparam=HardwareParam(),
        mapping=MappingParam(1, 27, 1, 2, 8, 1, 16, 0),
    )

    conv3 = Analyzer_Conv(
        name="Alexnet.conv3",
        convparam=ConvParam(batch_size, 15, 15, 3, 3, 13, 13, 256, 384, 1),
        hardwareparam=HardwareParam(),
        mapping=MappingParam(4, 13, 1, 4, 8, 4, 16, 0),
    )

    conv4 = Analyzer_Conv(
        name="Alexnet.conv4",
        convparam=ConvParam(batch_size, 15, 15, 3, 3, 13, 13, 192, 384, 1),
        hardwareparam=HardwareParam(),
        mapping=MappingParam(4, 13, 2, 3, 8, 2, 16, 0),
    )

    conv5 = Analyzer_Conv(
        name="Alexnet.conv5",
        convparam=ConvParam(batch_size, 15, 15, 3, 3, 13, 13, 192, 256),
        hardwareparam=HardwareParam(),
        mapping=MappingParam(4, 13, 2, 3, 8, 2, 16, 0),
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
    test_analyzer()
    test_mapper()
