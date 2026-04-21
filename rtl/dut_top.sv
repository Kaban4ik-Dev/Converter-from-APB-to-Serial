// ============================================================================
// APB to Serial Interface Converter (Master on both sides)
// Serial Interface: 1-bit data, 1-bit control, 8-bit address, 8-bit data
// APB clock is 3x faster than serial bit clock
// ============================================================================

module apb_to_serial_converter (
    // APB Slave Interface (input from APB master)
    input  logic        PCLK,           // APB clock (3x faster than serial bit clock)
    input  logic        PRESETn,        // Active-low reset
    input  logic [31:0] PADDR,          // APB address bus (32-bit)
    input  logic [2:0]  PPROT,          // Protection type (secure/privileged/instruction)
    input  logic        PSEL,           // APB select signal (this slave is selected)
    input  logic        PENABLE,        // APB enable signal (2nd phase of transfer)
    input  logic        PWRITE,         // 1=write, 0=read
    input  logic [31:0] PWDATA,         // APB write data bus
    input  logic [3:0]  PSTRB,          // Write strobes (one per byte lane)
    output logic        PREADY,         // APB ready signal (slave can extend transfer)
    output logic [31:0] PRDATA,         // APB read data bus
    output logic        PSLVERR,        // APB slave error response
    
    // Serial Interface (Master output)
    output logic        serial_clk,     // Serial bit clock (PCLK / 3)
    output logic        serial_data,    // Serial data line (output from converter)
    output logic        serial_ctrl,    // Control line: 0=command/address/data, 1=idle/response
    input  logic        serial_ready,   // Serial slave ready to accept transaction
    input  logic        serial_response // Serial slave response line (for read data)
);

    // ========================================================================
    // Enumeration type definitions for Finite State Machines
    // ========================================================================
    
    // APB FSM states (2 bits needed for 4 states)
    // APB protocol has 3 main states: IDLE, SETUP, ACCESS
    // WAIT_RESPONSE is added for handling serial read response delays
    typedef enum logic [1:0] {
        APB_IDLE,           // No active transfer, waiting for PSEL assertion
        APB_SETUP,          // Setup phase: address and control signals are driven
        APB_ACCESS,         // Access phase: PENABLE asserted, data transferred
        APB_WAIT_RESPONSE   // Extra state for waiting serial read response
    } apb_state_t;
    
    // Serial FSM states (3 bits needed for up to 8 states)
    // Implements serial protocol with command, address, and data phases
    typedef enum logic [2:0] {
        SERIAL_IDLE,        // Serial interface idle, no transaction in progress
        SERIAL_WAIT_READY,  // Waiting for serial slave to assert serial_ready
        SERIAL_SEND_CMD,    // Sending command byte (read=1/write=0)
        SERIAL_SEND_ADDR,   // Sending 8-bit address (LSB first)
        SERIAL_SEND_DATA,   // Sending 8-bit write data (write operation only)
        SERIAL_RECV_DATA,   // Receiving 8-bit read data (read operation only)
        SERIAL_DONE         // Transaction complete, return to idle
    } serial_state_t;
    
    // ========================================================================
    // Signal declarations
    // ========================================================================
    
    // APB FSM registers and signals
    apb_state_t apb_state;          // Current APB state
    apb_state_t apb_next;           // Next APB state (combinatorial logic)
    
    // APB latched signals (captured during SETUP phase)
    logic [31:0] addr_reg;          // Latched APB address
    logic [31:0] wdata_reg;         // Latched APB write data
    logic [2:0]  prot_reg;          // Latched protection signals
    logic        write_reg;         // Latched write enable (1=write, 0=read)
    logic [3:0]  strb_reg;          // Latched write strobes
    
    // APB read data assembly
    logic [31:0] rdata_reg;         // Assembled read data (from serial bytes)
    
    // APB transaction control flags
    logic transfer_complete;        // Asserted when serial transaction finishes
    logic transfer_error;           // Asserted when serial error occurs
    
    // Serial FSM registers and signals
    serial_state_t serial_state;    // Current serial state
    serial_state_t serial_next;     // Next serial state (combinatorial logic)
    
    // Serial data buffers
    logic [7:0] addr_ser;           // 8-bit address for serial transmission
    logic [7:0] data_ser_tx;        // 8-bit data for serial transmission (write)
    logic [7:0] data_ser_rx;        // 8-bit data received from serial (read)
    
    // Serial bit counter (0-7 for 8 bits per byte)
    logic [2:0] bit_counter;        // Current bit position being sent/received
    
    // Serial clock divider (PCLK is 3x faster than serial bit clock)
    logic [2:0] clk_div_counter;    // Counter for dividing PCLK by 3
    logic       serial_clk_en;      // Enable signal for serial clock edge detection
    logic       serial_clk_edge;    // Pulse on rising edge of serial_clk
    
    // Serial transaction control
    logic start_serial_tx;          // Trigger to start serial transaction
    logic serial_tx_busy;           // Serial transaction in progress
    logic serial_tx_done;           // Serial transaction completed
    logic rx_valid;                 // Received data is valid
    logic [7:0] rx_data;            // Received read data byte
    
    // Operation type flags
    logic read_operation;           // Current operation is read (PWRITE=0)
    logic write_operation;          // Current operation is write (PWRITE=1)
    
    // ========================================================================
    // APB Slave Interface FSM - Sequential Logic (State Register)
    // ========================================================================
    // This always block updates the current state and registers on clock edge
    // All APB signals are sampled on the rising edge of PCLK
    // ========================================================================
    always_ff @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            // Reset condition: active-low reset initializes all registers to zero
            apb_state <= APB_IDLE;          // Return to idle state
            addr_reg <= 32'b0;              // Clear latched address
            wdata_reg <= 32'b0;             // Clear latched write data
            prot_reg <= 3'b0;               // Clear protection signals
            write_reg <= 1'b0;              // Default to read operation
            strb_reg <= 4'b0;               // Clear write strobes
            rdata_reg <= 32'b0;             // Clear read data register
            transfer_complete <= 1'b0;      // No pending completion flag
            transfer_error <= 1'b0;         // No pending error flag
            
        end else begin
            // Normal operation on rising clock edge
            apb_state <= apb_next;          // Update APB FSM state
            
            // Latch address and control signals during SETUP phase
            // Condition: PSEL is high, PENABLE is low (setup phase), and currently idle
            // This captures the transaction parameters before ACCESS phase
            if (PSEL && !PENABLE && apb_state == APB_IDLE) begin
                addr_reg <= PADDR;          // Capture address bus
                wdata_reg <= PWDATA;         // Capture write data (valid for writes)
                prot_reg <= PPROT;           // Capture protection type
                write_reg <= PWRITE;         // Capture direction (read/write)
                strb_reg <= PSTRB;           // Capture write strobes (byte enables)
            end
            
            // Clear completion flag after one cycle (pulse behavior)
            if (transfer_complete) begin
                transfer_complete <= 1'b0;   // De-assert completion flag
            end
            
            // Clear error flag after one cycle (pulse behavior)
            if (transfer_error) begin
                transfer_error <= 1'b0;      // De-assert error flag
            end
            
            // Assemble read data from serial bytes when transaction completes
            // This example uses a simplified assembly (assumes single byte read)
            // For multi-byte reads, address mapping and byte lane selection needed
            if (apb_next == APB_ACCESS && serial_state == SERIAL_DONE) begin
                if (read_operation) begin
                    // Assemble read data: received byte goes to appropriate byte lane
                    // Simplified: place received byte in lower 8 bits
                    // Full implementation would use address[1:0] for lane selection
                    rdata_reg <= {24'b0, rx_data};  // Zero-extend to 32 bits
                end
            end
        end
    end
    
    // ========================================================================
    // APB Slave Interface FSM - Combinatorial Logic (Next State and Outputs)
    // ========================================================================
    // This always block determines the next state based on current state and inputs
    // Also generates APB output signals: PREADY, PSLVERR, PRDATA
    // ========================================================================
    always_comb begin
        // Default assignments (prevents inferred latches)
        apb_next = apb_state;           // Stay in current state by default
        PREADY = 1'b0;                  // Default: not ready (wait state)
        PSLVERR = 1'b0;                 // Default: no error
        PRDATA = rdata_reg;             // Output latched read data
        start_serial_tx = 1'b0;         // Default: don't start serial transaction
        read_operation = 1'b0;          // Default: not read
        write_operation = 1'b0;         // Default: not write
        
        // State machine logic
        case (apb_state)
            APB_IDLE: begin
                // IDLE state: waiting for APB master to select this slave
                // Transition to SETUP when PSEL is asserted
                if (PSEL) begin
                    apb_next = APB_SETUP;   // Move to setup phase
                end
            end
            
            APB_SETUP: begin
                // SETUP state: address and control signals are valid
                // APB protocol requires exactly one cycle in SETUP state
                // Always transition to ACCESS state on next clock
                apb_next = APB_ACCESS;
                
                // Trigger serial transaction start when moving to ACCESS
                // This is detected in the calling code via state transition
                // The actual trigger is set below based on apb_next condition
            end
            
            APB_ACCESS: begin
                // ACCESS state: PENABLE is high, data transfer in progress
                // Wait for serial transaction to complete
                if (serial_state == SERIAL_DONE) begin
                    // Serial transaction finished, complete the APB transfer
                    PREADY = 1'b1;              // Signal APB master we're ready
                    if (transfer_error) begin
                        PSLVERR = 1'b1;         // Report error if serial failed
                    end
                    apb_next = APB_IDLE;        // Return to idle state
                end else begin
                    // Serial transaction still in progress, insert wait states
                    PREADY = 1'b0;              // Extend APB transfer
                    apb_next = APB_ACCESS;      // Stay in ACCESS state
                end
            end
            
            APB_WAIT_RESPONSE: begin
                // WAIT_RESPONSE state: additional wait for serial read response
                // This state can be used if serial read requires extra delay
                apb_next = APB_ACCESS;          // Return to ACCESS to complete
            end
            
            default: begin
                // Safety: if unknown state, return to IDLE
                apb_next = APB_IDLE;
            end
        endcase
        
        // Start serial transaction when transitioning from SETUP to ACCESS
        // This detection works because apb_next is set to ACCESS above
        if (apb_state == APB_SETUP && apb_next == APB_ACCESS) begin
            start_serial_tx = 1'b1;             // Pulse to start serial FSM
            read_operation = ~write_reg;        // Read if PWRITE=0
            write_operation = write_reg;        // Write if PWRITE=1
        end
    end
    
    // ========================================================================
    // Serial Clock Generation (Divide PCLK by 3)
    // ========================================================================
    // Serial interface operates at 1/3 the frequency of APB clock
    // This block generates serial_clk and detects its rising edge
    // ========================================================================
    always_ff @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            // Reset: clear all clock generation registers
            clk_div_counter <= 3'b0;        // Reset divider counter
            serial_clk <= 1'b0;              // Initialize serial clock to low
            serial_clk_en <= 1'b0;           // Disable clock edge detection
            serial_clk_edge <= 1'b0;         // Clear edge detection flag
            
        end else begin
            // Default: clear edge detection flag each cycle
            serial_clk_edge <= 1'b0;
            
            // Only generate clock when serial interface is active
            if (serial_state != SERIAL_IDLE || start_serial_tx) begin
                // Divide by 3 counter: counts 0,1,2 then wraps
                if (clk_div_counter == 3'd2) begin
                    clk_div_counter <= 3'b0;     // Wrap around after 3 cycles
                    serial_clk <= ~serial_clk;   // Toggle serial clock
                    serial_clk_en <= 1'b1;       // Enable for one PCLK cycle
                    
                    // Detect rising edge: clock transitions from 0 to 1
                    if (serial_clk == 1'b0) begin
                        serial_clk_edge <= 1'b1;  // Rising edge detected
                    end
                end else begin
                    clk_div_counter <= clk_div_counter + 1'b1;  // Increment counter
                    serial_clk_en <= 1'b0;       // Not a clock edge cycle
                end
            end else begin
                // Idle: hold clock low and reset counter
                clk_div_counter <= 3'b0;
                serial_clk <= 1'b0;
                serial_clk_en <= 1'b0;
            end
        end
    end
    
    // ========================================================================
    // Serial Interface Master FSM - Sequential Logic (State Register)
    // ========================================================================
    // This always block implements the serial protocol state machine
    // Handles command, address, data phases for both read and write operations
    // ========================================================================
    always_ff @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            // Reset: initialize all serial FSM registers
            serial_state <= SERIAL_IDLE;        // Start in idle state
            addr_ser <= 8'b0;                   // Clear address buffer
            data_ser_tx <= 8'b0;                // Clear transmit buffer
            data_ser_rx <= 8'b0;                // Clear receive buffer
            bit_counter <= 3'b0;                // Reset bit position counter
            serial_tx_busy <= 1'b0;             // Not busy after reset
            serial_tx_done <= 1'b0;             // Clear completion flag
            rx_valid <= 1'b0;                   // No valid received data
            rx_data <= 8'b0;                    // Clear received data register
            transfer_complete <= 1'b0;          // Clear transfer complete flag
            transfer_error <= 1'b0;             // Clear error flag
            serial_data <= 1'b1;                // Idle high (pull-up behavior)
            serial_ctrl <= 1'b1;                // Idle high (control inactive)
            
        end else begin
            // Clear pulse signals each cycle
            serial_tx_done <= 1'b0;             // Clear completion pulse
            rx_valid <= 1'b0;                   // Clear valid data pulse
            
            // Start new serial transaction when triggered
            if (start_serial_tx) begin
                serial_state <= SERIAL_WAIT_READY;   // Move to wait for slave
                serial_tx_busy <= 1'b1;              // Mark as busy
                
                // Prepare serial data from latched APB signals
                // Use lower 8 bits of APB address (supports up to 256 peripherals)
                addr_ser <= addr_reg[7:0];
                
                // For write operations: prepare data to send
                // Simplified: use lower 8 bits of PWDATA
                // Full implementation would use address[1:0] and PSTRB for byte selection
                if (write_reg) begin
                    data_ser_tx <= wdata_reg[7:0];   // Take first byte of write data
                end else begin
                    data_ser_tx <= 8'b0;              // No data to send for reads
                end
                
                // Reset bit counter for new byte transmission
                bit_counter <= 3'b0;
                
                // Set default line states (will be overridden in state machine)
                serial_data <= 1'b1;
                serial_ctrl <= 1'b1;
                transfer_error <= 1'b0;              // Clear any previous error
            end
            
            // Serial FSM state transitions (clocked at PCLK, but actions occur at serial_clk_edge)
            case (serial_state)
                // --------------------------------------------------------------------
                // WAIT_READY state: Wait for serial slave to assert ready signal
                // --------------------------------------------------------------------
                SERIAL_WAIT_READY: begin
                    serial_ctrl <= 1'b1;             // Control high (idle/receive mode)
                    // Check if slave is ready on rising edge of serial clock
                    if (serial_ready && serial_clk_edge) begin
                        serial_state <= SERIAL_SEND_CMD;   // Proceed to send command
                        bit_counter <= 3'b0;                // Reset bit counter
                    end
                end
                
                // --------------------------------------------------------------------
                // SEND_CMD state: Transmit command byte (1 bit command + 7 reserved bits)
                // Command: 1 = read operation, 0 = write operation
                // --------------------------------------------------------------------
                SERIAL_SEND_CMD: begin
                    serial_ctrl <= 1'b0;             // Control low = command/address/data phase
                    if (serial_clk_edge) begin
                        // Send command bit on data line
                        // Bit 7 (MSB) = 1 for read, 0 for write
                        serial_data <= (write_operation ? 1'b0 : 1'b1);
                        
                        if (bit_counter == 3'd0) begin
                            // First bit sent, move to next bit position
                            bit_counter <= bit_counter + 1'b1;
                        end else begin
                            // Command byte complete (only 1 bit used, but protocol expects byte)
                            // Move to address transmission
                            serial_state <= SERIAL_SEND_ADDR;
                            bit_counter <= 3'b0;
                        end
                    end
                end
                
                // --------------------------------------------------------------------
                // SEND_ADDR state: Transmit 8-bit address (LSB first per typical serial)
                // --------------------------------------------------------------------
                SERIAL_SEND_ADDR: begin
                    serial_ctrl <= 1'b0;             // Control low during address phase
                    if (serial_clk_edge) begin
                        // Send address bits from MSB to LSB (bit 7 to bit 0)
                        // Alternative: LSB first would use addr_ser[bit_counter]
                        serial_data <= addr_ser[7 - bit_counter];
                        
                        if (bit_counter == 3'd7) begin
                            // All 8 bits transmitted
                            // Next state depends on operation type
                            if (write_operation) begin
                                serial_state <= SERIAL_SEND_DATA;   // Write: send data
                            end else begin
                                serial_state <= SERIAL_RECV_DATA;   // Read: receive data
                            end
                            bit_counter <= 3'b0;
                        end else begin
                            bit_counter <= bit_counter + 1'b1;      // Next bit position
                        end
                    end
                end
                
                // --------------------------------------------------------------------
                // SEND_DATA state: Transmit 8-bit data (write operation only)
                // --------------------------------------------------------------------
                SERIAL_SEND_DATA: begin
                    serial_ctrl <= 1'b0;             // Control low during data phase
                    if (serial_clk_edge) begin
                        // Send data bits from MSB to LSB
                        serial_data <= data_ser_tx[7 - bit_counter];
                        
                        if (bit_counter == 3'd7) begin
                            // All 8 data bits transmitted
                            serial_state <= SERIAL_DONE;          // Transaction complete
                            serial_tx_done <= 1'b1;              // Signal completion
                            serial_tx_busy <= 1'b0;              // Not busy anymore
                            transfer_complete <= 1'b1;           // Notify APB FSM
                            if (write_operation) begin
                                transfer_error <= 1'b0;          // Write successful
                            end
                        end else begin
                            bit_counter <= bit_counter + 1'b1;    // Next bit position
                        end
                    end
                end
                
                // --------------------------------------------------------------------
                // RECV_DATA state: Receive 8-bit data (read operation only)
                // Control line is high during receive to indicate response phase
                // --------------------------------------------------------------------
                SERIAL_RECV_DATA: begin
                    serial_ctrl <= 1'b1;             // Control high = response/receive phase
                    if (serial_clk_edge) begin
                        // Sample response line into receive buffer
                        // Build byte from MSB to LSB (bit 7 to bit 0)
                        data_ser_rx[7 - bit_counter] <= serial_response;
                        
                        if (bit_counter == 3'd7) begin
                            // All 8 bits received
                            rx_data <= data_ser_rx;              // Store received byte
                            rx_valid <= 1'b1;                    // Data is valid
                            serial_state <= SERIAL_DONE;         // Transaction complete
                            serial_tx_busy <= 1'b0;              // Not busy anymore
                            transfer_complete <= 1'b1;           // Notify APB FSM
                            transfer_error <= 1'b0;              // Read successful
                        end else begin
                            bit_counter <= bit_counter + 1'b1;    // Next bit position
                        end
                    end
                end
                
                // --------------------------------------------------------------------
                // DONE state: Transaction complete, return to idle
                // --------------------------------------------------------------------
                SERIAL_DONE: begin
                    serial_ctrl <= 1'b1;             // Return control to idle high
                    serial_data <= 1'b1;             // Data line idle high
                    // Return to idle if not starting a new transaction
                    if (!start_serial_tx) begin
                        serial_state <= SERIAL_IDLE;
                        serial_tx_busy <= 1'b0;
                    end
                end
                
                // --------------------------------------------------------------------
                // IDLE state: No transaction in progress
                // --------------------------------------------------------------------
                SERIAL_IDLE: begin
                    serial_ctrl <= 1'b1;             // Control line idle high
                    serial_data <= 1'b1;             // Data line idle high
                    serial_tx_busy <= 1'b0;          // Not busy
                end
                
                // --------------------------------------------------------------------
                // Default: safety state for unexpected conditions
                // --------------------------------------------------------------------
                default: begin
                    serial_state <= SERIAL_IDLE;     // Return to idle on any error
                end
            endcase
        end
    end
    
    // ========================================================================
    // Note on PSTRB (Write Strobe) Support:
    // ========================================================================
    // This implementation uses a simplified approach that sends only the first
    // byte of write data (PWDATA[7:0]) for all write transactions.
    //
    // For full PSTRB support in a production design, you would need to:
    // 1. Decode PADDR[1:0] to determine which byte lane is being accessed
    // 2. Check corresponding PSTRB bit to verify byte is valid
    // 3. Extract the appropriate byte from PWDATA based on address
    // 4. Potentially generate multiple serial transactions for multi-byte writes
    //
    // Example byte lane selection logic:
    //   case (addr_reg[1:0])
    //       2'b00: data_byte = wdata_reg[7:0];   // Byte lane 0, PSTRB[0]
    //       2'b01: data_byte = wdata_reg[15:8];  // Byte lane 1, PSTRB[1]
    //       2'b10: data_byte = wdata_reg[23:16]; // Byte lane 2, PSTRB[2]
    //       2'b11: data_byte = wdata_reg[31:24]; // Byte lane 3, PSTRB[3]
    //   endcase
    //
    // Similarly for read operations, the received byte would need to be placed
    // into the correct byte lane of PRDATA based on the original address.
    // ========================================================================
    
endmodule