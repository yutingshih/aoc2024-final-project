class PE(object):
    def __init__(self,
                 IFMAP_SPAD_SIZE = 12,
                FILTER_SPAD_SIZE = 224,
                PSUM_SPAD_SIZE = 24,
                IFMAP_NUM = 1,
                FILTER_NUM = 4,
                IPSUM_NUM = 1,
                OPSUM_NUM = 1,
                MA_X = 0,
                MA_Y = 0) -> None:
        self.IFMAP_SPAD_SIZE = IFMAP_SPAD_SIZE
        self.FILTER_SPAD_SIZE = FILTER_SPAD_SIZE
        self.PSUM_SPAD_SIZE = PSUM_SPAD_SIZE
        self.IFMAP_NUM = IFMAP_NUM
        self.FILTER_NUM = FILTER_NUM
        self.IPSUM_NUM = IPSUM_NUM
        self.OPSUM_NUM = OPSUM_NUM
        self.MA_X = MA_X
        self.MA_Y = MA_Y
        self.config_q = 0
        self.config_p = 0
        self.config_U = 0
        self.config_S = 0
        self.config_F = 0
        self.config_W = 0
        
        # spad
        self.ifmap_spad = [0,]*IFMAP_SPAD_SIZE
        self.filter_spad = [0,]*FILTER_SPAD_SIZE
        self.psum_spad = [0,]*PSUM_SPAD_SIZE
        
        self.reset_counter()
        
    def reset_counter(self):
        self.ifmap_cnt = 0
        self.filter_cnt = 0
        self.psum_cnt = 0
        self.macs_cnt = 0
    
    def set_info(self,q,p,U,S,F,W):
        self.config_q = q
        self.config_p = p
        self.config_U = U
        self.config_S = S
        self.config_F = F
        self.config_W = W
        self.reset_counter()
    
    def put_ifmap(self,ifmap): # IFMAP_NUM data/transfer
        assert (self.ifmap_cnt < self.IFMAP_SPAD_SIZE), "ifmap is full, incorrect event"
        assert (len(ifmap) == self.IFMAP_NUM), "ifmap nums should be {:d} but got {:d}".format(self.IFMAP_NUM, len(ifmap))
        self.ifmap_spad[self.ifmap_cnt:self.ifmap_cnt+self.IFMAP_NUM] = ifmap
        self.ifmap_cnt += self.IFMAP_NUM
    
    def put_filter(self,filter): # FILTER_NUM data/transfer
        assert (self.filter_cnt < self.FILTER_SPAD_SIZE), "filter is full, incorrect event"
        assert (len(filter) == self.FILTER_NUM), "filter nums should be {:d} but got {:d}".format(self.FILTER_NUM, len(filter))
        self.filter_spad[self.filter_cnt:self.filter_cnt+self.FILTER_NUM] = filter
        self.filter_cnt += self.FILTER_NUM
        
    def run(self):
        self.MACs()
        
    def MACs(self):
        if self.macs_cnt >= self.filter_cnt or self.macs_cnt >= self.ifmap_cnt:
            return
        
        self.psum_spad[self.psum_cnt]
        
    
    def put_ipsum(self,ipsum): # IPSUM_NUM data/transfer
        pass
    
    def get_opsum(self):
        return 0

## --------------------------------------------------
import torch

torch.manual_seed(123)

def tiling_list(N, n):
    return [n,]*(N//n) + [N%n, ] if N%n != 0 else [n,]*(N//n)

def tiling_conv2d(ifmap, filter, simulate_output):    
    (N,C,H,W)= ifmap.shape
    (M,_,R,S)= filter.shape
    (_,_,E,F)= simulate_output.shape
    
    n_tile = tiling_list(N,4)
    n_tile = tiling_list(N,4)
    n_tile = tiling_list(N,4)
    
    
    for n in range(N):
        for m in range(M):
            for e in range(E):
                for r in range(R):
                    for c in range(c_tile):
                        # --------------------------
                        for q in range(q_tile[c]):
                            for f in range(F):
                                h = e+r-(R//2)
                                if h < 0 or h >= H:
                                    continue
                                w1 = f-(S//2)
                                w2 = w1 + 3
                                s1 = 0
                                s2 = 3
                                if w1 < 0:
                                    w1 = 0
                                    s1 = w1 - (f-(S//2))
                                if w2 >= W:
                                    w2 = W
                                    s2 = w2 - (f-(S//2))
                                #for s in range(S):    
                                simulate_output[n][m][e][f] += torch.dot(ifmap[n][c*4 + q][h][w1:w2] , filter[m][c*4+q][r][s1:s2])
                print("[simulate_output] [{:3d}][{:3d}][{:3d}][{:3d}]".format(n,m,e,f),end= "\r", flush=True)
    
    print()
    return simulate_output

def main():
    ifmap = torch.randint(low=-128, high=128, size=(1, 3, 28, 28), dtype=torch.int16)
    filter = torch.randint(low=-128, high=128, size=(3, 3, 3, 3), dtype=torch.int16)
    golden = torch.nn.functional.conv2d(ifmap, filter, stride=(1, 1), padding=(1, 1))
    simulate_output = torch.zeros_like(golden)
    
    print(ifmap.shape)
    print(filter.shape)
    print(golden.shape)
    print(simulate_output.shape)
    
    simulate_output = tiling_conv2d( ifmap, filter, simulate_output)
    print("[Result Check] ", torch.equal(golden,simulate_output))
    
if __name__ == "__main__":
    main()