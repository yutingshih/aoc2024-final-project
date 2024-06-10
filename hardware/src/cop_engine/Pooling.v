module Pooling#(
    parameter DATA_BITWIDTH = 8,
    parameter INFO_BITWIDTH = 8,
    parameter ADDRESS_BITWIDTH = 12
)
(
    input clk,
    input rst,
    input enable, // work when enable
    /* set info */
    input set_info, // set_info before start
    input [1:0] kernel_size, // 2x2 or 3x3
    input [1:0] pooling_type, // Pooling type: (0) MaxPooling2D (1) Average Pooling2D
    /* Data flow */
    input [ADDRESS_BITWIDTH-1:0] e_in, // input height (max 56)
    input [ADDRESS_BITWIDTH-1:0] f_in, // input width  (max 256)
    input [DATA_BITWIDTH-1:0] data_in, // input data
    output logic write_ready, // ready to outside
    input write_valid,  // valid means data is prepared

    input [ADDRESS_BITWIDTH-1:0] e_out, // output height (max 56)
    input [ADDRESS_BITWIDTH-1:0] f_out, // output width  (max 256)
    output logic [DATA_BITWIDTH-1:0] data_out,    // output data
    output logic read_valid,  // valid means data is prepared
    input read_ready    // ready means data is read from outside
);

   // Parameters
    localparam MAX_KERNEL_SIZE = 3;
    localparam MAX_HEIGHT = 56;
    localparam MAX_WIDTH = 256;

    // Internal variables
    reg [DATA_BITWIDTH-1:0] buffer [0:MAX_HEIGHT-1][0:MAX_KERNEL_SIZE-1];
    reg [ADDRESS_BITWIDTH-1:0] col_counter;
    reg [ADDRESS_BITWIDTH-1:0] row_counter;
    reg [ADDRESS_BITWIDTH-1:0] buffer_col_count;
    reg [ADDRESS_BITWIDTH-1:0] buffer_row_count;    //unused
    reg [DATA_BITWIDTH + 14:0] sum;    //log(56*256) = 14
    reg [ADDRESS_BITWIDTH-1:0] pixel_count;
    reg [1:0] current_pooling_type;
    reg [1:0] current_kernel_size;

    // State Machine
    typedef enum {
        IDLE,
        COLLECTING,
        POOLING,
        OUTPUT
    } state_t;

    state_t state;

    // State Machine Transitions
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            col_counter <= 0;
            row_counter <= 0;
            buffer_col_count <= 0;
            //buffer_row_count <= 0;
            sum <= 0;
            pixel_count <= 0;
            data_out <= 0;
            write_ready <= 1;
            read_valid <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (enable && set_info) begin
                        current_pooling_type <= pooling_type;
                        current_kernel_size <= kernel_size;
                        state <= COLLECTING;
                    end
                end
                COLLECTING: begin
                    if (write_valid && write_ready) begin
                        //  MaxPooling
                        if (current_pooling_type == 0) begin
                            // put data_in into buffer
                            buffer[row_counter][col_counter % current_kernel_size] <= data_in;
                            row_counter <= row_counter + 1;
                            //buffer_row_count <= buffer_row_count + 1;
                            if (row_counter == e_in) begin
                                row_counter <= 0;
                                //buffer_row_count <= 0;
                                col_counter <= col_counter + 1;
                                //buffer_col_count <= buffer_col_count + 1;
                            end

                            // go pooling
                            if(col_counter == current_kernel_size - 1) begin
                                if (row_counter % current_kernel_size == current_kernel_size - 1) begin
                                    state <= POOLING;
                                end
                                else if(row_counter == e_in) begin
                                    state <= POOLING;
                                end
                            end
                            else if (col_counter == f_in) begin
                                if (row_counter % current_kernel_size == current_kernel_size - 1) begin
                                    state <= POOLING;
                                end
                            end
                        end
                        

                        // Global Average Pooling
                        else if (current_pooling_type == 1) begin
                            sum <= sum + data_in;
                            pixel_count <= pixel_count + 1;
                            if (pixel_count == e_in*f_in) begin
                                state <= POOLING;
                            end
                        end                        
                    end
                end
                POOLING: begin
                    // MaxPooling
                    if (current_pooling_type == 0) begin                        
                        data_out <= buffer[row_counter][col_counter % current_kernel_size];
                        for (int i = 0; i <= row_counter % current_kernel_size; i = i + 1) begin
                            for (int j = 0; j <= col_counter % current_kernel_size; j = j + 1) begin
                                if (buffer[row_counter - i][col_counter - j] > data_out) begin
                                    data_out <= buffer[row_counter - i][col_counter - j];
                                end
                            end
                        end
                    end
                    // Global Average Pooling
                    else if (current_pooling_type == 1) begin                        
                        data_out <= sum / pixel_count;
                    end
                    read_valid <= 1;
                    state <= OUTPUT;
                end
                OUTPUT: begin
                    if (read_ready && read_valid) begin
                        read_valid <= 0;
                        if (row_counter == e_in) begin
                            row_counter <= 0;
                            col_counter <= 0;
                            state <= IDLE;
                        end
                        else begin
                            state <= COLLECTING;
                        end
                    end
                end
            endcase
        end
    end

endmodule