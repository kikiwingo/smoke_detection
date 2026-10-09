//==================================================================
// color_mask.v  ——  颜色掩码比较器（黄红色目标检测）
// 位置: user_source/hdl_source/isp/color_mask.v
// 并列于: edge_detect_96.v, isp_top.v
//
// 输入: AWB 输出的 RGB96（4像素打包，每像素 R[23:16] G[15:8] B[7:0]）
// 输出: 伪彩RGB96（命中=红, 未命中=暗灰） + 4bit单像素掩码
//
// 判定规则（黄红色相，可改阈值，全部整数运算，无除法）:
//   1) 色相排序  : R >= G >= B
//   2) 饱和度代理: R - B >= TH_RB  （红蓝差足够大，排除灰白中性面/白墙）
//   3) 橙红主导  : R - G >= TH_RG  （排除暖光残留色偏下的浅黄表面）
//   4) 亮度窗口  : Y_LO <= Y <= Y_HI（Y = R/4+G/2+B/4；下限滤暗噪声，上限防过曝误检）
// 纯比较器，无 line buffer。
//
// 注意：tvalid/tuser/tlast 直接透传（不打拍），仅数据打1拍。
// 原因：data_96_to_128 的 S_cnt 相位跟着 I_96b_valid 走，
// 如果 valid/user 打拍了，S_cnt 相位就错位，导致 DDR 只写中间一小块。
//==================================================================
module color_mask #(
    parameter IMG_WIDTH  = 1280,
    parameter IMG_HEIGHT = 720,
    parameter [7:0] TH_RB = 8'd60,   // R-B 最小差（饱和度代理）
    parameter [7:0] TH_RG = 8'd30,   // R-G 最小差（橙红主导）
    parameter [8:0] Y_LO  = 9'd40,   // 亮度下限
    parameter [8:0] Y_HI  = 9'd235   // 亮度上限（防过曝白墙误检）
)(
    input               I_clk,
    input               I_rst_n,
    input               I_tlast,
    input               I_tuser,
    input               I_tvalid,
    input      [95:0]   I_tdata,
    output              O_tlast,
    output              O_tuser,
    output              O_tvalid,
    output reg [95:0]   O_tdata,    // 伪彩可视化
    output reg [3:0]    O_mask      // 每像素1bit掩码，给 detect_top
);

    // tvalid/tuser/tlast 直接透传——和 awb 相位对齐，S_cnt 不错位
    assign O_tvalid = I_tvalid;
    assign O_tuser  = I_tuser;
    assign O_tlast  = I_tlast;

    // 拆出4个像素
    wire [7:0] r0 = I_tdata[95:88], g0 = I_tdata[87:80], b0 = I_tdata[79:72];
    wire [7:0] r1 = I_tdata[71:64], g1 = I_tdata[63:56], b1 = I_tdata[55:48];
    wire [7:0] r2 = I_tdata[47:40], g2 = I_tdata[39:32], b2 = I_tdata[31:24];
    wire [7:0] r3 = I_tdata[23:16], g3 = I_tdata[15:8],  b3 = I_tdata[7:0];

    // 黄红判定：色相排序 + 饱和度代理 + 橙红主导 + 亮度窗口
    function pix_hit;
        input [7:0] r, g, b;
        reg [8:0] y;
        begin
            y = {3'b000, r[7:2]} + {2'b00, g[7:1]} + {3'b000, b[7:2]};
            pix_hit = (r >= g) && (g >= b)
                   && (r - b >= TH_RB)
                   && (r - g >= TH_RG)
                   && (y >= Y_LO) && (y <= Y_HI);
        end
    endfunction

    wire hit0 = pix_hit(r0, g0, b0);
    wire hit1 = pix_hit(r1, g1, b1);
    wire hit2 = pix_hit(r2, g2, b2);
    wire hit3 = pix_hit(r3, g3, b3);

    // 伪彩：命中=纯红 FF0000，未命中=暗灰 101010
    function [23:0] pseudo;
        input hit;
        begin
            pseudo = hit ? 24'hFF0000 : 24'h101010;
        end
    endfunction

    // 数据打1拍（比较器组合逻辑后打拍，时序友好）
    // 注意：valid/user/last 是透传的，data 晚1拍——
    // 但 data_96_to_128 内部自己有 S_96b_data_1d 打拍对齐，所以没问题
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            O_tdata  <= 96'd0;
            O_mask   <= 4'd0;
        end else begin
            O_tdata  <= {pseudo(hit0), pseudo(hit1), pseudo(hit2), pseudo(hit3)};
            O_mask   <= {hit3, hit2, hit1, hit0};
        end
    end

endmodule
