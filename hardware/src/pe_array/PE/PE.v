`include "def.svh"

module PE#(
    parameter IFMAP_SPAD_SIZE = 12,
			FILTER_SPAD_SIZE = 192,
			PSUM_SPAD_SIZE = 16,
			IFMAP_DATA_SIZE = 8,
			FILTER_DATA_SIZE = 16,
			PSUM_DATA_SIZE = 32,
			IPSUM_DATA_SIZE = 32,
			IFMAP_NUM = 4,
			FILTER_NUM = 1,
			IPSUM_NUM = 4,
			OPSUM_NUM = 4,
			CONFIG_Q_BIT = 2, // channel count config
			CONFIG_P_BIT = 5, // kernel count config
			CONFIG_U_BIT = 4, // stride config
			CONFIG_S_BIT = 4, // filter width config
			CONFIG_F_BIT = 8, // ifmap width config
			CONFIG_W_BIT = 8, // ofmap width config
			MA_X = 0,
			MA_Y = 0
)   (
    
    input clk,
    input rst,
    input enable,
    /* Data Flow */
    input   [(IFMAP_NUM * IFMAP_DATA_SIZE)-1:0]     ifmap,
    input   [(FILTER_NUM * FILTER_DATA_SIZE)-1:0]    filter,
    input   [(IPSUM_NUM * IPSUM_DATA_SIZE)-1:0]     ipsum,
    output reg [(OPSUM_NUM * PSUM_DATA_SIZE)-1:0]     opsum,
    /* Control Signal */
    input ifmap_enable,
    output wire ifmap_ready,
    input filter_enable,
    output filter_ready,
    input ipsum_enable,
    output ipsum_ready,
    output opsum_enable,
    input opsum_ready,
    /* Control Signal */
    input set_info,
    input [CONFIG_Q_BIT-1:0] config_q,
    input [CONFIG_P_BIT-1:0] config_p,
    input [CONFIG_U_BIT-1:0] config_U,
    input [CONFIG_S_BIT-1:0] config_S,
    input [CONFIG_F_BIT-1:0] config_F,
    input [CONFIG_W_BIT-1:0] config_W
    /* 
        q(channel, 2b),
        p(kernel, 5b),
        U(stride, 4b), 
        S(filter width, 4b),
        F(ofmap width, 8b),
        W(ifmap width, 8b),
    */
);


reg [2:0] current_state, next_state;
parameter IDLE = 3'd0,SET = 3'd1, READ_AND_COMPUTE = 3'd2, IPSUM = 3'd3, OUTPUT = 3'd4, SHIFT = 3'd5, DONE = 3'd6;
reg [2:0] channel_count, ipsum_count;
reg [3:0] ifmap_count, mac_count, filter_col_count, stride_count;
reg [8:0] filter_count, mac_filter_count;
reg [5:0] ofcol_count;
reg [6:0] opsum_count;
reg [4:0] kernel_count;

reg [CONFIG_Q_BIT-1:0] config_q_reg;
reg [CONFIG_P_BIT-1:0] config_p_reg;
reg [CONFIG_U_BIT-1:0] config_U_reg;
reg [CONFIG_S_BIT-1:0] config_S_reg;
reg [CONFIG_F_BIT-1:0] config_F_reg;
reg [CONFIG_W_BIT-1:0] config_W_reg;
reg [11:0] data_valid;

reg signed [FILTER_DATA_SIZE-1:0] filter_reg [FILTER_SPAD_SIZE-1:0];
reg signed [IFMAP_DATA_SIZE-1:0] ifmap_reg [IFMAP_SPAD_SIZE-1:0];
reg signed [IPSUM_DATA_SIZE-1:0] ipsum_reg [3:0];
reg signed [PSUM_DATA_SIZE-1:0] psum [PSUM_SPAD_SIZE-1:0];

reg filter_done;
integer i;

wire ipsum_valid = (ipsum_ready && ipsum_enable);
wire ifmap_valid = (ifmap_ready && ifmap_enable);
wire filter_valid = (filter_enable && filter_ready);
wire [3:0] data_count = (mac_count < 12) ?11 - mac_count :0;
wire [FILTER_DATA_SIZE-1:0] cur_filter;
wire [IFMAP_DATA_SIZE-1:0] cur_ifmap;
// wire [11:0]shift_data = {data_valid[10:0], 1'b0};


wire [PSUM_DATA_SIZE-1:0] mul;
wire [PSUM_DATA_SIZE-1:0] sum;
reg [PSUM_DATA_SIZE-1:0] opsum_reg[3:0];
//assign mul = (current_state == IPSUM) ?ipsum_reg[ipsum_count] :((current_state == READ_AND_COMPUTE)?({{16{cur_ifmap[7]}},cur_ifmap} * {{16{cur_filter[7]}},cur_filter}) :mul);
assign mul = (current_state == IPSUM) ?ipsum_reg[ipsum_count] :mul;
assign sum = psum[kernel_count] + mul;


wire overflow = ((mul[PSUM_DATA_SIZE-1] == psum[kernel_count][PSUM_DATA_SIZE-1]) && (mul[PSUM_DATA_SIZE-1] != sum[PSUM_DATA_SIZE-1]));
//assign opsum_reg[ipsum_count] = (overflow == 1'd1) ?((psum[kernel_count][PSUM_DATA_SIZE-1] == 1'd1) ?(32'h80000000) :(32'h7fffffff)) :sum;



assign filter_ready = ((current_state == READ_AND_COMPUTE) && (filter_count < FILTER_SPAD_SIZE)) ?1'd1 :1'd0;
//assign ifmap_ready = ((current_state == READ_AND_COMPUTE) && (ifmap_count < IFMAP_SPAD_SIZE))?1'd1 :1'd0;
assign ifmap_ready = ((current_state == READ_AND_COMPUTE) && (data_valid[3:0] == 4'd0))?1'd1 :1'd0;
assign ipsum_ready = ((current_state == IPSUM) && (ipsum_count == 0)) ?1'b1 :1'b0;
assign opsum_enable = (current_state == OUTPUT) ?1'b1 :1'b0;

assign cur_filter = filter_reg[mac_filter_count];
assign cur_ifmap = ifmap_reg[mac_count];
wire done = ((ofcol_count == config_F_reg) && (current_state == SHIFT));


always @(*) begin
	if(ipsum_valid)begin
		ipsum_reg[0] = ipsum[IPSUM_DATA_SIZE-1:0];
		ipsum_reg[1] = ipsum[2*IPSUM_DATA_SIZE-1:IPSUM_DATA_SIZE];
		ipsum_reg[2] = ipsum[3*IPSUM_DATA_SIZE:2*IPSUM_DATA_SIZE];
		ipsum_reg[3] = ipsum[4*IPSUM_DATA_SIZE:3*IPSUM_DATA_SIZE];
	end
	if(current_state == IPSUM)begin
		opsum_reg[ipsum_count] = (overflow == 1'd1) ?((psum[kernel_count][PSUM_DATA_SIZE-1] == 1'd1) ?(32'h80000000) :(32'h7fffffff)) :sum;
	end
	
	else if (current_state == OUTPUT) begin
		if(opsum_ready)begin
			opsum[PSUM_DATA_SIZE-1:0] <= opsum_reg[0];
			opsum[2*PSUM_DATA_SIZE-1:PSUM_DATA_SIZE] <= opsum_reg[1];
			opsum[3*PSUM_DATA_SIZE-1:2*PSUM_DATA_SIZE] <= opsum_reg[2];
			opsum[4*PSUM_DATA_SIZE-1:3*PSUM_DATA_SIZE] <= opsum_reg[3];
		end
	end
end



always @(posedge clk or posedge rst) begin
    if(rst)begin
        current_state <= IDLE;
    end
    else begin
        current_state <= next_state;
    end
end


always @(*) begin
    case (current_state)
        IDLE:begin
			if(enable)begin
            	next_state = SET;
			end
			else begin
				next_state = IDLE;
			end
        end
        SET:begin
            if (set_info) begin
                next_state = READ_AND_COMPUTE;
            end
            else begin
                next_state = SET;
            end
        end
		READ_AND_COMPUTE:begin
			if((filter_col_count == (config_S_reg-1)) && (channel_count == (config_q_reg)) && (kernel_count == 15))begin
				next_state = IPSUM;
			end
			else begin
				next_state = READ_AND_COMPUTE;
			end
            
        end
		IPSUM:begin
			if(ipsum_count == (IPSUM_NUM-1))begin
				next_state = OUTPUT;
			end
			else begin
				next_state = IPSUM;
			end
		end
		OUTPUT:begin
			 if(opsum_count < (OPSUM_NUM-1))begin
				next_state = IPSUM;
			end
			else if ((opsum_count == (OPSUM_NUM-1)) && opsum_ready) begin
				next_state = SHIFT;
			end
			else begin
				next_state = OUTPUT;
			end
		end	
        SHIFT:begin
            if ((channel_count == (config_q_reg-1)) && (stride_count == config_U_reg-1)) begin
                next_state = READ_AND_COMPUTE;
            end
			else if (done == 1) begin
				next_state = DONE;
			end
			else begin
                next_state = SHIFT;
            end
        end
        DONE:begin
            next_state = IDLE;
        end
		default:begin
			next_state = IDLE;
		end    
    endcase
 end



always @(posedge clk or posedge rst) begin
    if(rst)begin
		filter_count <= 4'd0;
		ifmap_count <= 4'd0;
		mac_count <= 4'd0;
		ofcol_count <= 6'd0;
		opsum_count <= 7'd0;
		channel_count <= 0;
		kernel_count <= 0;
		ipsum_count <= 0;
		mac_filter_count <= 0;
		filter_col_count <= 0;
		stride_count <= 0;
		data_valid <= 0;	
		opsum <= 0;
		filter_done <= 0;
		for (i=0 ;i<12 ;i=i+1) begin
			filter_reg [i] <= 0;
			ifmap_reg [i] <= 0;
		end
		for (i=0 ;i<16 ;i=i+1) begin
			psum [i] <= 0;
		end
		for (i=0 ;i<4 ;i=i+1) begin
			ipsum_reg[i] <= 0;
		end
		config_q_reg <= 3'd0;
        config_p_reg <= 5'd0;
        config_U_reg <= 4'd0;
        config_S_reg <= 4'd0;
        config_F_reg <= 12'd0;
        config_W_reg <= 12'd0;
	end
	else begin
		case(current_state)
			IDLE:begin
				//psum <= 24'd0;
				filter_count <= 9'd0;
				ifmap_count <= 4'd0;	
				mac_count <= 4'd0;
				channel_count <= 0;
				kernel_count <= 0;
				ipsum_count <= 0;
				mac_filter_count <= 0;
				filter_col_count <= 0;
				stride_count <= 0;
				ofcol_count <= 6'd0;
				opsum_count <= 7'd0;
                config_q_reg <= 3'd0;
                config_p_reg <= 5'd0;
                config_U_reg <= 4'd0;
                config_S_reg <= 4'd0;
                config_F_reg <= 12'd0;
                config_W_reg <= 12'd0;
				data_valid <= 0;	
				opsum <= 0;		
			end
			SET:begin
                if(set_info)begin
                    config_q_reg <= config_q;   //channel 3
                    config_p_reg <= config_p;   //kernel 5
                    config_U_reg <= config_U;   //stride 4
                    config_S_reg <= config_S;   //filter width 4
                    config_F_reg <= config_F;   //ofmap width 12
                    config_W_reg <= config_W;   //ifmap width 12
                end
                else begin
					config_q_reg <= 3'd0;   
					config_p_reg <= 5'd0;
					config_U_reg <= 4'd0;
                    config_S_reg <= 4'd0;
                    config_F_reg <= 12'd0;
                    config_W_reg <= 12'd0;
				end
				filter_count <= 0;
            end
			READ_AND_COMPUTE:begin
				if(ofcol_count == 6'd0 || ofcol_count == config_F_reg)begin	//first opsum
					if(ifmap_count == 4'd0)begin
						if(ifmap_valid)begin
							ifmap_reg [0] <= ifmap[7:0];
							ifmap_reg [1] <= ifmap[15:8];
							ifmap_reg [2] <= ifmap[23:16];
							ifmap_reg [3] <= ifmap[31:24];
							data_valid[11] <= 1;
							data_valid[10] <= 1;
							data_valid[9] <= 1;
							data_valid[8] <= 1;
							ifmap_count <= ifmap_count + 4'd4;
						end
					end
					if(ifmap_count == 4'd4)begin
						if(ifmap_valid)begin	
							ifmap_reg [4] <= ifmap[7:0];
							ifmap_reg [5] <= ifmap[15:8];
							ifmap_reg [6] <= ifmap[23:16];
							ifmap_reg [7] <= ifmap[31:24];
							data_valid[7] <= 1;
							data_valid[6] <= 1;
							data_valid[5] <= 1;
							data_valid[4] <= 1;
							ifmap_count <= ifmap_count + 4'd4;
						end
					end
					else if(ifmap_count == 4'd8) begin		//ifmap done
						if(ifmap_valid)begin	
							ifmap_reg [8] <= ifmap[7:0];
							ifmap_reg [9] <= ifmap[15:8];
							ifmap_reg [10] <= ifmap[23:16];
							ifmap_reg [11] <= ifmap[31:24];
							data_valid[3] <= 1;
							data_valid[2] <= 1;
							data_valid[1] <= 1;
							data_valid[0] <= 1;
							ifmap_count <= ifmap_count + 4'd4;
						end
					end
				end
                else begin //new data
                    if(data_valid[3:0] == 4'd0)begin
						ifmap_reg [8] <= ifmap[7:0];
						ifmap_reg [9] <= ifmap[15:8];
						ifmap_reg [10] <= ifmap[23:16];
						ifmap_reg [11] <= ifmap[31:24];
						data_valid[3] <= 1;
						data_valid[2] <= 1;
						data_valid[1] <= 1;
						data_valid[0] <= 1;
						ifmap_count <= ifmap_count + 4'd4; 
					end
                end
				//filter
				if(filter_done == 0)begin
					if(filter_count < FILTER_SPAD_SIZE)begin
						if(filter_valid)begin
							filter_reg[filter_count] <= filter;
							filter_count <= filter_count + 9'd1;
						end
					end
				end
				if(kernel_count < 15)begin	
					if (filter_col_count < (config_S_reg - 1)) begin
						if(channel_count < (config_q_reg - 1))begin
							if((mac_filter_count < filter_count) && (mac_count < ifmap_count) && data_valid[data_count])begin	//data already prepared to READ_AND_COMPUTE
								psum[kernel_count] <= filter_reg[mac_filter_count] * ifmap_reg [mac_count] + psum[kernel_count];
								mac_count <= mac_count + 4'd1;
								mac_filter_count <= mac_filter_count + 1;
								channel_count <= channel_count + 1;
							end
						end
						else begin
							if((mac_filter_count < filter_count) && (mac_count < ifmap_count) && data_valid[data_count])begin
								psum[kernel_count] <= filter_reg[mac_filter_count] * ifmap_reg [mac_count] + psum[kernel_count];
								mac_filter_count <= mac_filter_count + 1;	
								mac_count <= mac_count + 4'd1;
								channel_count <= 0;
								filter_col_count <= filter_col_count + 1;
							end
						end	
					end
					else begin	//mac done
						if(channel_count < (config_q_reg - 1))begin
							if((mac_filter_count < filter_count) && (mac_count < ifmap_count) && data_valid[data_count])begin	//data already prepared to READ_AND_COMPUTE
								psum[kernel_count] <= filter_reg[mac_filter_count] * ifmap_reg [mac_count] + psum[kernel_count];
								mac_count <= mac_count + 4'd1;
								mac_filter_count <= mac_filter_count + 1;
								channel_count <= channel_count + 1;
							end
						end
						else begin
							if((mac_filter_count < filter_count) && (mac_count < ifmap_count) && data_valid[data_count])begin
								psum[kernel_count] <= filter_reg[mac_filter_count] * ifmap_reg [mac_count] + psum[kernel_count];
								filter_col_count <= 0;
								channel_count <= 0;
								mac_count <= 0;
								
								kernel_count <= kernel_count + 1;	//new filter new psum
								mac_filter_count <= mac_filter_count + 1;
								
							end
							
						end
					end
				end
				else begin
					if (filter_col_count < (config_S_reg - 1)) begin
						if(channel_count < (config_q_reg - 1))begin
							if((mac_filter_count < filter_count) && (mac_count < ifmap_count) && data_valid[data_count])begin	//data already prepared to READ_AND_COMPUTE
								psum[kernel_count] <= filter_reg[mac_filter_count] * ifmap_reg [mac_count] + psum[kernel_count];
								mac_count <= mac_count + 4'd1;
								mac_filter_count <= mac_filter_count + 1;
								channel_count <= channel_count + 1;
							end
						end
						else begin
							if((mac_filter_count < filter_count) && (mac_count < ifmap_count) && data_valid[data_count])begin
								psum[kernel_count] <= filter_reg[mac_filter_count] * ifmap_reg [mac_count] + psum[kernel_count];
								mac_filter_count <= mac_filter_count + 1;	
								mac_count <= mac_count + 4'd1;
								channel_count <= 0;
								filter_col_count <= filter_col_count + 1;
							end
						end	
					end
					else begin	//mac done
						if(channel_count < config_q_reg)begin
							if((mac_filter_count < filter_count) && (mac_count < ifmap_count) && data_valid[data_count])begin	//data already prepared to READ_AND_COMPUTE
								psum[kernel_count] <= filter_reg[mac_filter_count] * ifmap_reg [mac_count] + psum[kernel_count];
								mac_count <= mac_count + 4'd1;
								mac_filter_count <= mac_filter_count + 1;
								channel_count <= channel_count + 1;
							end
						end
						else begin
							// if((mac_filter_count < filter_count) && (mac_count < ifmap_count) && data_valid[data_count])begin
							// 	psum[kernel_count] <= filter_reg[mac_filter_count] * ifmap_reg [mac_count] + psum[kernel_count];
							// end
							mac_count <= 0;
							filter_col_count <= 0;
							channel_count <= 0;
							kernel_count <= 0;
							mac_filter_count <= 0;
							filter_done <= 1;
						end
						
					end	
					//ofcol_count <= ofcol_count + 6'd1;
				end
					// if(mac_count == 3'd11)begin
					// 	kernel_count <= kernel_count + 1;
					// end
				
			end
			IPSUM:begin
				if(ipsum_valid || (ipsum_count != 0))begin
					if(ipsum_count < (IPSUM_NUM-1))begin
						ipsum_count <= ipsum_count + 1;
					end	
					else begin
						ipsum_count <= 0;
					end
					if(kernel_count < (config_p - 1))begin
						kernel_count <= kernel_count + 1;
					end
					else begin
						kernel_count <= 0;
					end

				end
			end
			OUTPUT:begin
				if(opsum_ready)begin
					ipsum_count <= 0;
					//mac_count <= 4'd0;
					// opsum[7:0] <= opsum_reg[0];
					// opsum[15:8] <= opsum_reg[1];
					// opsum[23:16] <= opsum_reg[2];
					// opsum[31:24] <= opsum_reg[3];
					if(opsum_count < (OPSUM_NUM-1))begin
						opsum_count <= opsum_count + 1;
						 
					end
					else if(opsum_count == (OPSUM_NUM-1))begin	// all four opsum output
						opsum_count <= 0;
						ofcol_count <= ofcol_count + 1;
						//kernel_count <= 0;
					end
					//ipsum_count <= 0;
					//opsum_enable <= 1;	
				end
				
			end
            SHIFT:begin //shift ifmap reg by sride and channel
			
                if(stride_count < config_U_reg)begin
					if (channel_count < config_q_reg) begin
						ifmap_reg [0] <= ifmap_reg[1];
						ifmap_reg [1] <= ifmap_reg[2];
						ifmap_reg [2] <= ifmap_reg[3];
						ifmap_reg [3] <= ifmap_reg[4];
						ifmap_reg [4] <= ifmap_reg[5];
						ifmap_reg [5] <= ifmap_reg[6];
						ifmap_reg [6] <= ifmap_reg[7];
						ifmap_reg [7] <= ifmap_reg[8];
						ifmap_reg [8] <= ifmap_reg[9];
						ifmap_reg [9] <= ifmap_reg[10];
						ifmap_reg [10] <= ifmap_reg[11];
						ifmap_reg [11] <= 0;
						ifmap_count <= ifmap_count - 4'd1;
						if(channel_count == config_q_reg -1)begin
							channel_count <= 0;
							stride_count <= stride_count + 1;
						end
						else begin
							channel_count <= channel_count + 1;
						end
						data_valid <= {data_valid[10:0],1'b0};
					end

                end
				
                else begin
                    stride_count <= 0;
                    channel_count <= 0;
                end
                
            end
			default:begin
				filter_count <= 4'd0;
				ifmap_count <= 4'd0;
				mac_count <= 4'd0;
				ofcol_count <= 6'd0;
				opsum_count <= 7'd0;
                config_q_reg <= 3'd0;
                config_p_reg <= 5'd0;
                config_U_reg <= 4'd0;
                config_S_reg <= 4'd0;
                config_F_reg <= 12'd0;
                config_W_reg <= 12'd0;		
			end
		endcase
	end
end





endmodule
// 	if( == 3'd3)begin
				// 		if (mac_count == 4'd10) begin
				// 			psum <= filter_reg[mac_count] * ifmap_reg [mac_count] + psum;
							
				// 		end
				// 		else begin
				// 			psum <= filter_reg[mac_count] * ifmap_reg [mac_count] + psum;
				// 			if (mac_count == 4'd2 ||mac_count == 4'd6) begin
				// 				mac_count <= mac_count + 4'd2;
				// 			end
				// 			else begin
				// 				mac_count <= mac_count + 4'd1;
				// 			end
				// 		end
				// 	end
				// 	else begin
				// 		if (mac_count == 4'd11) begin
				// 			psum <= filter_reg[mac_count] * ifmap_reg [mac_count] + psum;
				// 			ofcol_count <= ofcol_count + 6'd1;
				// 		end
				// 		else begin
				// 			psum <= filter_reg[mac_count] * ifmap_reg [mac_count] + psum;
				// 			mac_count <= mac_count + 4'd1;
				// 		end
							
				// 	end
// if(ofcol_count == config_F_reg)begin	//done row of ofmap 
				// 	if(ifmap_valid)begin
				// 			ifmap_reg [0] <= ifmap[7:0];
				// 			ifmap_reg [1] <= ifmap[15:8];
				// 			ifmap_reg [2] <= ifmap[23:16];
				// 			ifmap_reg [3] <= ifmap[31:24];
				// 			ifmap_count <= ifmap_count + 4'd4;
				// 			ofcol_count <= 6'd0;
				// 	end
				// 	if(filter_valid)begin
				// 		filter_reg[filter_count] <= filter;
				// 		filter_count <= filter_count + 4'd1;
				// 	end
				// end
				// else begin
				// 	if(ifmap_count == 4'd8) begin
				// 		if(ifmap_valid)begin
				// 			ifmap_reg [0] <= ifmap_reg[4];
				// 			ifmap_reg [1] <= ifmap_reg[5];
				// 			ifmap_reg [2] <= ifmap_reg[6];
				// 			ifmap_reg [3] <= ifmap_reg[7];
				// 			ifmap_reg [4] <= ifmap_reg[8];
				// 			ifmap_reg [5] <= ifmap_reg[9];
				// 			ifmap_reg [6] <= ifmap_reg[10];
				// 			ifmap_reg [7] <= ifmap_reg[11];
				// 			ifmap_reg [8] <= ifmap[7:0];
				// 			ifmap_reg [9] <= ifmap[15:8];
				// 			ifmap_reg [10] <= ifmap[23:16];
				// 			ifmap_reg [11] <= ifmap[31:24];
				// 			ifmap_count <= ifmap_count + 4'd4;
							
				// 		end
				// 	end
				// end