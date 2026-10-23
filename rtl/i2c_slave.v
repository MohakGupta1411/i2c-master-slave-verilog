
module i2c_slave(
    input scl,
    inout sda
);

    parameter [6:0] SLAVE_ADDRESS = 7'b1010111;

    localparam IDLE       = 3'd0,
               ADDRESS    = 3'd1,
               SLAVE_ACK  = 3'd2,
               WRITE_DATA = 3'd3,
               WRITE_ACK  = 3'd4,
               READ_DATA  = 3'd5,
               MASTER_ACK = 3'd6;

    reg [2:0] state = IDLE;
    reg [7:0] data_reg = 8'hCD;
    reg [7:0] shift_reg = 0;
    reg [7:0] tx_reg = 0;
    reg [6:0] address_reg = 0;
    reg rw_reg = 0;
    reg [2:0] bit_count = 7;
    reg sda_drive_low = 0;

    assign sda = sda_drive_low ? 1'b0 : 1'bz;

    // START condition: SDA falls while SCL is high.
    always @(negedge sda) begin
        if (scl === 1'b1) begin
            state <= ADDRESS;
            bit_count <= 7;
            shift_reg <= 0;
            sda_drive_low <= 0;
        end
    end

    // STOP condition: SDA rises while SCL is high.
    always @(posedge sda) begin
        if (scl === 1'b1) begin
            state <= IDLE;
            bit_count <= 7;
            sda_drive_low <= 0;
        end
    end

    // Receive bits on rising SCL edges.
    always @(posedge scl) begin
        case (state)

            IDLE: begin
                sda_drive_low <= 0;
            end

            ADDRESS: begin
                shift_reg[bit_count] <= sda;

                if (bit_count == 0) begin
                    address_reg <= shift_reg[7:1];
                    rw_reg <= sda;
                    state <= SLAVE_ACK;
                    bit_count <= 7;
                end
                else begin
                    bit_count <= bit_count - 1'b1;
                end
            end

            SLAVE_ACK: begin
                if (address_reg == SLAVE_ADDRESS) begin
                    if (rw_reg == 0) begin
                        state <= WRITE_DATA;
                        bit_count <= 7;
                        shift_reg <= 0;
                    end
                    else begin
                        state <= READ_DATA;
                        tx_reg <= data_reg;
                        bit_count <= 7;
                    end
                end
                else begin
                    state <= IDLE;
                end
            end

            WRITE_DATA: begin
                shift_reg[bit_count] <= sda;

                if (bit_count == 0) begin
                    data_reg <= {shift_reg[7:1], sda};
                    state <= WRITE_ACK;
                    bit_count <= 7;
                end
                else begin
                    bit_count <= bit_count - 1'b1;
                end
            end

            WRITE_ACK: begin
                state <= IDLE;
                sda_drive_low <= 0;
            end

            READ_DATA: begin
                if (bit_count == 0) begin
                    state <= MASTER_ACK;
                    bit_count <= 7;
                    sda_drive_low <= 0;
                end
                else begin
                    bit_count <= bit_count - 1'b1;
                end
            end

            MASTER_ACK: begin
                state <= IDLE;
                sda_drive_low <= 0;
            end

            default: begin
                state <= IDLE;
                sda_drive_low <= 0;
            end

        endcase
    end

    // Prepare ACK/data on falling SCL edges.
    always @(negedge scl) begin
        case (state)

            SLAVE_ACK:
                sda_drive_low <= (address_reg == SLAVE_ADDRESS);

            WRITE_ACK:
                sda_drive_low <= 1'b1;

            READ_DATA:
                sda_drive_low <= ~tx_reg[bit_count];

            default:
                sda_drive_low <= 1'b0;

        endcase
    end

endmodule
