`default_nettype none

module test_st #(
  parameter real Fref = 0.1e9,
  parameter real Tstop = 20e-6
);
  timeunit 1ns;
  timeprecision 1ps;
  
  const real Tref = 1/Fref;

  bit rclk;
  initial begin
    forever begin
      #(0.5*Tref*1s);
      rclk = ~rclk;
    end
  end

  bit dclk;
  bit vclk;

  cppll cppll (
    .rclk_i(rclk),
    .dclk_o(dclk),
    .vclk_o(vclk)
  );

  initial begin
    #(Tstop*1s);
    $finish();
  end

  initial begin
    real t_start;
    real tau;
    real sgn;
    integer fh;
    int k;

    fh = $fopen("tau_st.csv", "w");
    $fdisplay(fh, "k,tau,v");
    
    forever begin
      wait(cppll.icp != 0);
      sgn = (cppll.icp > 0) ? +1 : -1;
      t_start = $realtime();
      wait(cppll.icp == 0);
      tau = sgn * (($realtime() - t_start)/1s);
      $fdisplay(fh, "%0d,%.4e,%.4e", k, tau, cppll.vctrl);
      k++;
    end
  end

endmodule


module cppll (
  input bit rclk_i,
  output bit dclk_o,
  output bit vclk_o
);
  timeunit 1ns;
  timeprecision 1ps;

  bit up;
  bit dn;

  pfd pfd (
    .rclk_i,
    .dclk_i(dclk_o),
    .up_o(up),
    .dn_o(dn)
  );

  real icp;

  cp cp (
    .up_i(up),
    .dn_i(dn),
    .icp_o(icp)
  );

  real vctrl;

  lpf lpf (
    .icp_i(icp),
    .vctrl_o(vctrl)
  );

  vco vco (
    .vctrl_i(vctrl),
    .vclk_o
  );

  fbdiv fbdiv (
    .vclk_i(vclk_o),
    .dclk_o
  );

endmodule


module pfd #(
  parameter real Delay = 1e-12
)(
  input bit rclk_i,
  input bit dclk_i,
  output bit up_o,
  output bit dn_o
);
  timeunit 1ns;
  timeprecision 1ps;

  bit reset;

  always_comb begin
    reset = (up_o & dn_o);
  end

  bit reset_delayed;

  always @(reset) begin
    #(Delay * 1s);
    reset_delayed =  reset;
  end

  always_ff @(posedge rclk_i, posedge reset_delayed) begin
    if (reset) begin
      up_o <= 1'b0;
    end else begin
      up_o <= 1'b1;
    end
  end

  always_ff @(posedge dclk_i, posedge reset_delayed) begin
    if (reset) begin
      dn_o <= 1'b0;
    end else begin
      dn_o <= 1'b1;
    end
  end

endmodule


module cp #(
  parameter Icp = 50e-6
)(
  input bit up_i,
  input bit dn_i,
  output real icp_o
);
  timeunit 1ns;
  timeprecision 1ps;

  real iup;
  always_comb begin
    if (up_i) begin
      iup = Icp;
    end else begin
      iup = 0;
    end
  end

  real idn;
  always_comb begin
    if (dn_i) begin
      idn = -Icp;
    end else begin
      idn = 0;
    end
  end

  always_comb begin
    icp_o = (iup + idn);
  end

endmodule


module lpf #(
  parameter real R1 = 1e3,
  parameter real C1 = 10e-12,
  parameter real Tstep = 10e-12
)(
  input real icp_i,
  output real vctrl_o
);
  timeunit 1ns;
  timeprecision 1ps;

  real delta_vc;
  real vc;

  always #(Tstep*1s) begin
    delta_vc = (icp_i / C1) * Tstep;
    vc += delta_vc;
  end

  always_comb begin
    vctrl_o = vc + R1*icp_i;
  end

endmodule


module vco #(
  parameter real Kvco = 1.8e9,
  parameter real Fmin = 0.1e9,
  parameter real Vmin = 0.1,
  parameter real Tstep = 10e-12
)(
  input real vctrl_i,
  output bit vclk_o
);
  timeunit 1ns;
  timeprecision 1ps;

  real frequency;

  always_comb begin
    if (vctrl_i < Vmin) begin
      frequency = Fmin;
    end else begin
      frequency = Fmin + (Kvco * (vctrl_i - Vmin));
    end
  end

  const real PI = 4*$atan(1);
  real phase;

  always #(Tstep*1s) begin
    phase += 2*PI*frequency*Tstep;
    if (phase > 2*PI) begin
      phase = 0;
    end
  end

  always_comb begin
    if (phase > PI) begin
      vclk_o = 1'b1;
    end else begin
      vclk_o = 1'b0;
    end
  end

endmodule


module fbdiv #(
  parameter int Ndiv = 10
)(
  input bit vclk_i,
  output bit dclk_o
);
  timeunit 1ns;
  timeprecision 1ps;

  int unsigned max_count;

  always_comb begin
    if (Ndiv >= 1) begin
      max_count = (Ndiv - 1);
    end else begin
      max_count = 0;
    end
  end

  int unsigned count;
  
  always_ff @(posedge vclk_i) begin
    if (count == max_count) begin
      count <= 0;
    end else begin
      count <= count + 1;
    end
  end

  always_comb begin
    if (count == max_count) begin
      dclk_o = 1'b1;
    end else begin
      dclk_o = 1'b0;
    end
  end

endmodule

`default_nettype wire