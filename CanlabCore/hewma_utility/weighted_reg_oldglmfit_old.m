function [means,stats] = weighted_reg_oldglmfit_old(Y,varargin)% Calculate weighted average using weighted linear least squares% See examples below for usage%% :Model:%%   Y_i = 1*Ypop + noise%% :Inputs:%%   **Y:**%        data matrix (nsub x T)%%   **w:**%        weights%%   **varY:**%        variance of data at each time point (nsub x T) + var between%% :Outputs:%%   **Ymean:**%        weighted mean of each column of Y%%   **dfe:**%        error degrees of freedom, adjusted for inequality of variance%        (Sattherwaite) and pooled across data columns%% Extended output in stats structure:%%   **stats.t:**%        t-values for weighted t-test%%   **stats.p:**%        2-tailed p-values for weighted t-test%%%   **r:**%        weighted correlation coeff across columns of Y%%   **xy:**%        weighted covariance matrix%%   **v:**%        weighted variance estimates for each column of Y%      - sqrt(v) is the standard error of the mean (or grp difference)%%%   **stats.fits:**%        fits  for each group (Ymean by group), low contrast weight group then high%        Fastest if no stats are asked for.%% Computation time:% For FULL stats report%  - Triples from 500 -> 1000 columns of Y, continues to increase%% For mean/dfe only, fast for full dataset (many columns of Y)%% :Examples:% ::%%    % Basic multivariate stats for 1000 columns of dat, no weighting%    % Multivariate covariances are meaningful if cols of Y are organized, e.g., timeseries%    [means,stats] = weighted_reg(dat(:,1:1000));%%    % The same, but return univariate stats only (good for large Y)%    [means,stats] = weighted_reg(dat,'uni');%% ..%    NOTE: TOR CHANGED INPUT TO ASSUME THAT WE SHOULD ENTER VARWI + VARBETWEEN% ..% ..%    Set up arguments% ..if nargin == 0, error('Must at least enter data as 1st argument.'); enddomultivariate = 1;     % multivariate covariance est for Ydobtwn = 0;             % between-subjects contrastbcon = []; zpdiff = []; w = []; varY = [];for i = 1:length(varargin)    arg = varargin{i};    if ischar(arg)        switch lower(arg)            case 'w', w = varargin{i+1};            case 'btwn', bcon = contrast_code(varargin{i+1});             case 'vary', varY = varargin{i+1};            case 'uni', domultivariate = 0;        end    endend[m,n] = size(Y);% fill in missing inputs with default valuesif ~is_entered(w), w = ones(m,1);  endif ~is_entered(varY), varY = ones(m,1); endif is_entered(bcon), dobtwn = 1; end% --------------------------------------% * Weights and computational steps% --------------------------------------W = diag(w);                    % Weight matrixX = repmat(1,m,1);              % Design matrix - 1 column of all ones to calculate average% and, separately, use bcon if that's enteredinvxwx = inv(X'*W*X);hat = invxwx * X'* W;         % hat matrix% Between-observations, if entered% ----------------------------------------if dobtwn    invxwx_diff = inv(bcon'*W*bcon);    hatdiff = invxwx_diff*bcon'*W;else    hatdiff = [];end% --------------------------------------% * Means and contrast% --------------------------------------Ymean = hat*Y;% Output: weighted population meanmeans.Ymean = Ymean;% Between-observation contrast, if entered% ----------------------------------------if dobtwn    zpdiff = hatdiff*Y;    % for output; fits for each group; low then high    grpfits = repmat(Ymean,2,1) + repmat(sort(unique(bcon)),1,n) .* repmat(zpdiff,2,1);    means.grpmeans = grpfits;endif nargout == 1, return, end% --------------------------------------% * Residuals% --------------------------------------e = Y - repmat(Ymean,m,1);         % residualsif dobtwn    % fitted values depending on group    fits = repmat(Ymean,m,1) + repmat(bcon,1,n) .* repmat(zpdiff,m,1);    ediff = Y - fits;end% --------------------------------------% * Degrees of freedom% --------------------------------------[dfe,dfediff] = get_dfe(m,n,X,hat,varY,dobtwn,hatdiff,bcon);if ~domultivariate    % ======================================    %    %    % Univariate stats: MSE, t, and p-values    %    %    % ======================================    % --------------------------------------    % * Mean squared error    % --------------------------------------    % Loop version of MSE: avoids out of memory errors for large voxel sets    MSE = zeros(1,n); for i=1:n, MSE(i) = e(:,i)'*W*e(:,i); end, MSE = MSE/dfe;    v = invxwx * MSE;       % variances for mean    if dobtwn        MSEdiff = zeros(1,n);        for i=1:n, MSEdiff(i) = ediff(:,i)'*W*ediff(:,i); end, MSEdiff = MSEdiff/dfediff;        vdiff = invxwx_diff * MSEdiff;       % variances for mean    end    % output    stats.descrip1 = 'Univariate stats for test against zero:';    stats.v = v;    stats.v_descrip = 'V = ste^2; variance of mean estimate';    stats.t = Ymean ./ sqrt(v);    stats.p = 2 * ( 1 - tcdf(abs(stats.t),dfe) );    stats.dfe = dfe;    if dobtwn        stats.descrip2 = 'Univariate stats for between-case contrast:';        stats.bcon = bcon;        stats.vdiff = vdiff;        stats.tdiff = fits ./ sqrt(v);        stats.pdiff = 2 * ( 1 - tcdf(abs(stats.tdiff),dfediff) );        stats.dfediff = dfediff;    endelse    % ======================================    %    %    % Multivariate stats: MSE, cov(Y), r(Y)    % Useful for simulating t-values under dependence    %    % ======================================    % --------------------------------------    % * Mean squared error    % --------------------------------------    % additional output: covariance matrix for Ymean and zdiff across time    % (columns)    % and correlation matrix for Ymean and zdiff    % used in Monte Carlo simulations for controlling false positives    % across columns    MSE = (e'*W*e)/dfe;             % Mean square error    if dobtwn        MSEdiff = (ediff'*W*ediff)/dfediff;    end    % --------------------------------------    % * Estimated covariance and correlation    %   Estimated between-subjects variance (v)    % --------------------------------------    xy = invxwx * MSE;           % Covariance matrix for Ymean;    xy = 0.5*(xy+xy');              % Remove rounding error    if dobtwn        xydiff = inv(bcon'*W*bcon)*MSEdiff;           % Covariance matrix for Ymean;        xydiff = 0.5*(xydiff+xydiff');    end    v = diag(xy);                   % Variance for Ymean    if dobtwn        vdiff = diag(xydiff);    end    r = xy./sqrt(v*v');             % Correlation matrix for Ymean    if dobtwn        rdiff = xydiff./sqrt(vdiff*vdiff');         % Correlation matrix for Ymean    end    stats.descrip1 = 'Multivariate stats for test against zero:';    stats.r = r;    stats.v = v;    stats.xy = xy;    stats.t = Ymean ./ sqrt(v');    stats.p = 2 * ( 1 - tcdf(abs(stats.t),dfe) );    if dobtwn        stats.descrip2 = 'Univariate stats for between-case contrast:';        stats.rdiff = rdiff;        stats.vdiff = vdiff;        stats.xydiff = xydiff;        stats.tdiff = fits ./ sqrt(vdiff');        stats.p = 2 * ( 1 - tcdf(abs(stats.tdiff),dfediff) );    endendreturnfunction [dfe,dfediff] = get_dfe(m,n,X,hat,varY,dobtwn,hatdiff,bcon)dfediff = [];% Set up residual-forming matrix% --------------------------------------dfe_v = zeros(n,1);R = eye(m) - X*hat;    % residual inducing matrix% contrast, if enteredif dobtwn    dfe_vdiff = zeros(n,1);    Rdiff = eye(m) - bcon * hatdiff;end% Calculate effective degrees of freedom% --------------------------------------have_unique_vars = size(varY,2) == n;if ~have_unique_vars    % Only one (pooled?) vector of variance estimates    % --------------------------------------    V = diag(varY(:,1));    dfe = (trace(R*V)^2)/trace(R*V*R*V);       % Satherwaite approximation    if dobtwn, dfediff = (trace(Rdiff*V)^2)/trace(Rdiff*V*Rdiff*V); endelse    % Variance estimates for each data vector    % --------------------------------------    for i=1:n,        % make diagonal matrix of variances        V = diag(varY(:,i));        dfe_v(i) = (trace(R*V)^2)/trace(R*V*R*V);       % Satherwaite approximation        if dobtwn            dfe_vdiff(i) = (trace(Rdiff*V)^2)/trace(Rdiff*V*Rdiff*V);        end    end    dfe = mean(dfe_v);               % Calculate average df over all columns (pool over data vectors)    if dobtwn        dfediff = mean(dfe_vdiff);    endendreturnfunction bool = is_entered(x)bool = exist('x','var') && ~isempty(x);return