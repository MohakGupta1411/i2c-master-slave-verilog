
`timescale 1ns/1ns

module i2c_tb;

    reg clk;
    reg areset;
    reg [6:0] addr;
    reg [7:0] data_in;
    reg rw;
    reg enable;

    wire scl;
    tri1 sda;
    wire [7:0] data_out;
    wire busy;

    integer tests_passed;
    integer tests_failed;

    // Instantiate I2C master
    i2c_master master(
        .clk(clk),
        .areset(areset),
        .addr(addr),
        .data_in(data_in),
        .rw(rw),
        .enable(enable),
        .scl(scl),
        .sda(sda),
        .data_out(data_out),
        .busy(busy)
    );

    // Instantiate I2C slave
    i2c_slave slave(
        .scl(scl),
        .sda(sda)
    );

    // 100 MHz system clock
    always #5 clk = ~clk;

    // Write one byte, read it back, and compare
    task test_write_read;
        input [7:0] test_byte;
        begin
            $display("");
            $display("----------------------------------------");
            $display("Testing write/read data = 0x%02h", test_byte);

            // WRITE transaction
            @(negedge clk);
            addr = 7'b1010111;
            data_in = test_byte;
            rw = 1'b0;
            enable = 1'b1;

            @(negedge clk);
            enable = 1'b0;

            wait (busy === 1'b1);
            wait (busy === 1'b0);
            #100;

            // READ transaction
            @(negedge clk);
            addr = 7'b1010111;
            rw = 1'b1;
            enable = 1'b1;

            @(negedge clk);
            enable = 1'b0;

            wait (busy === 1'b1);
            wait (busy === 1'b0);
            #100;

            if (data_out === test_byte) begin
                $display("PASS: expected=0x%02h, received=0x%02h",
                         test_byte, data_out);
                tests_passed = tests_passed + 1;
            end
            else begin
                $display("FAIL: expected=0x%02h, received=0x%02h",
                         test_byte, data_out);
                tests_failed = tests_failed + 1;
            end
        end
    endtask

    // Main test sequence
    initial begin
        clk = 1'b0;
        areset = 1'b1;
        addr = 7'b1010111;
        data_in = 8'h00;
        rw = 1'b0;
        enable = 1'b0;

        tests_passed = 0;
        tests_failed = 0;

        // Reset
        #100;
        areset = 1'b0;
        #100;

        // Four valid-address write/read tests
        test_write_read(8'hAA);
        test_write_read(8'h3C);
        test_write_read(8'h55);
        test_write_read(8'h00);

        // Incorrect-address test
        $display("");
        $display("----------------------------------------");
        $display("Testing incorrect slave address");

        @(negedge clk);
        addr = 7'b1010001;  // Deliberately incorrect address
        rw = 1'b0;
        data_in = 8'hA5;
        enable = 1'b1;

        @(negedge clk);
        enable = 1'b0;

        // Wait for this transaction to start and finish
        wait (busy === 1'b1);
        wait (busy === 1'b0);
        #100;

        // Check whether the master detected the missing address ACK.
        if (master.ack_error === 1'b1) begin
            $display("PASS: Incorrect address detected (NACK).");
            tests_passed = tests_passed + 1;
        end
        else begin
            $display("FAIL: Incorrect address was not detected.");
            tests_failed = tests_failed + 1;
        end

        // Final summary
        $display("");
        $display("========================================");
        $display("I2C TEST SUMMARY");
        $display("Tests passed: %0d", tests_passed);
        $display("Tests failed: %0d", tests_failed);
        $display("========================================");

        if ((tests_passed == 5) && (tests_failed == 0))
            $display("OVERALL RESULT: PASS");
        else
            $display("OVERALL RESULT: FAIL");

        $finish;
    end

    // Global simulation timeout
    initial begin
        #5000000;
        $display("FAIL: Global simulation timeout.");
        $finish;
    end

endmodule
