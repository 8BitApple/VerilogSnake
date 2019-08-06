`timescale 1ns/1ns

// POTENTIAL ISSUE: Check timing to see if snake can collide with the final
// piece of the snake (snake should be able to chase itself in a perfect loop)
// ^^ Going of of that, check all the block for timing issues. A lot of things
// are clock triggered right now, but they really don't need to be

////////////////////////////////////////////////////////////////////////////////
// MODULE moveSnake
// Determines how the snake will move (or won't move, if paused)
// Outputs position of snake
// To track the body of the snake, record the x and y position. To determine how
// far back data is legitimate, have a number storing the length of the snake.
////////////////////////////////////////////////////////////////////////////////
module moveSnake(X, Y, UP, DOWN, LEFT, RIGHT, ISPAUSED, CLK, RST);
  input UP, DOWN, LEFT, RIGHT, ISPAUSED, CLK, RST;
  output reg [3:0] X, Y;
  
  reg [1:0] move_dir; // 00 is up, 01 is down, 10 is left, 11 is right
  
  // Update move direction (does not allow reversing direction 180 degrees)
  always @(posedge UP or posedge DOWN or posedge LEFT or posedge RIGHT) begin
    if(UP == 1'b1 && move_dir != 2'b01)     move_dir <= 2'b00;
    if(DOWN == 1'b1  && move_dir != 2'b00)  move_dir <= 2'b01;
    if(LEFT == 1'b1 && move_dir != 2'b11)   move_dir <= 2'b10;
    if(RIGHT == 1'b1  && move_dir != 2'b10) move_dir <= 2'b11;
  end
  
  always @(posedge CLK or posedge RST) begin
    if(RST == 1'b1) begin // Reset outputs
      X <= 4'b1000;
      Y <= 4'b0100;
      move_dir <= 2'b00;
    end
    else if(!ISPAUSED) begin // Move snake if not paused
      case(move_dir)
        2'b00 : Y <= Y+1;
        2'b01 : Y <= Y-1;
        2'b10 : X <= X-1;
        2'b11 : X <= X+1;
      endcase
    end
  end
endmodule
     

////////////////////////////////////////////////////////////////////////////////
// MODULE gameClock
// Downconverts 100MHz system clock to 4Hz (adjustable w/ integer 'count_to'
// Counter is able to be reset or paused and outputs a signal 'ISPAUSED' when
// it is paused. Game is paused upon reset and must be unpaused to begin
// Future feature could include changin the clock frequency so that as the game
// goes on, the clock speeds up (the snake moves faster)
////////////////////////////////////////////////////////////////////////////////
module gameClock(CLK, ISPAUSED, SYS_CLK, RST, PAUSE);
  input SYS_CLK, RST, PAUSE;
  output reg CLK, ISPAUSED;
  
  reg [24:0] move_counter; // Counts up to 25M
  integer count_to = 250; // For device testing, change to 25000000
  
  // Button downpress flips pause state
  always @(posedge PAUSE or posedge RST) begin
    if(RST == 1'b1) ISPAUSED <= 1;
    else ISPAUSED <= ~ISPAUSED;
  end
  
  // Increments counter and cretes CLK signal
  always @(posedge SYS_CLK) begin
    if(RST == 1'b1) begin
      move_counter <= 0;
      CLK <= 0;
    end
    else if(ISPAUSED == 1'b1) ; // Do nothing to counter if paused
    else if(move_counter < count_to)
      move_counter <= move_counter+1;
    else begin
      CLK <= ~CLK;
      move_counter <= 0;
  	end
  end
endmodule

////////////////////////////////////////////////////////////////////////////////
// MODULE trackSnake
// Tracks the snake length and and the location of its body.
// There is a 256 bit array to pass to other modules and a 2048 bit memory
// to hold information for this module only
////////////////////////////////////////////////////////////////////////////////
module trackSnake(BODY_POS, LENGTH, X, Y, GOT_ITEM, RST);
  input [3:0] X, Y;
  input GOT_ITEM, RST;
  output reg [7:0] LENGTH; // Excludes head, big enough to occupy every square
  output reg [255:0] BODY_POS; // 16x16 array to track snake in square
  
  // Memory holding 
  reg [7:0] body_mem [0:255];

  reg [7:0] i;
  reg [7:0] j;
 
  always @(posedge GOT_ITEM) LENGTH <= LENGTH + 1;
  
  always @(X or Y or posedge RST) begin 
    if(RST == 1'b1) begin
      BODY_POS <= 256'd0; //  Set BODY_POS to 0 everywhere
      BODY_POS[{X,Y}] <= 1'b1;   // Set all 3 parts of snake to 1
      BODY_POS[{X,Y-2'b01}] <= 1'b1;
      BODY_POS[{X,Y-2'b10}] <= 1'b1;
      LENGTH <= 3;
      body_mem[0] <= 8'b10000100; // Position (8,4);
      body_mem[1] <= 8'b10000011; // Position (8,3)
      body_mem[2] <= 8'b10000010; // Position (8,2)
    end
    else begin
     
      // Update BODY_POS
      BODY_POS[{X,Y}] <= 1'b1; // Add new snake head location to array 
      if(GOT_ITEM == 1'b0) begin
        BODY_POS[body_mem[LENGTH-1]] <= 1'b0; // Erase end of snake
      end
      
      // Update body_mem
      for(i = 255; i > 0; i = i - 1) begin
        body_mem[i] <= body_mem[i-1];
      end
      body_mem[0] <= {X,Y};
    end
  end
endmodule

// Need to combine the above and below modules (cannot pass snake body location)
// Might also need to combine with generateItem as this needs to know where
// the snake is to avoid generating an item on top of it

////////////////////////////////////////////////////////////////////////////////
// MODULE detectCollision
// Detects a collision between the snake and the wall or the snake and itself
// IN PROGRESS: Currently only detects a collision with the snake and the wall
////////////////////////////////////////////////////////////////////////////////
module detectCollision(COLLISION, X, Y, CLK, RST);
  input CLK, RST;
  input [3:0] X, Y;
  output COLLISION;
  
  wire [3:0] at_edge; // 3=top edge, 2=bottom edge, 1=left edge, 0=right edge
  reg [3:0] at_edge_prev; // holds previous values of at_edge
  
  assign at_edge[3] = &Y;  // 1 if Y = 1111
  assign at_edge[2] = ~|Y; // 1 if Y = 0000
  assign at_edge[1] = ~|X; // 1 if X = 0000
  assign at_edge[0] = &X;  // 1 if X = 1111
  
  // Collision detection with wall
  wire [3:0] col_bus; // Interim wire for detecting collision
  and U0(col_bus[3],at_edge[2], at_edge_prev[3]); // Detect top edge collision
  and U1(col_bus[2],at_edge[3], at_edge_prev[2]); // Detect bottom edge collision
  and U2(col_bus[1],at_edge[0], at_edge_prev[1]); // Detect left edge collision
  and U3(col_bus[0],at_edge[1], at_edge_prev[0]); // Detect right edge collision
  
  assign COLLISION = ( |col_bus) ? 1 : 0;
  
  // Reset register or shift in values from at_edge
  always @(posedge CLK or posedge RST) begin
    if(RST == 1'b1) begin
      at_edge_prev <= 4'b0000;
    end else begin
      at_edge_prev <= at_edge;
    end  
  end
endmodule


////////////////////////////////////////////////////////////////////////////////
// MODULE generateItem
// Generate an item for the snake to get (and notify when successfully gotten)
////////////////////////////////////////////////////////////////////////////////
module generateItem(GOT_ITEM, X, Y, RST, SEED);
  input [3:0] X, Y;
  input RST;
  input [6:0] SEED;
  output reg GOT_ITEM;
  
  reg got_first_item; // Controls whether using init_loc or getRand
  reg [7:0] init_loc; // First 4 bits are X, last 4 bits are Y
  reg [7:0] rand_loc; // First 4 bits are X, last 4 bits are Y
  
  wire [7:0] item_loc;
  assign item_loc = (got_first_item) ? rand_loc : init_loc;
  
  always @(negedge RST) init_loc <= {1'b1,SEED};
  
  always @(X or Y or posedge RST) begin
    GOT_ITEM <= 0;
    if(RST == 1'b1) begin // Reset button pressed
      got_first_item <= 0;
    end
    //else if(got_first_item == 1'b0 && init_loc != {X,Y}) begin
      //rand_loc <= {1'b1,init_loc};
    //end
    if(item_loc == {X,Y}) begin	  // Otherwise, use the algorithm
      got_first_item <= 1'b1;
      GOT_ITEM <= 1;
      rand_loc <= 8'h25; // Change this to be a random number (somehow)
      // Note that this number needs to avoid generation on the snake head
      // or body
    end
  end

  
  
  // FUNCTION getRand
  // Generate random location (item not compatible with 
  //function [5:0] rotate_right;
    //input SYS_CLK;
    //integer A = 13;
    //integer M = 89;
    //integer Q = M / A;
    //integer R = M % A;
    //integer number = (A*(number mod Q)    ) -
      //               ( R * floor(number / Q) );

        //if (number is negative)
            //  number = number + M;
          //  end
  //endfunction;
endmodule


////////////////////////////////////////////////////////////////////////////////
// MODULE getStartSeed
// Generate a value based on the duration the RST button is held down
////////////////////////////////////////////////////////////////////////////////
module getStartSeed(SEED, SYS_CLK, RST);
  input SYS_CLK, RST;
  output reg [6:0] SEED;
    
  always @(posedge SYS_CLK) begin
    if(RST == 1'b0) SEED <= 0;
    else SEED <= SEED+1;
  end
endmodule


////////////////////////////////////////////////////////////////////////////////
// MODULE numMoves
// Count the number of moves (i.e. count number of CLK cycles since RST)
////////////////////////////////////////////////////////////////////////////////
module numMoves(MOVES, CLK, RST);
  input CLK, RST;
  output reg [9:0] MOVES;
    
  always @(posedge CLK or posedge RST) begin
    if(RST == 1'b1) begin
      MOVES <= 0;
    end else
      MOVES <= MOVES+1;
  end
endmodule
