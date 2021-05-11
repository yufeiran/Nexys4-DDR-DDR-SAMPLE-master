`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Digilent Inc
// Engineer: Thomas Kappenman
// 
// Create Date:    01:55:33 09/09/2014 
// Design Name: Looper
// Module Name:    looper1_1.v 
// Project Name: Looper Project
// Target Devices: Nexys4 DDR
// Tool versions: Vivado 2015.1
// Description: This project turns your Nexys4 DDR into a guitar/piano/aux input looper. Plug input into XADC3
//
// Dependencies: 
//
// Revision: 
//  0.01 - File Created
//  1.0 - Finished with 8 external buttons on JC, 4 memory banks
//  1.1 - Changed addressing, bug fixes
//  1.2 - Moved to different control scheme using 4 onboard buttons, banks doubled to 8 banks, 3 minutes each
//
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module DDR2(

//XADC guitar input
    input vauxp3,
    input vauxn3,
   
    input BTNL,
    input BTNR,
    input BTND,
    input BTNC,
    input JC1,
    
    input CLK100MHZ,
    input rstn,
    //input [3:0]sw,
    input [15:0] sw,
    
    output wire [15:0] LED,
    output wire LED16_R,
    output wire LED17_G,   
    output AUD_PWM,
    output AUD_SD,
    
    output [7:0]an,
    output [6:0]seg,
    
    //memory signals
    output   [12:0] ddr2_addr,
    output   [2:0] ddr2_ba,
    output   ddr2_ras_n,
    output   ddr2_cas_n,
    output   ddr2_we_n,
    output   ddr2_ck_p,
    output   ddr2_ck_n,
    output   ddr2_cke,
    output   ddr2_cs_n,
    output   [1:0] ddr2_dm,
    output   ddr2_odt,
    inout    [15:0] ddr2_dq,
    inout    [1:0] ddr2_dqs_p,
    inout    [1:0] ddr2_dqs_n
);
   
    wire rst;
    assign rst = ~rstn;
   
    parameter tenhz = 10000000;
    
    // Max_block = 64,000,000 / 8 = 8,000,000 or 0111 1010 0001 0010 0000 0000
    // 22:0
    //8 banks
    
    wire playb;
    assign playb = BTNC || JC1;//Play button = JC1 OR BTNC, foot button place on JC1
    
    wire [3:0]buttons_i;
    assign buttons_i = {BTNR, playb, BTND, BTNL};
    
    reg [22:0] max_block=0;
    reg [26:0] timercnt=0;
    reg [11:0] timerval=0;
        
    wire set_max;
    wire reset_max;
    wire p;//Bank is playing
    wire r;//Bank is recording
    wire del_mem;//Clear delete flag
    wire delete;//Delete flag
    wire [2:0] delete_bank;//Bank to delete
    wire [2:0] mem_bank;//Bank
    wire write_zero;//Used when deleting
    wire [22:0]current_block;//Block address
    wire [3:0] buttons_db;//Debounced buttons
    wire [7:0] active;//Bank is recorded on
    
    wire [2:0] current_bank;
    
    wire [26:0] mem_a;   //????????งางๅ???
    assign mem_a[26] = 1'b0;  
    assign mem_a [25:0] = 26'd666; //Address is block*8 + banknumber
    //So address cycles through 0 - 1 - 2 - 3 - 4 - 5 - 6 - 7, then current block is inremented by 1 and mem_bank goes back to 0: mem_a = 8
    wire [31:0] mem_dq_i;
    wire [31:0] mem_dq_o;
    wire [31:0] mem_dq;
    wire mem_cen;
    wire mem_oen;
    wire mem_wen;
    wire mem_ub;
    wire mem_lb;
    assign mem_ub = 0;
    assign mem_lb = 0;
    
    wire [15:0] chipTemp;

    wire data_flag;

    wire data_ready;
    
    wire mix_data;
    wire [22:0] block44KHz;
    
//////////////////////////////////////////////////////////////////////////////////////////////////////////
////    clk_wiz instantiation and wiring
//////////////////////////////////////////////////////////////////////////////////////////////////////////
    clk_wiz_0 clk_1
    (
        // Clock in ports
        .clk_in1(CLK100MHZ),
        // Clock out ports  
        .clk_out1(clk_out_100MHZ),
        .clk_out2(clk_out2_200MHZ),
        // Status and control signals        
        .locked()            
    );     
    assign p=BTNL;
    assign r=BTNR;
        
    
////////////////////////////////////////////////////////////////////////////////////////////////////////
////    Memory instantiation
//////////////////////////////////////////////////////////////////////////////////////////////////////// 
    //sel 0 ???? 1 ????
    //????32??????
    Ram2Ddr Ram(
        .clk_200MHz_i          (clk_out2_200MHZ),
        .rst_i                 (rst),
        .device_temp_i         (chipTemp[11:0]),
        // RAM interface
        .ram_a                 (mem_a),
        .ram_dq_i              (mem_dq_i),
        .ram_dq_o              (mem_dq_o),
        .ram_cen               (mem_cen),
        .ram_oen               (mem_oen),
        .ram_wen               (mem_wen),
        .ram_ub                (mem_ub),
        .ram_lb                (mem_lb),
        // DDR2 interface
        .ddr2_addr             (ddr2_addr),
        .ddr2_ba               (ddr2_ba),
        .ddr2_ras_n            (ddr2_ras_n),
        .ddr2_cas_n            (ddr2_cas_n),
        .ddr2_we_n             (ddr2_we_n),
        .ddr2_ck_p             (ddr2_ck_p),
        .ddr2_ck_n             (ddr2_ck_n),
        .ddr2_cke              (ddr2_cke),
        .ddr2_cs_n             (ddr2_cs_n),
        .ddr2_dm               (ddr2_dm),
        .ddr2_odt              (ddr2_odt),
        .ddr2_dq               (ddr2_dq),
        .ddr2_dqs_p            (ddr2_dqs_p),
        .ddr2_dqs_n            (ddr2_dqs_n)
    );
          
////////////////////////////////////////////////////////////////////////////////////////////////////////
////    Memory Controller
//////////////////////////////////////////////////////////////////////////////////////////////////////// 

    mem_ctrl mem_controller(
        .clk_100MHz(clk_out_100MHZ),
        .rst(rst),
        
        .playing(p),
        .recording(r),
        
        .delete_clear(del_mem),
        .RamCEn(mem_cen),
        .RamOEn(mem_oen),
        .RamWEn(mem_wen),
        .write_zero(write_zero),
        .get_data(data_flag),
        .data_ready(data_ready),
        .mix_data(mix_data)
        );


////////////////////////////////////////////////////////////////////////////////////////////////////////
////    Data in latch
//////////////////////////////////////////////////////////////////////////////////////////////////////// 

    reg [31:0] mem_dq_o_b;   
    reg [31:0] InData;
        
    always@(posedge(clk_out_100MHZ))begin
        if(data_ready==1)
        begin
            mem_dq_o_b<=mem_dq_o;
        end
    end
    

    always@(posedge clk_out_100MHZ)begin
        if(data_flag==1)begin
            InData<={sw[7:0], 16'h0,sw[15:8]};
        end
    end
  
 
                             
    //Data in is assigned the latched data input from sound_data, or .5V (16'h7444) if write zero is on      
    assign mem_dq_i = (write_zero==0) ?  InData: 32'h7FFFFFFF;
    assign LED[15:0]={mem_dq_o_b[31:24],mem_dq_o_b[7:0]};
    assign LED16_R=r;
    assign LED17_G=p;
    
endmodule