//timescale - DONT CHANGE!!!!
`timescale 1ns / 1ps

//initialize all needed inputs and outputs so far - subject to change
//using switches 0-7
//using LEDS 0-7
//using JMOD A for IPS input
//using JMOD B for comparator input (still in testing, we'll finish it later)
//using JMOD C for all H-Bridge outputs
//I haven't figured out how to declare these as arrays - don't judge me
module HELPv2
(
            input clk,
            input SW0,
            output LED0,
            input SW1,
            output LED1,
            input SW2,
            output LED2,
            input SW3,
            output LED3,
            input SW4,
            output LED4,
            input SW5,
            output LED5,
            input SW6,
            output LED6,
            input SW7,
            input JB0,
            input JB1,
            output JC0,
            output JC1,
            output JC2,
            output JC4,
            output JC5,
            output JC6,
            output LED7,
            input JA0,
            output reg [3:0] an,      // 4 Digits on Basys 3 Board
            output reg [6:0] seg    // 7 Segment Display 
 );
 
//Whole bunch of assignments, primarily used to assign LEDS to stuff
//Assigning a port to an LED is like, the easiest way to test a JMOD port
assign LED0 = SW0;
assign LED1 = SW1;
assign LED2 = SW2;
assign LED3 = SW3;
assign LED4 = SW4;
assign LED5 = SW5;
assign LED6 = SW6;

//H-bridge outputs tied to switches
assign JC1 = SW3;
assign JC2 = SW4;
assign JC5 = SW4;
assign JC6 = SW3;
assign JA0 = LED7;

 //USED FOR 7-seg, DON'T CHANGE!!!!!!!!
 //Use the 2 MSBs of 19-bit counter to create 190 Hz frequency refresh
 reg [18:0] count;
 always @ (posedge clk)
      count = count + 1;
 // This wire is driven by the 3 MSBs of the counter. We'll use it to
 // refresh the display.
 wire [2:0] refresh;
 assign refresh = count[18:15];


//7-Segment bullshit. Literally just collapse this and ignore it.
//DO NOT CHANGE UNLESS YOU ARE 100% CERTAIN WHAT YOU ARE DOING
//EVEN THEN, CONSULT ME (PAUL) BEFORE CHANGING!!!!!!!!
always @ (*) 
case (refresh) 
           3'b000:
                begin
                    case(SW0)
                        1'b1:
                            begin
                            an = 4'b1110;
                            seg = 7'b1111001;
                            end
                            default:
                            begin
                            an = 4'b1110;
                            seg = 7'b1111111;
                            end 
                    endcase       
                end
           3'b001:
                begin
                    case(SW1)
                        1'b1:
                            begin
                            an = 4'b1110;
                            seg = 7'b0100100;
                            end
                            default:
                            begin
                            an = 4'b1110;
                            seg = 7'b1111111;
                            end          
                    endcase       
                end
           3'b010:
                begin
                    case(SW2)
                        1'b1:
                            begin
                            an = 4'b1110;
                            seg = 7'b0110000;
                            end
                        default:
                            begin
                            an = 4'b1110;
                            seg = 7'b1111111;
                            end      
                    endcase       
                end
           3'b011:
                    begin
                        case(SW3) //F for forwards default, flip switch to go back
                        1'b1:
                            begin
                            an = 4'b1101;
                            seg = 7'b0001110;
                            end
                        default:
                            begin
                            an = 4'b1101;
                            seg = 7'b1111111;
                            end  
                      endcase   
                    end 
           3'b100:
                    begin
                        case(SW4) //F for forwards default, flip switch to go back
                        1'b1:
                            begin
                            an = 4'b1101;
                            seg = 7'b0000011;
                            end
                        default:
                            begin
                            an = 4'b1101;
                            seg = 7'b1111111;
                            end
                       endcase
                    end
endcase


//15 bit register to count through for PWM
reg [15:0] speedcounter1;
always @ (posedge clk)
    begin
         //count until 32767, once you hit 32767 go back to 0
         if (speedcounter1 < 32767) 
            speedcounter1 <= speedcounter1 + 1;
         else 
            speedcounter1 <= 0;  
    end

//Another 15 bit register to count through for PWM
//We actually don't REALLY need this one, but don't delete it
reg [15:0] speedcounter2;
always @ (posedge clk)
    begin
         //count until 32767, once you hit 32767 go back to 0
         if (speedcounter2 < 32767) 
            speedcounter2 <= speedcounter1 + 1;
         else 
            speedcounter2 <= 0;  
    end

//Wire SP1C is 1 when the speedcounter1 < 23550, and 0 when speedcounter1 > 23550
//This creates a 61% duty cycle, creating speed 1.    
wire SP1C;
    assign SP1C = (speedcounter1 < 23550) ? 1:0;
    
//Then AND the PWM with SW0 
wire SP1E;
    and(SP1E, SP1C, SW0);

//Wire SP2C is 1 when the speedcounter1 < 26550, and 0 when speedcounter1 > 26550
//This creates a 71% duty cycle, creating speed 2.
wire SP2C;
    assign SP2C = (speedcounter2 < 26555) ? 1:0;
    
//Then AND the PWM with SW1 
wire SP2E;
    and(SP2E, SP2C, SW1);

//Wire SP3C is just switch 2, no duty cycle  
wire SP3E;
    assign SP3E = SW2;

//This was for overcurrent protection but we never got that shit working  
//reg [30:0] speedcounter3;
//always @ (posedge clk)
//    begin
//         if (speedcounter3 < 1073741842) 
//         speedcounter3 <= speedcounter3 + 1;
//         else speedcounter3 <= 0;  
//    end
//wire stop;
//assign stop = (speedcounter3 < 1073741839) ? 1:0;
//reg JB0_last;
//always @ (posedge stop)
//JB0_last = ~JB0;

//Wire SPSel is XOR'd with all 3 SP#E wires
//This ensures only 1 speed is selected on a time
wire SPSel;
    xor(SPSel, SP1E, SP2E, SP3E); 

//IPS inputs - work in progress 
wire IPS;
    assign IPS = ~JA0; 

//AND gate with IPS and SPSel to drive ENA and ANB
//ENA and ENB essentially act as power to the rover
wire OnCondition;
    and(OnCondition, IPS, SPSel);

//ENA and ENB are driven by OnCondition
assign JC0 = OnCondition; 
assign JC4 = OnCondition;    

//End of module - hooray!!!
//There's a way to use multiple modules in one file, but my ass hasn't figured it out yet
endmodule
