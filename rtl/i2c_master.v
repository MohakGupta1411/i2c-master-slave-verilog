
module i2c_master(
    input clk,
    input areset,
    input [6:0] addr,
    input [7:0] data_in,
    input enable,
    input rw,
    output reg [7:0] data_out,
    output busy,
    output reg scl,
    inout sda
);

parameter integer HALF_PERIOD = 500;

localparam IDLE       = 4'd0,
           START_A    = 4'd1,
           START_B    = 4'd2,
           ADDR_SETUP = 4'd3,
           ADDR_HIGH  = 4'd4,
           ACK_SETUP  = 4'd5,
           ACK_HIGH   = 4'd6,
           DATA_SETUP = 4'd7,
           DATA_HIGH  = 4'd8,
           MACK_SETUP = 4'd9,
           MACK_HIGH  = 4'd10,
           STOP_A     = 4'd11,
           STOP_B     = 4'd12,
           STOP_C     = 4'd13,
           DONE       = 4'd14;

reg [3:0] state;
reg [9:0] divider;
reg [2:0] bit_count;
reg [7:0] address_byte;
reg [7:0] saved_data;
reg saved_rw;
reg sda_drive_low;
reg [7:0] rx_shift;

// This signal records whether the address was NACKed.
reg ack_error;

assign sda = sda_drive_low ? 1'b0 : 1'bz;
assign busy = (state != IDLE);

always @(posedge clk or posedge areset) begin
    if (areset) begin
        state         <= IDLE;
        divider       <= 0;
        bit_count     <= 7;
        address_byte  <= 0;
        saved_data    <= 0;
        saved_rw      <= 0;
        sda_drive_low <= 0;
        scl           <= 1;
        rx_shift      <= 0;
        data_out      <= 0;
        ack_error     <= 0;
    end
    else if (state == IDLE) begin
        divider       <= 0;
        scl           <= 1;
        sda_drive_low <= 0;

        if (enable) begin
            address_byte <= {addr, rw};
            saved_data   <= data_in;
            saved_rw     <= rw;
            bit_count    <= 7;
            rx_shift     <= 0;
            ack_error    <= 0;
            state        <= START_A;
        end
    end
    else if (divider == HALF_PERIOD - 1) begin
        divider <= 0;

        case (state)

            START_A: begin
                scl           <= 1;
                sda_drive_low <= 1;
                state         <= START_B;
            end

            START_B: begin
                scl           <= 0;
                sda_drive_low <= 1;
                state         <= ADDR_SETUP;
            end

            ADDR_SETUP: begin
                scl           <= 0;
                sda_drive_low <= ~address_byte[bit_count];
                state         <= ADDR_HIGH;
            end

            ADDR_HIGH: begin
                scl <= 1;

                if (bit_count == 0)
                    state <= ACK_SETUP;
                else begin
                    bit_count <= bit_count - 1'b1;
                    state     <= ADDR_SETUP;
                end
            end

            ACK_SETUP: begin
                scl           <= 0;
                sda_drive_low <= 0;
                state         <= ACK_HIGH;
            end

            ACK_HIGH: begin
                scl <= 1;

                // ACK is SDA = 0; NACK is SDA = 1.
                if (sda !== 1'b0) begin
                    ack_error <= 1;
                    state     <= STOP_A;
                end
                else begin
                    bit_count <= 7;
                    state     <= DATA_SETUP;
                end
            end

            DATA_SETUP: begin
                scl <= 0;

                if (saved_rw == 0)
                    sda_drive_low <= ~saved_data[bit_count];
                else
                    sda_drive_low <= 0;

                state <= DATA_HIGH;
            end

            DATA_HIGH: begin
                scl <= 1;

                if (saved_rw == 1)
                    rx_shift[bit_count] <= sda;

                if (bit_count == 0) begin
                    if (saved_rw == 1)
                        data_out <= {rx_shift[7:1], sda};

                    state <= MACK_SETUP;
                end
                else begin
                    bit_count <= bit_count - 1'b1;
                    state     <= DATA_SETUP;
                end
            end

            MACK_SETUP: begin
                scl           <= 0;
                sda_drive_low <= 0;
                state         <= MACK_HIGH;
            end

            MACK_HIGH: begin
                scl   <= 1;
                state <= STOP_A;
            end

            STOP_A: begin
                scl           <= 0;
                sda_drive_low <= 1;
                state         <= STOP_B;
            end

            STOP_B: begin
                scl           <= 1;
                sda_drive_low <= 1;
                state         <= STOP_C;
            end

            STOP_C: begin
                scl           <= 1;
                sda_drive_low <= 0;
                state         <= DONE;
            end

            DONE: begin
                scl           <= 1;
                sda_drive_low <= 0;
                state         <= IDLE;
            end

            default: begin
                scl           <= 1;
                sda_drive_low <= 0;
                state         <= IDLE;
            end

        endcase
    end
    else begin
        divider <= divider + 1'b1;
    end
end

endmodule
