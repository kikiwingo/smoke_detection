//==================================================================
// detect_top.v  ——  目标检测顶层（占位版）
// 位置: user_source/hdl_source/isp/detect_top.v
// 并列于: edge_detect_96.v, color_mask.v, isp_top.v
//
// 当前占位: 直接把 color_mask 的4bit掩码渲染成二值伪彩
//   掩码=1 → 绿色 00FF00
//   掩码=0 → 黑色 000000
// 后续要加的功能（预留接口，本版不实现）:
//   - 行游程编码
//   - 连通域面积统计
//   - 面积阈值筛选
//   - 帧级IIR平滑
//   - 输出目标计数/坐标/面积
//
// 注意：tvalid/tuser/tlast 直接透传（不打拍），仅数据打1拍。
// 原因：data_96_to_128 的 S_cnt 相位跟着 I_96b_valid 走，
// 如果 valid/user 打拍了，S_cnt 相位就错位，导致 DDR 只写中间一小块。
//==================================================================
module detect_top #(
    parameter IMG_WIDTH  = 1280,
    parameter IMG_HEIGHT = 720
)(
    input               I_clk,
    input               I_rst_n,
    input               I_tlast,
    input               I_tuser,
    input               I_tvalid,
    input      [3:0]    I_mask,     // color_mask 输出的4bit掩码
    output              O_tlast,
    output              O_tuser,
    output              O_tvalid,
    output reg [95:0]   O_tdata,    // 二值伪彩RGB96
    output reg [15:0]   O_obj_count,  // 目标计数（占位，恒0）
    output reg [11:0]   O_obj_x,      // 目标中心x（占位）
    output reg [11:0]   O_obj_y       // 目标中心y（占位）
);

    // tvalid/tuser/tlast 直接透传——和 awb 相位对齐，S_cnt 不错位
    assign O_tvalid = I_tvalid;
    assign O_tuser  = I_tuser;
    assign O_tlast  = I_tlast;

    // 掩码→伪彩：mask=1→绿 00FF00，mask=0→黑 000000
    function [23:0] mask_to_rgb;
        input m;
        begin
            mask_to_rgb = m ? 24'h00FF00 : 24'h000000;
        end
    endfunction

    // 数据打1拍
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            O_tdata    <= 96'd0;
            O_obj_count <= 16'd0;
            O_obj_x     <= 12'd0;
            O_obj_y     <= 12'd0;
        end else begin
            // 像素0 必须放最高位（与 awb/color_mask 输出顺序一致）：
            // color_mask 的 O_mask = {hit3,hit2,hit1,hit0}，即 mask[0]=像素0、mask[3]=像素3，
            // 这里按 0,1,2,3 顺序输出；否则每4像素组左右镜像，掩码密集时整屏绿黑噪点。
            O_tdata  <= {mask_to_rgb(I_mask[0]),
                         mask_to_rgb(I_mask[1]),
                         mask_to_rgb(I_mask[2]),
                         mask_to_rgb(I_mask[3])};
            // 占位：连通域统计后续在这里实现
            O_obj_count <= 16'd0;
            O_obj_x     <= 12'd0;
            O_obj_y     <= 12'd0;
        end
    end

endmodule
