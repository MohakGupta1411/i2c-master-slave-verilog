module i2c_slave(
    input scl,
    inout sda
);

    parameter [6:0] SLAVE_ADDRESS = 7'b1010111;

    // FSM states
    localparam IDLE       = 3'd0,
               ADDRESS    = 3'd1,
               SLAVE_ACK  = 3'd2,
               WRITE_DATA = 3'd3,
               WRITE_ACK  = 3'd4,
               READ_DATA  = 3'd5,
               MASTER_ACK = 3'd6;

    reg [2:0] state = IDLE;

    reg [7:0] data_reg = 8'hCD;
    reg [7:0] shift_reg = 8'h00;
    reg [7:0] tx_reg = 8'h00;

    reg [6:0] address_reg = 7'h00;
    reg rw_reg = 1'b0;
    reg [2:0] bit_count = 3'd7;

    reg sda_drive_low = 1'b0;

    // Open-drain SDA
    assign sda = sda_drive_low ? 1'b0 : 1'bz;

    // Detect START condition
    always @(negedge sda) begin
        if (scl === 1'b1) begin
            state         <= ADDRESS;
            bit_count     <= 3'd7;
            shift_reg     <= 8'h00;
            sda_drive_low <= 1'b0;
        end
    end

    // Detect STOP condition
    always @(posedge sda) begin
        if (scl === 1'b1) begin
            state         <= IDLE;
            bit_count     <= 3'd7;
            sda_drive_low <= 1'b0;
        end
    end

    // Receive address/data on rising SCL edges
    always @(posedge scl) begin
        case (state)

            IDLE: begin
                sda_drive_low <= 1'b0;
            end

            // Receive address and R/W bit, MSB first
            ADDRESS: begin
                shift_reg[bit_count] <= sda;

                if (bit_count == 0) begin
                    address_reg <= shift_reg[7:1];
                    rw_reg      <= sda;

                    state       <= SLAVE_ACK;
                    bit_count   <= 3'd7;
                end
                else begin
                    bit_count <= bit_count - 1'b1;
                end
            end

            // Check address and select operation
            SLAVE_ACK: begin
                if (address_reg == SLAVE_ADDRESS) begin
                    if (rw_reg == 1'b0) begin
                        state     <= WRITE_DATA;
                        bit_count <= 3'd7;
                        shift_reg <= 8'h00;
                    end
                    else begin
                        state     <= READ_DATA;
                        tx_reg    <= data_reg;
                        bit_count <= 3'd7;
                    end
                end
                else begin
                    state <= IDLE;
                end
            end

            // Receive one data byte
            WRITE_DATA: begin
                shift_reg[bit_count] <= sda;

                if (bit_count == 0) begin
                    data_reg  <= {shift_reg[7:1], sda};
                    state     <= WRITE_ACK;
                    bit_count <= 3'd7;
                end
                else begin
                    bit_count <= bit_count - 1'b1;
                end
            end

            // Complete the data ACK clock
            WRITE_ACK: begin
                state <= IDLE;
            end

            // Transmit data, MSB first
            READ_DATA: begin
                if (bit_count == 0) begin
                    state     <= MASTER_ACK;
                    bit_count <= 3'd7;
                end
                else begin
                    bit_count <= bit_count - 1'b1;
                end
            end

            // Wait for the master's ACK/NACK
            MASTER_ACK: begin
                state <= IDLE;
            end

            default: begin
                state         <= IDLE;
                sda_drive_low <= 1'b0;
            end

        endcase
    end

    // Set SDA on falling SCL edges
    always @(negedge scl) begin
        case (state)

            SLAVE_ACK: begin
                // ACK only if the address matches
                sda_drive_low <= (address_reg == SLAVE_ADDRESS);
            end

            WRITE_ACK: begin
                sda_drive_low <= 1'b1;
            end

            READ_DATA: begin
                sda_drive_low <= ~tx_reg[bit_count];
            end

            MASTER_ACK: begin
                sda_drive_low <= 1'b0;
            end

            default: begin
                sda_drive_low <= 1'b0;
            end

        endcase
    end

endmodule
