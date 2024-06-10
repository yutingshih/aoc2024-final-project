print("[PYTHON] generate testbench for GIN")
# generate testbench for GIN
TOTAL_ROW = 12
TOTAL_COL = 14

ROW_LEN = 4
ID_LEN = 5

STRIDE = 1
Q = 4
E = 28
S = 3
t = 2
r = 2
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
    print("[{:2d}]->".format((i//(PE_SET[1])%(r))*Q), end=" ")
    set_row_scan_ifmap[i] = (i//(PE_SET[1])%(r))*Q
    for j in range(TOTAL_COL):
        set_id_scan_ifmap[i*TOTAL_COL + j] = (i//PE_SET[1]//r//t)*TOTAL_COL*STRIDE + i%PE_SET[1] + j*STRIDE
        print("{:2d}".format((i//PE_SET[1]//r//t)*TOTAL_COL*STRIDE + i%PE_SET[1] + j*STRIDE), end=" ")
    print()
    
print("[FILTER GIN scan chain]")
for i in range(TOTAL_ROW):
    print("[{:2d}]->".format((i//PE_SET[1]%(r*t))*Q), end=" ")
    set_row_scan_filter[i] = (i//PE_SET[1]%(r*t))*Q
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
            set_id_scan_ipsum[i*TOTAL_COL + j] = (i//PE_SET[1]//r//t)*TOTAL_COL*STRIDE + j*STRIDE
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
            set_id_scan_opsum[i*TOTAL_COL + j] = (i//PE_SET[1]//r//t)*TOTAL_COL*STRIDE + j*STRIDE
        else:
            set_id_scan_opsum[i*TOTAL_COL + j] = 31
        print("{:2d}".format(set_id_scan_opsum[i*TOTAL_COL + j]), end=" ")
    print()

# reverse for scan chain
row_scan = set_row_scan_filter + set_row_scan_ifmap + set_row_scan_ipsum + set_row_scan_opsum
id_scan = set_id_scan_filter + set_id_scan_ifmap + set_id_scan_ipsum + set_id_scan_opsum

row_scan.reverse()
id_scan.reverse()

# generate test data
ifmap = [i//224 for i in range(224*60)]

# write out file
print("[PYTHON] writing file...", end = "")
row_file = open("./output/PEarray_Test_ROW.txt","w")
for n in row_scan:
    row_file.write("{:02x}\n".format(n))
row_file.close()

id_file = open("./output/PEarray_Test_ID.txt","w")
for n in id_scan:
    id_file.write("{:02x}\n".format(n))
id_file.close()

ifmap_file = open("./output/PEarray_Test_IFMAP.txt","w")
for n in ifmap:
    ifmap_file.write("{:02x}\n".format(n))
ifmap_file.close()
print("Done")