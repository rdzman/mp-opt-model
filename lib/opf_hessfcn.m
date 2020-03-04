function Lxx = opf_hessfcn(x, lambda, cost_mult, om, Hs)
%OPF_HESSFCN  Evaluates Hessian of Lagrangian for AC OPF.
%   LXX = OPF_HESSFCN(X, LAMBDA, COST_MULT, OM)
%   LXX = OPF_HESSFCN(X, LAMBDA, COST_MULT, OM, HS)
%
%   Hessian evaluation function for AC optimal power flow, suitable
%   for use with MIPS or FMINCON's interior-point algorithm.
%
%   Inputs:
%     X : optimization vector
%     LAMBDA (struct)
%       .eqnonlin : Lagrange multipliers on power balance equations
%       .ineqnonlin : Kuhn-Tucker multipliers on constrained branch flows
%     COST_MULT : (optional) Scale factor to be applied to the cost
%          (default = 1).
%     OM : OPF model object
%     HS : (optional) sparse matrix with tiny non-zero values specifying
%          the fixed sparsity structure that the resulting LXX should match
%
%   Outputs:
%     LXX : Hessian of the Lagrangian.
%
%   Examples:
%       Lxx = opf_hessfcn(x, lambda, cost_mult, om);
%       Lxx = opf_hessfcn(x, lambda, cost_mult, om, Hs);
%
%   See also OPF_COSTFCN, OPF_CONSFCN.

%   MATPOWER
%   Copyright (c) 1996-2020, Power Systems Engineering Research Center (PSERC)
%   by Ray Zimmerman, PSERC Cornell
%   and Carlos E. Murillo-Sanchez, PSERC Cornell & Universidad Nacional de Colombia
%
%   This file is part of MATPOWER.
%   Covered by the 3-clause BSD License (see LICENSE file for details).
%   See https://matpower.org for more info.

%% ----- evaluate d2f -----
[f, df, d2f] = opf_costfcn(x, om);
d2f = d2f * cost_mult;

%%----- evaluate Hessian of power balance constraints -----
d2G = om.eval_nln_constraint_hess(x, lambda.eqnonlin, 1);

%%----- evaluate Hessian of flow constraints -----
d2H = om.eval_nln_constraint_hess(x, lambda.ineqnonlin, 0);

%%-----  do numerical check using (central) finite differences  -----
if 0
    mpc = om.get_mpc();
    nl = size(mpc.branch, 1);       %% number of branches
    if nargin < 9
        il = (1:nl);            %% all lines have limits by default
    end

    nx = length(x);
    step = 1e-5;
    num_d2f = sparse(nx, nx);
    num_d2G = sparse(nx, nx);
    num_d2H = sparse(nx, nx);
    for i = 1:nx
        xp = x;
        xm = x;
        xp(i) = x(i) + step/2;
        xm(i) = x(i) - step/2;
        % evaluate cost & gradients
        [fp, dfp] = opf_costfcn(xp, om);
        [fm, dfm] = opf_costfcn(xm, om);
        % evaluate constraints & gradients
        [Hp, Gp, dHp, dGp] = opf_consfcn(xp, om);
        [Hm, Gm, dHm, dGm] = opf_consfcn(xm, om);
        num_d2f(:, i) = cost_mult * (dfp - dfm) / step;
        num_d2G(:, i) = (dGp - dGm) * lambda.eqnonlin   / step;
        num_d2H(:, i) = (dHp - dHm) * lambda.ineqnonlin / step;
    end
    d2f_err = full(max(max(abs(d2f - num_d2f))));
    d2G_err = full(max(max(abs(d2G - num_d2G))));
    d2H_err = full(max(max(abs(d2H - num_d2H))));
    if d2f_err > 1e-6
        fprintf('Max difference in d2f: %g\n', d2f_err);
    end
    if d2G_err > 1e-5
        fprintf('Max difference in d2G: %g\n', d2G_err);
    end
    if d2H_err > 1e-6
        fprintf('Max difference in d2H: %g\n', d2H_err);
    end
end

Lxx = d2f + d2G + d2H;


%% force specified sparsity structure
if nargin > 4
    %% add sparse structure (with tiny values) to current matrices to
    %% ensure that sparsity structure matches that supplied
    Lxx = Lxx + Hs;

%     %% check sparsity structure against that supplied
%     if nnz(Lxx) ~= nnz(Hs)
%         fprintf('=====> nnz(Lxx) is %d, expected %d <=====\n', nnz(Lxx), nnz(Hs));
%     else
%         [iHs, jHs] = find(Hs);
%         [iH, jH] = find(Lxx);
%         if any(iH ~= iHs) || any(jH ~= jHs)
%             fprintf('=====> structure of Lxx is not as expected <=====\n');
%         end
%     end
end
