# N: number of ifmaps/ofmaps
# M: number of filters
# H/W: ifmap height/width
# R/S: filter height/width
# E/F: ofmap height/width
# U: stride

# m: ofmap channels in global buffer
# n: number of ifmaps in a pass
# e: ofmap width (PE array width)
# p: number of filters in a pass
# q: (ifmap or filter) channels in a pass
# r: number of PE sets for different (ifmap/filter) channels
# t: number of PE sets for different filters


DATA_SIZE = 2 # Byte
class Mapping:
    cnt = 0

    def __init__(
        self,
        name = None,
        m = 16,
        n = 1,
        e = 7, # 224
        p = 16,
        q = 4,
        r = 1,
        t = 1,
        W = 224,
        H = 224,
        R = 11,
        S = 11,
        E = 55,
        F = 55,
        C = 3,
        M = 96,
    ) -> None:
        self.name = name if name is not None else f"mapping_{Mapping.cnt}"
        self.H = H
        self.W = W
        self.R = R
        self.S = S
        self.E = E
        self.F = F
        self.C = C
        self.M = M

        self.m = m
        self.n = n
        self.e = e
        self.p = p
        self.q = q
        self.r = r
        self.t = t
        Mapping.cnt += 1

    @property
    def ifmap_channel(self):
        return self.q * self.r

    @property
    def glb_ifmap(self):
        return DATA_SIZE * self.n * self.ifmap_channel * self.W * self.H

    @property
    def glb_filter(self):
        return DATA_SIZE * self.n * self.m * self.R * self.S

    @property
    def glb_ofmap(self):
        return DATA_SIZE * self.m * self.e * self.E * self.n

    # for data reuse
    @property
    def glb_total_size(self):
        glb_total = 0
        glb_total += self.glb_ifmap
        glb_total += self.glb_filter
        glb_total += self.glb_ofmap
        return glb_total

    def __repr__(self) -> str:
        s = "[Memory Requirement]\n"
        s += f"[Name]\t{self.name}\n"
        s += "===============================\n"
        s += f"[glb_ifmap]\t {self.glb_ifmap/1024:10.1f} KiB\n"
        s += f"[glb_filter]\t {self.glb_filter/1024:10.1f} KiB\n"
        s += f"[glb_ofmap]\t {self.glb_ofmap/1024:10.1f} KiB\n"
        s += f"[glb_total]\t {self.glb_total_size/1024:10.1f} KiB\n"
        return s

    def test_info(self)->str:
        s = ""
        s += f"[glb_ifmap]\t {self.glb_ifmap/1024:10.1f} KiB "
        s += f"[glb_filter]\t {self.glb_filter/1024:10.1f} KiB "
        s += f"[glb_ofmap]\t {self.glb_ofmap/1024:10.1f} KiB "
        s += f"[glb_total]\t {self.glb_total_size/1024:10.1f} KiB "
        return 0


if __name__ == '__main__':
    conv2 = Mapping(
        name = 'Alexnet.conv2',
        m = 64,
        n = 1,
        e = 27, # 224
        p = 16,
        q = 2,
        r = 1,
        t = 1,
        W = 31,
        H = 31,
        R = 5,
        S = 5,
        E = 27,
        F = 27,
        C = 48,
        M = 256,
    )

    conv3 = Mapping(
        name = 'Alexnet.conv3',
        m = 64,
        n = 4,
        e = 13, # 224
        p = 16,
        q = 4,
        r = 1,
        t = 4,
        W = 15,
        H = 15,
        R = 3,
        S = 3,
        E = 13,
        F = 13,
        C = 256,
        M = 384,
    )

    param = dict(
        m = 64,
        n = 1,
        e = 14, # 224
        p = 16, # psum Spad (filter in PE)
        q = 4, # ifmap/filter channels/pass
        r = 1, # different
        t = 4, # (different filter in PE sets)
        W = 56,
        H = 56,
        R = 3,
        S = 3,
        E = 56,
        F = 56,
        C = 64,
        M = 192,
    )
    m = Mapping(**param)

    print(conv2)
    print(conv3)
    print(m)
