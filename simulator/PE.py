IDLE = 0
COMPUTE = 1
IPSUM = 2
OPSUM = 3

class PE(object):
    def __init__(self,
                 IFMAP_SPAD_SIZE = 12,
                FILTER_SPAD_SIZE = 224,
                PSUM_SPAD_SIZE = 24,
                IFMAP_NUM = 1,
                FILTER_NUM = 4,
                IPSUM_NUM = 4,
                OPSUM_NUM = 4,
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
        self.state = IDLE
        self.ipsum = None
        
    def reset_counter(self):
        self.ifmap_cnt = 0
        self.filter_cnt = 0
        self.psum_cnt = 0
        self.macs_cnt = 0
        self.w_cnt = 0
    
    def set_info(self,q,p,U,S,F,W):
        assert (self.state==IDLE), "state should be IDLE"
        assert (q*S <= self.IFMAP_SPAD_SIZE), "ifmap spad is oversize, incorrect q*S"
        assert (p*q*S <= self.FILTER_SPAD_SIZE), "filter spad is oversize, incorrect p*q*S"
        self.config_q = q
        self.config_p = p
        self.config_U = U
        self.config_S = S
        self.config_F = F
        self.config_W = W
        self.reset_counter()
        self.state=COMPUTE
    
    def put_ifmap(self,ifmap): # IFMAP_NUM data/transfer
        assert (self.state==COMPUTE), "state should be COMPUTE "
        assert (self.ifmap_cnt < self.config_q*self.config_S), "ifmap is full, incorrect event"
        assert (len(ifmap) == self.IFMAP_NUM), "ifmap nums should be {:d} but got {:d}".format(self.IFMAP_NUM, len(ifmap))
        self.ifmap_spad[self.ifmap_cnt:self.ifmap_cnt+self.IFMAP_NUM] = ifmap
        self.ifmap_cnt += self.IFMAP_NUM
    
    def put_filter(self,filter): # FILTER_NUM data/transfer
        assert (self.state==COMPUTE), "state should be COMPUTE "
        assert (self.filter_cnt < self.config_p*self.config_q*self.config_S), "filter is full, incorrect event"
        assert (len(filter) == self.FILTER_NUM), "filter nums should be {:d} but got {:d}".format(self.FILTER_NUM, len(filter))
        self.filter_spad[self.filter_cnt:self.filter_cnt+self.FILTER_NUM] = filter
        self.filter_cnt += self.FILTER_NUM
        
    def run(self):
        if self.state==COMPUTE:
            self.MACs()
            #if self.MA_X == 0:
                #print("[PE COMPUTE] macs_cnt = ",self.macs_cnt,
                #      "filter_cnt = ",self.filter_cnt,
                #      "ifmap_cnt = ",self.ifmap_cnt)
                #print("[self.ifmap_spad] ",self.ifmap_spad)
        
    def MACs(self):
        assert (self.state==COMPUTE), "state should be COMPUTE " 
        if self.macs_cnt >= self.filter_cnt or (self.macs_cnt%(self.config_q*self.config_S)) >= self.ifmap_cnt:
            return
        
        ifmap_id = self.macs_cnt%(self.config_q*self.config_S)
        filter_id = self.macs_cnt
        psum_id = self.macs_cnt//(self.config_q*self.config_S)
        self.psum_spad[psum_id] += self.ifmap_spad[ifmap_id] * self.filter_spad[filter_id] # MAC
        
        self.macs_cnt += 1
        if self.macs_cnt >= self.config_p*self.config_q*self.config_S: # compute done
            self.state=IPSUM
        
    def put_ipsum(self,ipsum): # IPSUM_NUM data/transfer
        assert (self.state==IPSUM), "state should be IPSUM "
        assert(self.ipsum == None), "ipsum is not ready"
        self.ipsum = ipsum
        self.state=OPSUM
    
    def get_opsum(self):
        assert (self.state==OPSUM), "state should be OPSUM "
        p1 = self.psum_cnt*self.OPSUM_NUM
        p2 = (self.psum_cnt+1)*self.OPSUM_NUM
        self.psum_spad[p1:p2] += self.ipsum
        self.psum_cnt += self.OPSUM_NUM
        self.ipsum = None
        r = self.psum_spad[p1:p2]
        
        if self.psum_cnt >= self.config_p:
            self.psum_cnt = 0
            self.psum_spad = [0,]*self.PSUM_SPAD_SIZE
            self.macs_cnt = 0
            self.ifmap_cnt -= self.config_q
            self.ifmap_spad = self.ifmap_spad[self.config_q:self.config_q*self.config_S] + [0,] * self.config_q  
            self.w_cnt += 1 # shif
            if self.w_cnt == self.config_W: # one pass done
                self.state = IDLE
                self.reset_counter()
            else:
                #print("[Back to COMPUTE]")
                self.state = COMPUTE
        
        #breakpoint()
        return r
    
    @property
    def ifmap_ready(self):
        return True if self.ifmap_cnt < self.config_q*self.config_S else False
    
    @property
    def filter_ready(self):
        return True if self.filter_cnt < self.config_p*self.config_q*self.config_S else False
    
    @property
    def ipsum_ready(self):
        return self.state==IPSUM
    
    @property
    def opsum_enable(self):
        return self.state==OPSUM

import torch
torch.manual_seed(123)
def unitest():
    print("[ Using Pytorch backend to Verify ]")
    ### Prepare data
    (n,q,H,W) = (1,4,3,12)
    (p,q,R,S) = (4,4,3,3)
    U = 1
    F = (W-S+U)/U
    ifmap = torch.randint(low=-128, high=128, size=(n,q,H,W), dtype=torch.int16)
    filter = torch.randint(low=-128, high=128, size=(p,q,R,S), dtype=torch.int16)
    golden = torch.nn.functional.conv2d(ifmap, filter, stride=(U, U), padding=(0, 0))
    #print("[ ifmap ]",ifmap)
    #print("[ filter ]",filter)
    print("[ Golden ]",golden)
    simulate_output = torch.zeros_like(golden)
    print(simulate_output.shape)
    
    ### Generate PE 
    pe_set = [PE(MA_X = i) for i in range(R)] # default hardware configuration
    for pe in pe_set:
        pe.set_info(q = q,p = p,U = U,S = S,F = F,W = W) # PE software config
    
    ### Testing
    # Filter 
    for p_ in range(p):
        for S_ in range(S):
            # each PE 
            for R_ in range(R):
                if pe_set[R_].filter_ready:
                    filter_data = filter[p_,:,R_,S_]#.tolist()
                    pe_set[R_].put_filter(filter_data)
    
    # ifmap / psum
    W_ = 0
    F_ = 0
    psum = [[0,]*p, ] + [None, ] * R
    while F_ < F:
        #print("[W_ / W] = {:d} / {:d}".format(W_,W))
        # put ifmap
        all_ready = True
        for R_ in range(R):
            all_ready = all_ready and pe_set[R_].ifmap_ready
        
        if all_ready:
            for R_ in range(R):
                for q_ in range(q):
                    ifmap_data = [ifmap[0,q_,R_,W_].tolist(),]
                    pe_set[R_].put_ifmap(ifmap_data)
            W_ += 1
         

        # MACs
        for pe in pe_set:
            pe.run()
        
        # try get output / put ipsum
        for i in range(R):
            if pe_set[i].ipsum_ready and psum[i] != None:
                #print("[PUT PSUM]",i,psum[i])
                pe_set[i].put_ipsum(psum[i])
            if pe_set[i].opsum_enable:
                psum[i+1] = pe_set[i].get_opsum()
                #print("[GET PSUM]",i,psum[i+1])
        
        next_w = True
        for p_ in psum:
            if p_ == None:
                next_w = False
                break

        if next_w:
            for i,r in enumerate(psum[R]):
                #print(i, r)
                simulate_output[0,i,0,F_] = r
            #print(psum[R])
            psum = [[0,]*p, ] + [None, ] * R
            F_ += 1 

    print("[ simulate_output ]",simulate_output)
    
if __name__ == "__main__":
    unitest()