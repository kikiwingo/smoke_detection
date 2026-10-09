module osd_coord(
    input               pix_clk,
    input               rst_n,
    input               de_in,
    input               vsync_in,

    output reg [11:0]   x_cnt,
    output reg [11:0]   y_cnt
);

// X坐标：de高电平时计数，每行de变低自动清零
always @(posedge pix_clk or negedge rst_n) begin
    if(!rst_n)
        x_cnt <= 12'd0;
    else if(de_in)
        x_cnt <= x_cnt + 12'd1;
    else
        x_cnt <= 12'd0;
end

// Y坐标：注意——uivtc输出的vsync是正极性高脉冲（上升沿=帧开始），
// 不能用 !vsync_in 清零（那样y_cnt会一直被清成0，OSD永不命中）。
// 正确做法：检测vsync上升沿复位y_cnt；每行结束（de下降沿且x_cnt非0）加1。
reg vsync_1d;
always @(posedge pix_clk or negedge rst_n) begin
    if(!rst_n)
        vsync_1d <= 1'b0;
    else
        vsync_1d <= vsync_in;
end

wire vsync_rise = vsync_in & ~vsync_1d;

always @(posedge pix_clk or negedge rst_n) begin
    if(!rst_n)
        y_cnt <= 12'd0;
    else if(vsync_rise)
        y_cnt <= 12'd0;
    else if((de_in == 1'b0) && (x_cnt != 12'd0))
        y_cnt <= y_cnt + 12'd1;
end

endmodule
