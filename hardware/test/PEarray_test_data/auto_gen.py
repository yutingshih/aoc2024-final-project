def gen_scan_chain(
        TOTAL_ROW = 12,
        TOTAL_COL = 14,

        ROW_LEN = 4,
        ID_LEN = 5,

        H = None,
        W = None,
        C = None,
        
        U = 1,
        F = None,
        E = 28,
        M = None,
        S = 3,
        
        t = 2,
        r = 2,
        p = 16,
        q = 4,
        n = 1,
        m = 16,  
    ):
    #assert(H != None), "H is not given !!!"
    #assert(W != None), "W is not given !!!"
    #assert(C != None), "C is not given !!!"
    #assert(F != None), "C is not given !!!"
    
    print("[PYTHON] generate testbench for GIN")
    # generate testbench for GIN
    
    PE_SET = (TOTAL_ROW//(S*r*t), S, E)

    # init
    set_row_scan_ifmap = [(2**ROW_LEN-1),]*TOTAL_ROW
    set_id_scan_ifmap = [(2**ID_LEN-1),]*TOTAL_ROW*TOTAL_COL
    set_row_scan_filter = [(2**ROW_LEN-1),]*TOTAL_ROW
    set_id_scan_filter = [(2**ID_LEN-1),]*TOTAL_ROW*TOTAL_COL
    set_row_scan_ipsum = [(2**ROW_LEN-1),]*TOTAL_ROW
    set_id_scan_ipsum = [(2**ID_LEN-1),]*TOTAL_ROW*TOTAL_COL
    set_row_scan_opsum = [(2**ROW_LEN-1),]*TOTAL_ROW
    set_id_scan_opsum = [(2**ID_LEN-1),]*TOTAL_ROW*TOTAL_COL

    # set row and id
    print("[IFMAP GIN scan chain]")
    for i in range(TOTAL_ROW):
        print("[{:2d}]->".format((i//(PE_SET[1])%(r))*q), end=" ")
        set_row_scan_ifmap[i] = (i//(PE_SET[1])%(r))*q
        for j in range(TOTAL_COL):
            set_id_scan_ifmap[i*TOTAL_COL + j] = (i//PE_SET[1]//r//t)*TOTAL_COL*U + i%PE_SET[1] + j*U
            print("{:2d}".format((i//PE_SET[1]//r//t)*TOTAL_COL*U + i%PE_SET[1] + j*U), end=" ")
        print()
        
    print("[FILTER GIN scan chain]")
    for i in range(TOTAL_ROW):
        print("[{:2d}]->".format((i//PE_SET[1]%(r*t))*q), end=" ")
        set_row_scan_filter[i] = (i//PE_SET[1]%(r*t))*q
        for j in range(TOTAL_COL):
            set_id_scan_filter[i*TOTAL_COL + j] =  i%PE_SET[1]
            print("{:2d}".format( i%PE_SET[1]), end=" ")
        print()

    print("[IPSUM GIN scan chain]")
    for i in range(TOTAL_ROW):
        zz = i//(PE_SET[1]*t)%(r*t)
        if (i+1)%(PE_SET[1]*r) == 0:
            set_row_scan_ipsum[i] = zz
        else:
            set_row_scan_ipsum[i] = 15 # reserved
            
        print("[{:2d}]->".format(set_row_scan_ipsum[i]), end=" ")
        for j in range(TOTAL_COL):
            if (i+1)%(PE_SET[1]*r) == 0:
                set_id_scan_ipsum[i*TOTAL_COL + j] = (i//PE_SET[1]//r//t)*TOTAL_COL*U + j*U
            else:
                set_id_scan_ipsum[i*TOTAL_COL + j] = 31
            print("{:2d}".format(set_id_scan_ipsum[i*TOTAL_COL + j]), end=" ")
        print()
        
    print("[OPSUM GON scan chain]")
    for i in range(TOTAL_ROW):
        zz = i//(PE_SET[1]*t)%(r*t)
        if i%(PE_SET[1]*r) == 0:
            set_row_scan_opsum[i] = zz
        else:
            set_row_scan_opsum[i] = 15 # reserved
            
        print("[{:2d}]->".format(set_row_scan_opsum[i]), end=" ")
        for j in range(TOTAL_COL):
            if i%(PE_SET[1]*r) == 0:
                set_id_scan_opsum[i*TOTAL_COL + j] = (i//PE_SET[1]//r//t)*TOTAL_COL*U + j*U
            else:
                set_id_scan_opsum[i*TOTAL_COL + j] = 31
            print("{:2d}".format(set_id_scan_opsum[i*TOTAL_COL + j]), end=" ")
        print()

    # reverse for scan chain
    row_scan = set_row_scan_ifmap + set_row_scan_filter + set_row_scan_ipsum + set_row_scan_opsum
    id_scan = set_id_scan_ifmap + set_id_scan_filter + set_id_scan_ipsum + set_id_scan_opsum

    ## Local network
    print("[Local network scan chain]")
    LN_scan = 0
    for i in range(TOTAL_ROW):
        zz = i//(PE_SET[1]*t)%(r*t)
        if i%(PE_SET[1]*r) == 0:
            LN_scan = LN_scan + (0 << i)
        else:
            LN_scan = LN_scan + (1 << i) # reserved
            
    LN_scan = [
        (LN_scan>>24)%256,
        (LN_scan>>16)%256,
        (LN_scan>>8)%256,
        LN_scan%256
    ]
    for ln in LN_scan:
        print("{:08b}".format(ln), end=" ")
    print()
    
    print("[PE config scan chain]")
    pe_config_scan = []
    CONFIG_W_BIT = 8
    CONFIG_H_BIT = 8
    CONFIG_C_BIT = 12
    CONFIG_U_BIT = 4
    
    CONFIG_E_BIT = 8
    CONFIG_F_BIT = 8
    CONFIG_M_BIT = 12
    CONFIG_S_BIT = 4  # filter width config
    
    CONFIG_q_BIT = 3  # channel count config
    CONFIG_p_BIT = 5  # kernel count config
    CONFIG_t_BIT = 4  # filter width config
    CONFIG_r_BIT = 4  # filter width config
   
    pe_config = (W%(2**CONFIG_W_BIT))
    pe_config += (H%(2**CONFIG_H_BIT)) << CONFIG_W_BIT 
    pe_config += (C%(2**CONFIG_C_BIT)) << (CONFIG_W_BIT+CONFIG_H_BIT)
    pe_config += (U%(2**CONFIG_U_BIT)) << (CONFIG_W_BIT+CONFIG_H_BIT+CONFIG_C_BIT)
    
    pe_config_scan += [
        pe_config%256,
        (pe_config>>8)%256,
        (pe_config>>16)%256,
        (pe_config>>24)%256
    ] 
    
    pe_config = (F%(2**CONFIG_F_BIT))
    pe_config += (E%(2**CONFIG_E_BIT)) << CONFIG_F_BIT 
    pe_config += (M%(2**CONFIG_M_BIT)) << (CONFIG_E_BIT+CONFIG_F_BIT)
    pe_config += (S%(2**CONFIG_S_BIT)) << (CONFIG_E_BIT+CONFIG_F_BIT+CONFIG_M_BIT)
    
    pe_config_scan += [
        pe_config%256,
        (pe_config>>8)%256,
        (pe_config>>16)%256,
        (pe_config>>24)%256
    ] 
    
    pe_config = (q%(2**CONFIG_q_BIT))
    pe_config += (p%(2**CONFIG_p_BIT)) << CONFIG_q_BIT 
    pe_config += (t%(2**CONFIG_t_BIT)) << (CONFIG_q_BIT+CONFIG_p_BIT)
    pe_config += (r%(2**CONFIG_r_BIT)) << (CONFIG_q_BIT+CONFIG_p_BIT+CONFIG_t_BIT)
    
    pe_config_scan += [
        pe_config%256,
        (pe_config>>8)%256,
        (pe_config>>16)%256,
        (pe_config>>24)%256
    ]  
    
    print("[pe_config_scan] {:3d} Bytes".format(len(pe_config_scan)))
    print("[row_scan] {:3d} Bytes".format(len(row_scan)))
    print("[id_scan ] {:3d} Bytes".format(len(id_scan)))
    print("[LN_scan] {:3d} Bytes".format(len(LN_scan)))
    
    row_scan.reverse()
    id_scan.reverse()
    LN_scan.reverse()
    
    return pe_config_scan+row_scan+id_scan+LN_scan

### GEN IFMAP and OFMAP ###
import torch
torch.manual_seed(123)
def gen_test_data(
        ifmap_info = (1,8,28,224),
        filter_info = (4,8,28,3)
    ):
    print("[PYTHON] generate test data using pytorch")
    ### Prepare data
    (n,q,H,W) = ifmap_info
    (p,q,R,S) = filter_info
    U = 1
    F = (W-S+U)/U
    ifmap = torch.randint(low=-(2**7), high=(2**7), size=(n,q,H,W), dtype=torch.int8)
    filter = torch.randint(low=-(2**7), high=(2**7), size=(p,q,R,S), dtype=torch.int8)
    
    golden = torch.nn.functional.conv2d(ifmap.to(dtype=torch.int32), filter.to(dtype=torch.int32), stride=(U, U), padding=(0, 0))

    ifmap_file = open("./output/PEarray_Test_IFMAP.txt","w")
    ifmap_raw = ifmap.permute(0,2,3,1).flatten().numpy()
    print("[ifmap_raw] {:3d} Bytes".format(len(ifmap_raw)))
    for n in ifmap_raw:
        if n < 0:
            n = 256+int(n)
        ifmap_file.write("{:02x}\n".format(n))
    ifmap_file.close()

    filter_file = open("./output/PEarray_Test_FILTER.txt","w")
    filter_raw = filter.permute(0,2,3,1).flatten().numpy()
    print("[filter_raw] {:3d} Bytes".format(len(filter_raw)))
    for n in filter_raw:
        if n < 0:
            n = 256+int(n)
        filter_file.write("{:02x}\n".format(n))
    filter_file.close()
    
    print(filter[0,0:4,0,0:2])
    
    return list(ifmap_raw),list(filter_raw)

if __name__ == "__main__":
    scan_chain = gen_scan_chain(
        TOTAL_ROW = 12,
        TOTAL_COL = 14,

        ROW_LEN = 4,
        ID_LEN = 5,

        H = 28,
        W = 224,
        C = 8,
        M  = 16,
        F = int((224-3+1)/1),
        U = 1,
        q = 4,
        E = 28,
        S = 3,
        t = 1,
        r = 2
    )
    ifmap_raw,filter_raw = gen_test_data(
        ifmap_info = (1,8,28,224),
        filter_info = (16,8,3,3)
    )
    

    mem_data = filter_raw+ifmap_raw+scan_chain
    
    address = {
        "filter":0,
        "ifmap":len(filter_raw),
        "scan_chain":len(filter_raw)+len(ifmap_raw),
        "EOF":len(scan_chain)+len(filter_raw)+len(ifmap_raw),
    }
    
    print("[Memory Address]")
    for k,v in address.items():
        print("[{:15s}] {:8d}".format(k,v))
    
    print("[PYTHON] writing file...", end = "")
    mem_file = open("./output/PEarray_Test_MEM.txt","w")
    for n in mem_data:
        if n < 0:
            n = 256+int(n)
        mem_file.write("{:02x}\n".format(n))
    mem_file.close()
    
    print("Done")