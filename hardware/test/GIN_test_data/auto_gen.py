print("[PYTHON] generate testbench for GIN")
# generate testbench for GIN
TOTAL_ROW = 12
TOTAL_COL = 14

ROW_LEN = 4
ID_LEN = 5


PE_SET = (2, 3, 28)

# init
set_row_scan = [(2**ROW_LEN-1),]*TOTAL_ROW
set_id_scan = [(2**ID_LEN-1),]*TOTAL_ROW*TOTAL_COL

# set row and id
tile = PE_SET[0] * PE_SET[1]
for i in range(TOTAL_ROW):
    set_row_scan[i] = (i%tile)//PE_SET[1]
    for j in range(TOTAL_COL):
        set_id_scan[i*TOTAL_COL + j] = ((i%tile)//PE_SET[1])*TOTAL_COL + i%PE_SET[1] + j

# reverse for scan chain
set_row_scan.reverse()
set_id_scan.reverse()

# generate test data
ifmap = [i//224 for i in range(224*60)]

# write out file
print("[PYTHON] writing file...", end = "")
row_file = open("./output/GIN_Test_ROW.txt","w")
for n in set_row_scan:
    row_file.write("{:02x}\n".format(n))
row_file.close()

id_file = open("./output/GIN_Test_ID.txt","w")
for n in set_id_scan:
    id_file.write("{:02x}\n".format(n))
id_file.close()

ifmap_file = open("./output/GIN_Test_IFMAP.txt","w")
for n in ifmap:
    ifmap_file.write("{:02x}\n".format(n))
ifmap_file.close()
print("Done")