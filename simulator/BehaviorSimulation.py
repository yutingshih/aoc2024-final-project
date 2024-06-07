from PEarray import PE_array
import torch

torch.manual_seed(123)

def PE_array_sim(ifmap, filter, stride, padding):
    dut = PE_array()

def tiling_list(N, n):
    t = [n,]*(N//n) + [N%n, ] if N%n != 0 else [n,]*(N//n)
    return len(t), t

def hardware_conv2d(ifmap, filter,stride,pading_H1,pading_H2,padding_W):
    s = list(ifmap.shape)
    #print("[hardware_conv2d] ifmap.shape = ",s)
    s[2] = pading_H1 # height
    padding_zero = torch.zeros(s, dtype=torch.int16) 
    ifmap = torch.cat((padding_zero,ifmap) , dim = 2)
    s[2] = pading_H2 # height
    padding_zero = torch.zeros(s, dtype=torch.int16) 
    ifmap = torch.cat((ifmap,padding_zero) , dim = 2)
    #print("[hardware_conv2d] ifmap.shape = ",ifmap.shape)
    #print("[hardware_conv2d] filter.shape = ",filter.shape)
    
    output_goldon = torch.nn.functional.conv2d(ifmap, filter, stride=stride, padding=(0, padding_W)) # simulation using torch function
    #output_PE_sim =
        
    return output_goldon

def tiling_conv2d(ifmap, filter, simulate_output, stride=(1, 1), padding=(1, 1)):    
    (N,C,H,W)= ifmap.shape
    (M,_,R,S)= filter.shape
    (_,_,E,F)= simulate_output.shape
    P = padding[0]
    U = stride[0]
    
    map_n = 1
    map_q = 6
    map_e = 14
    map_m = 32
    
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
                    simulate_output[n1:n2,m1:m2,e1:e2,:] += hardware_conv2d(ifmap[n1:n2,q1:q2,h1:h2,:] , filter[m1:m2,q1:q2,:,:],stride, pading_H1, pading_H2 , padding[1])
                    print("[simulate_output] [{:3d}][{:3d}][{:3d}][:]".format(n1,m1,e1),end= "\r", flush=True)
    
    print()
    return simulate_output

def main():
    ifmap = torch.randint(low=-128, high=128, size=(1, 384, 56, 56), dtype=torch.int16)
    filter = torch.randint(low=-128, high=128, size=(256, 384, 3, 3), dtype=torch.int16)
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