/**
  ******************************************************************************
  * File Name          : timestamp.v
  * Author             : Chen Yuehai
  * Version            : 2.0
  * date               : 2021/3/9
  * Description        : 对应神经元泄漏事件的产生
  * Function List      :
  * History            :
        <author>    <version>    <time>    <desc>
  ******************************************************************************
  * @attention
  *
  * <h2><center>&copy; Copyright (c) 2020 XXXX.
  * All rights reserved.</center></h2>
  *
  ******************************************************************************
  */

module Tref_Event_generate(
    input wire CLK,
    input wire RST_N,
    input wire Receive_Tref,
    input wire tref_event_generate,

    output wire Tref_Event_Out

);


reg Tref_Event;

assign Tref_Event_Out = Tref_Event;


always@(posedge CLK or negedge RST_N)begin
   if(!RST_N)begin
       Tref_Event <= 0;
   end 
   else if(tref_event_generate)begin//49999
       Tref_Event <= 1;
   end
   else if(Receive_Tref)begin
       Tref_Event <= 0;
   end
   else if(~Tref_Event)begin
       Tref_Event <= 0;
   end
   else begin
       Tref_Event <= Tref_Event;
   end
end


endmodule