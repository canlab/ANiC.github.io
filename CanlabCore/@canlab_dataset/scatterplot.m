function fig_han = scatterplot(D, v1, v2, varargin)
% Scatterplot of two variables in dataset
%   - can be either event-level or subject-level
%   - event-level data is plotted as multi-line plot, one line per subject
%   - both variables must be valid names (case-sensitive)
%
% :Usage:
% ::
%
%    fig_han = scatterplot(D, varname1, varname2, [optional inputs])
%
% ..
%     Author and copyright information:
%
%     Copyright (C) 2013 Tor Wager
%
%     This program is free software: you can redistribute it and/or modify
%     it under the terms of the GNU General Public License as published by
%     the Free Software Foundation, either version 3 of the License, or
%     (at your option) any later version.
%
%     This program is distributed in the hope that it will be useful,
%     but WITHOUT ANY WARRANTY; without even the implied warranty of
%     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%     GNU General Public License for more details.
%
%     You should have received a copy of the GNU General Public License
%     along with this program.  If not, see <http://www.gnu.org/licenses/>.
% ..
%
%
% :Inputs:
%
%   **D:**
%        a canlab_dataset object
%
%   **v1:**
%        x variable
%
%   **v2:**
%        y variable
%
%
% :Optional Inputs:
%
%   **nofig:**
%        suppress creation of new figure
%
%   **subjtype:**
%        group by the following variable name
%
%   **wh_keep:**
%        followed by logical
%
%   **colors:**
%        followed by colors. 
%
%   **dorobust:**
%        do robust corr.  if enabled, colors will not work and subjtype grouping will not work well until
%        the function plot_correlation_samefig is updated, at some point in the future.
%
%
% :Outputs:
%
%   **fig_han:**
%        figure handle
%
% :Examples:
% ::
%
%    scatterplot(D, 'Anxiety', 'Frustration');
%    fig_han = scatterplot(D, D.Subj_Level.names{1}, D.Subj_Level.names{2});
%    scatterplot(D, D.Event_Level.names{1}, D.Event_Level.names{2});
%




fig_han = [];
dofig = 1;
grouping_var_name=[];
wh_keep = true(size(D.Subj_Level.id)); %everyone
colors{1}='k';
dorobust=0;

for i=1:length(varargin)
    if ischar(varargin{i})
        switch varargin{i}            
            case 'subjtype'
                grouping_var_name = varargin{i+1};
            case 'wh_keep'
                wh_keep = varargin{i+1};
            case 'nofig'
                dofig=0;
            case {'robust', 'dorobust'}
                dorobust=1;
        end
    end
end

[dat1, dcell1, whlevel1] = get_var(D, v1, wh_keep, varargin{:});
[dat2, dcell2, whlevel2] = get_var(D, v2, wh_keep, varargin{:});
dat1_level{1}=dat1; %to support grouping
dat2_level{1}=dat2; 

if whlevel1 ~= whlevel2
    disp('No plot: Variables are not at same level of analysis.');
    return
end

if isempty(dat1) || isempty(dat2)
    % skip
    disp('No plot: Missing variables');
    return
end

if dofig
    fig_han = create_figure([v1 '_vs_' v2]);
else
    fig_han = gcf;
end


if ~isempty(grouping_var_name)  % We have a grouping variable
    
    %get a wh_keep for all the levels
    [grouping_var, dum, dum, descripGrp] = D.get_var(grouping_var_name, wh_keep);
    
    levels = unique(grouping_var);
    
    % colors
    colors = {'r' 'b' 'g' 'k' 'y'};
    colors = colors(1:length(levels));
    wh = strcmp(varargin, 'colors');
    if any(wh), colors = varargin{find(wh)+1}; end

        
    for i=1:length(levels)
        
        wh_keep_lev{i} = (D.get_var(grouping_var_name,wh_keep)==levels(i));
        
        dat1_level{i} = dat1(wh_keep_lev{i},:);
        dat2_level{i} = dat2(wh_keep_lev{i},:);     
    end
    
end  
    
  
for i=1:length(dat1_level)    
    
    switch whlevel1
    case 1  
        x=dat1_level{i}; y= dat2_level{i};
            
        if dorobust
            plot_correlation_samefig(x,y,[],[],[],1)
            grid off
        else
            scatter(x,y, 65,  'MarkerFaceColor', colors{i}, 'MarkerEdgeColor', colors{i});%, 'within')
            inds = isnan(x) | isnan(y);
            h = refline(polyfit(x(~inds),y(~inds),1))
            set(h, 'Color', colors{i}, 'LineWidth', 2)
        end
        
        % correlation
        shortstr = correlation_subfunction(whlevel1, x, y, v1, v2);


    case 2
        
        han = line_plot_multisubject(dcell1, dcell2, varargin{:});
        
        % correlation
        shortstr = correlation_subfunction(whlevel1, dcell1, dcell2, v1, v2);

    otherwise
        error('Illegal level variable returned by get_var(D)');
end

set(gca, 'FontSize', 24)

xlabel(strrep(v1, '_', ' '));
ylabel(strrep(v2, '_', ' '));

xloc = mean(dat1(:)) + std(dat1(:));
yloc = mean(dat2(:)) + std(dat2(:));

text(xloc, yloc, shortstr, 'FontSize', 24);
axis tight

end

end % function





function shortstr = correlation_subfunction(whlevel1, dat1, dat2, v1, v2)

shortstr = [];

switch whlevel1
    case 1
        
    [wasnan, dat1, dat2] = nanremove(dat1, dat2);

    [rtotal, ptotal] = corr(dat1, dat2); 

        shortstr = sprintf('r = %3.2f\n', rtotal);
        str = sprintf('(%s, %s): r = %3.2f, p = %3.6f\n', v1, v2, rtotal, ptotal);
        disp(str)
        
    case 2
        Xc = cat(1, dat1{:});
        Yc = cat(1, dat2{:});
        rtotal = corr(Xc, Yc);

        for i = 1:length(dat1)
            x1{i} = scale(dat1{i}, 1); % mean-center
            x2{i} = scale(dat2{i}, 1);
        end
        
        rwithin = corr(cat(1, x1{:}), cat(1, x2{:}));
        
        % sqrt var increase when not removing between-subject random intercepts
        rbetween = sqrt(rwithin .^ 2 - rtotal .^ 2);
        
        % get P-values
        % within var: T-test on slopes for each subject
        for i = 1:length(dat1)
            b(i,:) = glmfit(dat1{i}, dat2{i});      % total
            b2(i,:) = glmfit(x1{i}, x2{i});         % within
        end
        
        [~, ptotal] = ttest(b(:, 2));
        [~, pwithin] = ttest(b2(:, 2));

        shortstr = sprintf('r = %3.2f', rtotal);
        
        str = sprintf('(%s, %s): \nr across all data: %3.2f, p = %3.6f\nr within subjects: %3.2f, p = %3.6f\nr between subjects: %3.2f\n', v1, v2, rtotal, ptotal, rwithin, pwithin, rbetween);
        disp(str)
        
    otherwise ('Illegal value!');
        
end

end
