`timescale 1ns/1ns

module snakeGame_tb();
  reg UP, DOWN, LEFT, RIGHT, SYS_CLK, RST, PAUSE;
  wire ISPAUSED, CLK, COLLISION, GOT_ITEM;
  wire [3:0] X, Y;
  wire [6:0] SEED;
  wire [9:0] MOVES;
  wire [7:0] LENGTH;
  wire [255:0] BODY_POS;
  
  moveSnake moveSnake_test(
    .X (X),
    .Y (Y),
    .UP (UP),
    .DOWN (DOWN),
    .LEFT (LEFT),
    .RIGHT (RIGHT),
    .ISPAUSED (ISPAUSED),
    .CLK (CLK),
    .RST (RST)
  );
  
  gameClock gameClock_test(
    .CLK (CLK),
    .ISPAUSED (ISPAUSED),
    .SYS_CLK (SYS_CLK),
    .RST (RST),
    .PAUSE (PAUSE)
  );
  
  trackSnake trackSnake_test(
    .BODY_POS (BODY_POS),
    .LENGTH (LENGTH),
    .X (X),
    .Y (Y),
    .GOT_ITEM (GOT_ITEM),
    .RST (RST)
  );
  
  detectCollision detectCollision_test(
    .COLLISION (COLLISION),
    .X (X),
    .Y (Y),
    .CLK (CLK),
    .RST (RST)
  );
  
  generateItem generateItem_test(
    .GOT_ITEM(GOT_ITEM),
    .X (X),
    .Y (Y),
    .RST (RST),
    .SEED (SEED)
  );
  
  getStartSeed getStartSeed_test(
    .SEED (SEED),
    .SYS_CLK (SYS_CLK),
    .RST (RST)
  );
  
  numMoves numMoves_test(
    .MOVES (MOVES),
    .CLK (CLK),
    .RST (RST)
  );
  
  initial begin
    RST = 0;
    PAUSE = 0;    
    UP = 0;
    DOWN = 0;
    LEFT = 0;
    RIGHT = 0;
    SYS_CLK = 0;
    #1000
    RST = 1;
    #826
    RST = 0;
    #100
    PAUSE = 1;
    #100
    PAUSE = 0;
    
    #12000
    RIGHT = 1;
    #1000
    RIGHT = 0;
    #24000
    DOWN = 1;
  end
  
  always
    #5 SYS_CLK = ~SYS_CLK;
  
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars;
    #100000 $finish;
  end
endmodule
