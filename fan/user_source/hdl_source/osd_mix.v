module osd_mix(
    input               pix_clk,
    input               rst_n,

    input               hsync_in,
    input               vsync_in,
    input               de_in,
    input      [23:0]   rgb_in,

    input      [11:0]   x_cnt,
    input      [11:0]   y_cnt,

    input               rom_pixel,
    input               warn_en,      // 警告使能：1=显示感叹号+警告文字，0=透传视频

    output reg          hsync_out,
    output reg          vsync_out,
    output reg          de_out,
    output reg [23:0]   rgb_out,
    output     [9:0]    rom_addr
);

// ===== 布局（720p 1280x720，右上角，整体高240px=屏高1/3）=====
// 感叹号：160x160（32x32 ROM 放大5倍）
localparam ICON_X   = 12'd1120;   // 1280 - 160
localparam ICON_Y   = 12'd80;
localparam ICON_W   = 12'd160;    // 32 * 5
localparam ICON_H   = 12'd160;
localparam ICON_DIV = 12'd5;

// "警告"文字：两字并排 128x64（16x16字库 放大4倍/字）
localparam TEXT_X   = 12'd1152;   // 1280 - 128
localparam TEXT_Y   = 12'd256;    // 80 + 160 + 16(间隔)
localparam TEXT_W   = 12'd128;    // 两字并排，每字 16*4=64
localparam TEXT_H   = 12'd64;     // 16*4
localparam TEXT_DIV = 12'd4;

localparam OSD_COLOR = 24'hFF0000;

// ---- 感叹号区域 ----
wire icon_active = (x_cnt >= ICON_X) && (x_cnt < ICON_X + ICON_W)
                 && (y_cnt >= ICON_Y) && (y_cnt < ICON_Y + ICON_H);
wire [11:0] icon_x_div = (x_cnt - ICON_X) / ICON_DIV;
wire [11:0] icon_y_div = (y_cnt - ICON_Y) / ICON_DIV;
assign rom_addr = { icon_y_div[4:0], icon_x_div[4:0] };

// ---- "警告"文字区域（用osd_char_lib字库，和左上角ANLU logo同一字库）----
wire text_active = (x_cnt >= TEXT_X) && (x_cnt < TEXT_X + TEXT_W)
                 && (y_cnt >= TEXT_Y) && (y_cnt < TEXT_Y + TEXT_H);
wire [11:0] text_x_div = (x_cnt - TEXT_X) / TEXT_DIV;
wire [11:0] text_y_div = (y_cnt - TEXT_Y) / TEXT_DIV;
wire        text_char_sel = (text_x_div >= 16);      // 0=警(左), 1=告(右)
wire [3:0]  text_char_x   = text_char_sel ? (text_x_div - 16) : text_x_div[3:0];
wire [3:0]  text_char_y   = text_y_div[3:0];

// 例化字库：0x82=警, 0x83=告
wire [7:0] char_code = text_char_sel ? 8'h83 : 8'h82;
wire [15:0] char_row_bits;
osd_char_lib u_warn_char(
    .I_char    ( char_code     ),
    .I_row     ( text_char_y  ),
    .O_row_bits( char_row_bits )
);
wire text_pixel = char_row_bits[15 - text_char_x];

// ---- 对齐打拍 ----
reg icon_active_r1, icon_active_r2;
reg text_active_r1, text_active_r2;
reg warn_en_r1, warn_en_r2;
reg text_pixel_r;
always @(posedge pix_clk or negedge rst_n) begin
    if(!rst_n) begin
        icon_active_r1 <= 1'b0; icon_active_r2 <= 1'b0;
        text_active_r1 <= 1'b0; text_active_r2 <= 1'b0;
        warn_en_r1 <= 1'b0; warn_en_r2 <= 1'b0;
        text_pixel_r <= 1'b0;
    end else begin
        icon_active_r1 <= icon_active;  icon_active_r2 <= icon_active_r1;
        text_active_r1 <= text_active;  text_active_r2 <= text_active_r1;
        warn_en_r1 <= warn_en;          warn_en_r2 <= warn_en_r1;
        text_pixel_r <= text_pixel;
    end
end

wire draw_icon = icon_active_r2 && warn_en_r2 && rom_pixel;
wire draw_text  = text_active_r2 && warn_en_r2 && text_pixel_r;
wire draw_osd   = draw_icon || draw_text;

// ---- 输出：hsync/vsync/de 打2拍，rgb 打2拍，全部对齐 ----
reg hsync_r1, vsync_r1, de_r1;
reg [23:0] rgb_r1;
always @(posedge pix_clk or negedge rst_n) begin
    if(!rst_n) begin
        hsync_r1 <= 1'b0; vsync_r1 <= 1'b0; de_r1 <= 1'b0; rgb_r1 <= 24'd0;
    end else begin
        hsync_r1 <= hsync_in;
        vsync_r1 <= vsync_in;
        de_r1    <= de_in;
        rgb_r1   <= rgb_in;
    end
end

always @(posedge pix_clk or negedge rst_n) begin
    if(!rst_n) begin
        hsync_out <= 1'b0; vsync_out <= 1'b0; de_out <= 1'b0; rgb_out <= 24'd0;
    end else begin
        hsync_out <= hsync_r1;
        vsync_out <= vsync_r1;
        de_out    <= de_r1;
        rgb_out   <= draw_osd ? OSD_COLOR : rgb_r1;
    end
end

endmodule
