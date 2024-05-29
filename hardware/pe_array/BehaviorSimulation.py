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
    t = [n,]*(N//n) + [N%n, ] if N%n != 0 else [n,]*(N//n)
    return len(t), t

def hardware_conv2d(ifmap, filter,pading_H1,pading_H2):
    s = list(ifmap.shape)
    #print("[hardware_conv2d] ifmap.shape = ",s)
    s[2] = pading_H1 # hight
    padding_zero = torch.zeros(s, dtype=torch.int16) 
    ifmap = torch.cat((padding_zero,ifmap) , dim = 2)
    s[2] = pading_H2 # hight
    padding_zero = torch.zeros(s, dtype=torch.int16) 
    ifmap = torch.cat((ifmap,padding_zero) , dim = 2)
    #print("[hardware_conv2d] ifmap.shape = ",ifmap.shape)
    #print("[hardware_conv2d] filter.shape = ",filter.shape)
        
    return torch.nn.functional.conv2d(ifmap, filter, stride=(1, 1), padding=(0, 1)) 

def tiling_conv2d(ifmap, filter, simulate_output, stride=(1, 1), padding=(1, 1)):    
    (N,C,H,W)= ifmap.shape
    (M,_,R,S)= filter.shape
    (_,_,E,F)= simulate_output.shape
    P = padding[0]
    U = stride[0]
    
    map_n = 1
    map_q = 3
    map_e = 14
    map_m = 4
    
    n_group, n_tile = tiling_list(N,map_n)
    q_group, q_tile = tiling_list(C,map_q)
    e_group, e_tile = tiling_list(E,map_e)
    m_group, m_tile = tiling_list(M,map_m)
    
    print(n_group, q_tile)
    print(q_group, n_tile)
    print(e_group, e_tile)
    print(m_group, m_tile)
    
    for n in range(n_group):
        for e in range(e_group):
            for c in range(q_group):
                for m in range(m_group):
                # --------------------------
                    n1 = n*map_n
                    n2 = n1 + n_tile[n]
                    e1 = e*map_e
                    e2 = e1 + e_tile[e]
                    q1 = c*map_q
                    q2 = q1 + q_tile[c]
                    m1 = m*map_m
                    m2 = m1 + m_tile[m]
                    h1 = (e1 * U) - U
                    h2 = (e2 * U) + U
                    #print((n1,n2),(e1,e2),(q1,q2),(m1,m2),(h1,h2))
                    pading_H1 = 0 if h1 >= 0 else P
                    h1 = h1 if h1 >= 0 else 0
                    pading_H2 = 0  if h2 <= H else P
                    h2 = h2 if h2 <= H else H
                    #print((n1,n2),(e1,e2),(q1,q2),(m1,m2),(h1,h2))
                    simulate_output[n1:n2,m1:m2,e1:e2,:] += hardware_conv2d(ifmap[n1:n2,q1:q2,h1:h2,:] , filter[m1:m2,q1:q2,:,:], pading_H1, pading_H2)
                    print("[simulate_output] [{:3d}][{:3d}][{:3d}][:]".format(n1,m1,e1),end= "\r", flush=True)
    
    print()
    return simulate_output

def main():
    ifmap = torch.randint(low=-128, high=128, size=(1, 256, 56, 56), dtype=torch.int16)
    filter = torch.randint(low=-128, high=128, size=(384, 256, 3, 3), dtype=torch.int16)
    golden = torch.nn.functional.conv2d(ifmap, filter, stride=(1, 1), padding=(1, 1))
    simulate_output = torch.zeros_like(golden)
    
    print(ifmap.shape)
    print(filter.shape)
    print(golden.shape)
    print(simulate_output.shape)
    
    simulate_output = tiling_conv2d( ifmap, filter, simulate_output, stride=(1, 1), padding=(1, 1))
    print("[Result Check] ", torch.equal(golden,simulate_output))
    
if __name__ == "__main__":
    main()