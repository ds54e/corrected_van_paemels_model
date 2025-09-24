`default_nettype none

module test_eq #(
  parameter real Fref = 0.1e9,
  parameter real Kvco = 1.8e9,
  parameter real Fmin = 0.1e9,
  parameter real Vmin = 0.1,
  parameter real Icp = 50e-6,
  parameter real R1 = 1e3,
  parameter real C1 = 10e-12,
  parameter int Ndiv = 10,
  parameter real Tau0 = 3.991e-08,
  parameter real V0 = 1.996e-01
);
  timeunit 1ns;
  timeprecision 1ps;

  const real Tref = 1/Fref;

  real tau, v;
  real a, b, c, d;
  real slk, sla;
  real lb;
  real fvco;
  real keff;

  let fmod(a, b) = (a - b*$floor(a/b));

  initial begin

    integer fh;
    fh = $fopen("tau_eq.csv", "w");
    $fdisplay(fh, "k,tau,v");

    tau = Tau0;
    v = V0;

    for (int k = 0; k < 100; k++) begin
      $fdisplay(fh, "%0d,%.4e,%.4e", k, tau, v);

      if (v < Vmin) begin
        fvco = Fmin;
        keff = 0.0;
      end else begin
        fvco = Fmin + Kvco * (v - Vmin);
        keff = Kvco;
      end

      a = keff*Icp / (2*C1);
      b = fvco + keff*Icp*R1;
      c = (Tref - fmod(tau, Tref))*fvco - Ndiv;
      slk = -(fvco - keff*Icp*R1)*tau + (keff*Icp / (2*C1))*(tau**2);
      sla = fmod(slk, Ndiv);
      lb = (Ndiv - sla) / fvco;
      d = sla + Tref*fvco - Ndiv;

      if (tau >= 0) begin
        if (c <= 0 && a != 0) begin
          tau = (-b + $sqrt(b**2 - 4*a*c)) / (2*a);
        end else begin
          tau = Ndiv / fvco - Tref + fmod(tau, Tref);
        end
      end else begin
        if (lb > Tref && a != 0) begin
          tau = (-b + $sqrt(b**2 - 4*a*d)) / (2*a);
        end else begin
          tau = lb - Tref;
        end
      end

      v += (Icp/C1)*tau;
    end

  end

endmodule


`default_nettype wire