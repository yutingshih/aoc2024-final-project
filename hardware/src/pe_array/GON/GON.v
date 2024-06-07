`include "./src/pe_array/GON/GONXBus.v"
`include "./src/pe_array/GON/GONYBus.v"

module GON #(
    parameter   XBUS_NUMS = 12,
                PE_NUMS = 14,
                ID_LEN = 5,
                ROW_LEN = 4,
                VALUE_LEN = 32
) (
    input clk,
    input rst,
    
    output wire enable,
    input ready,
    input [ROW_LEN-1:0] row_tag,
    input [ID_LEN-1:0] col_tag,
    output wire [VALUE_LEN-1:0] value,

    /* config */
    input set_id,
    input [ID_LEN-1:0] id_scan_in,
    output wire [ID_LEN-1:0] id_scan_out,

    input set_row,
    input [ROW_LEN-1:0] row_scan_in,
    output wire [ROW_LEN-1:0] row_scan_out,

    /* PE IO */
    output pe_ready [PE_NUMS*XBUS_NUMS-1:0],
    input [VALUE_LEN:0] pe_enable_data [PE_NUMS*XBUS_NUMS-1:0]
    
);

    /* gather value and enable to YBus */
    wire [ROW_LEN+ID_LEN:0] ready_tag = {ready, row_tag, col_tag};
    wire [VALUE_LEN:0] enable_value;
    assign value = enable_value[VALUE_LEN-1:0];
    assign enable = enable_value[VALUE_LEN];

    /* YBus - XBus connections */
    wire [ID_LEN:0] xbus_ready_tag [XBUS_NUMS-1:0];
    wire [VALUE_LEN:0] xbus_enable_data [XBUS_NUMS-1:0];

    /* YBus */
    GONYBus #(
        .MASTER_NUMS(XBUS_NUMS),
        .ROW_LEN(ROW_LEN),
        .ID_LEN(ID_LEN),
        .VALUE_LEN(VALUE_LEN)
    )YBus_0(
        .clk(clk),
        .rst(rst),
        
        /* Slave I/O */
        .ready_tag(ready_tag),
        .enable_value(enable_value),

        /* Master IO (to XBus)*/
        .master_ready_tag(xbus_ready_tag),
        .master_enable_data(xbus_enable_data),
        
        /* config */
        .set_id(set_row),
        .id_scan_in(row_scan_in),
        .id_scan_out(row_scan_out)
    );

    // id scan chain wire
    wire [ID_LEN-1:0] scan_chain [XBUS_NUMS:0];
    assign scan_chain[0] = id_scan_in;
    assign id_scan_out = scan_chain[XBUS_NUMS];

    /* XBuses */
    genvar i;
    for (i = 0;i < XBUS_NUMS; i = i + 1) begin
        GONXBus #(
        .MASTER_NUMS(PE_NUMS),
        .ID_LEN(ID_LEN),
        .VALUE_LEN(VALUE_LEN),
        .MA_Y(i)
        )XBus_0(
            .clk(clk),
            .rst(rst),
            
            /* Slave I/O */
            .ready_tag(xbus_ready_tag[i]),
            .enable_value(xbus_enable_data[i]),

            /* Master IO (to PEs)*/
            .master_ready_tag(pe_ready[(i+1)*PE_NUMS-1:i*PE_NUMS]),
            .master_enable_data(pe_enable_data[(i+1)*PE_NUMS-1:i*PE_NUMS]),
            
            /* config */
            .set_id(set_id),
            .id_scan_in(scan_chain[i]),
            .id_scan_out(scan_chain[i+1])
        );

    end

    always @(posedge clk) begin
        if(ready)begin
            $display("[GON] ready, row_tag = %d, col_tag = %d", row_tag,col_tag);
        end
    end
    
endmodule