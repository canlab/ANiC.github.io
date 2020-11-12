function cm = render_on_surface(obj, surface_handles, varargin)
% Map voxels in obj to isosurface (patch) handles in han and change surface colors according to values in obj
%
% :Usage:
% ::
%
%     cm = render_on_surface(obj, han, [optional inputs])
%
% - Object can be thresholded or unthresholded statistic_image, or other image_vector object
% - Uses only the first image in obj
%
% ..
%     Author and copyright information:
%
%     Copyright (C) 2020 Tor Wager
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
% :Inputs:
%
%   **obj:**
%       - image_vector object or subclasses
%       - e.g., fmri_data, thresholded or unthresholded statistic_image obj
%       - Uses only the first image in obj
%
%   **han:**
%       - A vector of one or more handles to patch objects (from surfaces)
%       - e.g., from patch(isosurface()), patch(isocaps()),
%       fmri_data.surface(), fmri_data.isosurface()
%       - Try: surface_handles = addbrain('left_cutaway');
%       - Try: surface_handles = addbrain('coronal_slabs_4');
%
% :Optional Inputs:
%   **'clim':**
%        Followed by [lowerlimit upperlimit] values to define color limits
%
%   **'colormap':**
%        Followed by the name of a Matlab colormap string
%        e.g., 'hot' (default), 'summer', 'winter'
%        - Creates a split colormap with gray values where object values
%        are zero, and colors where object values are nonzero
%
% :Outputs:
%
%   **renders colors on surfaces:**
%   Note that it is not always possible to reset the surfaces to their
%   original colors completely; you may have to redraw them if you change
%   the threshold/voxels that should be colored.
%
% :Examples:
% ::
%
% % Load a standard dataset (emotion regulation test data)
% % Perform a t-test, and render the results on a series of coronal slabs
%
% imgs = load_image_set('emotionreg', 'noverbose');
% t = ttest(imgs, .01, 'unc');
% figure; han = addbrain('coronal_slabs_4');
%
% % When the t map has positive and negative values, creates a special
% % bicolor split colormap that has warm colors for positive vals, and cool colors
% % for negative vals:
% render_on_surface(t, han);
%
% % You can set the color limits (here, in t-values)
% render_on_surface(t, han, 'clim', [-4 4]);
%
% % You can set the colormap to any Matlab colormap:
% render_on_surface(t, han, 'colormap', 'summer');
%
% % If your image is positive-valued only (or negative-valued only), a
% % bicolor split map will not be created:
% 
% t = threshold(t, [2 Inf], 'raw-between');
% render_on_surface(t, han, 'colormap', 'winter', 'clim', [2 6]);
%
% Note:
% To erase rendered blobs, use:
% sh = addbrain('eraseblobs', sh);

% Programmers' Notes:
% Tor Wager, Jan 2020
% desirable features:
% - Speed
% - control of colormap, can update
% - consistent value->color mapping across surfaces
% - need to know meaning of values, as they often represent statistic values
% - can re-run without changing colors
% - need to plot on isosurface or isocaps objects that use colormap to
% render gray-scale images. 
% This last part makes it a bit more complicated.
% Rendering only on solid-color patch objects from isosurfaces is easier:
%     c = isocolors(mesh_struct.X, mesh_struct.Y, mesh_struct.Z, mesh_struct.voldata, han(i));
%     set(han(i), 'FaceColor', 'interp')
%     c_orig = get(han(i), 'FaceVertexCData');
%     han(i).FaceVertexCData = c;
%
% But to render on either solid-color or gray scale colormapped patches, we want to use
% a split colormap.
%
% Different surface handles (to patches) will have FaceColor is an rgb
% triplet (for solid-color patches) or 'interp' for colormapped patches
% (like isocaps). This will be set to interp for all patches, but we have
% to preserve the existing colormapped grayscale values for interp patches
% by using the split colormap.
%
% Sept 2020: add solid-color 'color' option
% revise surface() method to use this

if any(~ishandle(surface_handles))
    error('Some surface_handles are not valid handles');
end


% -------------------------------------------------------------------------
% OPTIONAL INPUTS
% -------------------------------------------------------------------------

% cm = [];
nvals = 256;                % number of values for each segment of colormap
colormapname = 'hot';       % default colormap name (all Matlab defined colormaps OK)
custom_colormap = false;
pos_colormap = [];
neg_colormap = [];
clim = [];  
axis_handle = get(surface_handles, 'Parent');          % axis handle to apply colormap to; can be altered with varargin
allowable_keyword_value_pairs = {'clim' 'color' 'colormap' 'colormapname' 'axis_handle' 'pos_colormap' 'neg_colormap'};


% optional inputs with default values - each keyword entered will create a variable of the same name

for i = 1:length(varargin)
    if ischar(varargin{i})
        switch varargin{i}

            case 'color'
                % Special instructions for solid colors
                mycolor = varargin{i+1};
                validateattributes(mycolor, {'numeric'}, {'>=', 0, '<=', 1, 'size', [1 3]})
                
                nvals = 256;
                pos_colormap = repmat(mycolor, nvals, 1);
                
               
            case 'colormap'
                
                colormapname = varargin{i+1}; varargin{i+1} = [];
                custom_colormap = true;
                
            case allowable_keyword_value_pairs
                
                eval([varargin{i} ' = varargin{i+1}; varargin{i+1} = [];']);
            
            % eliminate this here because we may have passed many irrelevant values in in surface() call    
            %otherwise, warning(['Unknown input string option:' varargin{i}]);
        end
    end
end

% There are 2 ways to enter custom colormaps. 
% 1. By name
% 'colormap', [name of Matlab colormap]
%
% 2. Enter colormaps generated externally
% 'pos_colormap', followed by [n x 3] color vectors and/or
% 'neg_colormap', followed by [n x 3] color vectors
% 
% If you enter 'pos_colormap' / 'neg_colormap', these will be stacked and
% added to a gray colormap

if isempty(clim)
    
    % Get range of values in object
    % -----------------------------------------------------------------------
    % These will be used to map color limits
    % we will map values into the range of [1 nvals] where nvals = colormap length
    % Deal with possibility of multiple images in object
    % Exclude zeros
    if isa(obj, 'statistic_image')
        
        sig = logical(obj.sig);
        dat = obj.dat(sig);
        
    else
        
        wh = obj.dat ~= 0 & ~isnan(obj.dat);
        dat = obj.dat(wh);
        
    end
    
    clim = [min(dat(:)) max(dat(:))];  % clim: data values for min and max, should become min/max colors
    
    % if no variance, we have constant data values - special case.
    % reducing lower clim(1) will effectively map all data to max color value
    if abs(diff(clim)) < 100 * eps
        clim(1) = clim(2) - 1;
    end
    
end



% -------------------------------------------------------------------------
% Define colormap
% -------------------------------------------------------------------------

if ~isempty(pos_colormap) ||  ~isempty(neg_colormap)
    
    if any(strcmp(varargin, 'colormap'))
        error('Entering ''colormap'' argument and name cannot be done when entering custom colormaps in ''pos_colormap''/''neg_colormap''');
    end
    
    if ~isempty(pos_colormap) && ~isempty(neg_colormap) && size(pos_colormap, 1) ~= size(neg_colormap, 1)    
        error('Lengths of positive-color and negative-color colormaps must match.')
    end
    
    if ~isempty(pos_colormap)
        validateattributes(pos_colormap, {'numeric'}, {'>=', 0, '<=', 1, 'size', [NaN 3]})
        nvals = size(pos_colormap, 1);
    end
    
    if ~isempty(neg_colormap)
        validateattributes(neg_colormap, {'numeric'}, {'>=', 0, '<=', 1, 'size', [NaN 3]})
        nvals = size(neg_colormap, 1);
    end
    
    if isempty(pos_colormap)
        pos_colormap = hot(nvals);
    end
    
    if isempty(neg_colormap)
        neg_colormap = cool(nvals);
    end
        
    custom_colormap = true;
    
    % Build the colormap
    % -----------------------------------------------------------------------
    % Skip colormap generator, already
    % found the range of colors for pos/neg values to split around 0 here.
    % this sets the colormap for axis_handle
    cm = hotcool_split_colormap(nvals, clim, axis_handle, pos_colormap(1, :), pos_colormap(end, :), neg_colormap(1, :), neg_colormap(end, :));
        
    % colormapname = [neg_colormap; pos_colormap];   % colormapname is either name or [nvals x 3] matrix
    % nvals = size(colormapname, 1);                 % needs to match for color and gray maps to work right
    
else
    
    % Build the colormap
    % -----------------------------------------------------------------------
    % See notes below
    
    if custom_colormap
        
        cm = split_colormap(nvals, colormapname, axis_handle); % colormapname is either name or [nvals x 3] matrix
        
    elseif diff(sign(clim))
        
        % Default colormap for objects with - and + values
        cm = hotcool_split_colormap(nvals, clim, axis_handle);
        
    else
        cm = split_colormap(nvals, colormapname, axis_handle);
    end
    
end % custom posneg or other colormap

% -------------------------------------------------------------------------
% Change colors
% -------------------------------------------------------------------------

% Map object data values to indices in split colormap
% -----------------------------------------------------------------------
% Define mapping function. We will apply this later to vertex color data
% (only colored)
% Defining this here preserves the same mapping across different surfaces
% clim(1) mapped to lowest color, clim(2) to highest color
 map_function = @(c) 1 + nvals + (c - clim(1)) ./ range(clim) .* nvals;

% problem is that vertices near empty (zero) voxels get interpolated down to zero
%map_function = @(c) 1 + nvals + (c - 0) ./ range(clim) .* nvals;

% Reconstruct volume data
% -----------------------------------------------------------------------
% Needed to map to vertices later
[~, ~, mesh_struct] = reconstruct_image(obj);                % get volume data for slices

% Deal with edge interpolation effects
% problem is that vertices near empty (zero) voxels get interpolated down to zero
% solution: map all non-zero voxels to lowest limit value
% Need to preserve signs as well.
% Then replace empty voxels with gray
% lower lim to interp to 10% of the way towards zero,
% preserving sign
% lowerclimit = linspace(clim(1), 0, 10);
% lowerclimit = lowerclimit(2);           
% mesh_struct.voldata(mesh_struct.voldata == 0) = lowerclimit;
% lowerclimit = 0; ... wh = c == 0 | isnan(c); 

for i = 1:length(surface_handles)
    % For each surface handle entered
    % -----------------------------------------------------------------------
     
    % Get vertex colors for image (obj) to map
    % -----------------------------------------------------------------------
    % Use isocolors to get colormapped values
    % Convert to index color in split colormap by adding nvals to put in
    % colored range
    % isocolors returns nans sometimes even when no NaNs in data 
    c = isocolors(mesh_struct.X, mesh_struct.Y, mesh_struct.Z, mesh_struct.voldata, surface_handles(i));
    
    wh = c == 0 | isnan(c);                    % save these to replace with gray-scale later
    
    c_colored = map_function(c);    % Map to colormap indices (nvals = starting range, nvals elements)
    
    % Get the original grayscale values
    % -----------------------------------------------------------------------
    % Exclude colored values
    
    c_gray = get(surface_handles(i), 'FaceVertexCData');
    
    if isempty(c_gray)
        
        % solid
        c_gray = repmat(round(nvals ./ 2), size(get(surface_handles(i), 'Vertices'), 1), 1);
        %c_colored(wh) = c_gray(wh);
        
    else
        %orig: c_gray(~wh) = (c_gray(~wh) - min(c_gray(~wh))) ./ range(c_gray(~wh)) .* nvals;
        
        if range(c_gray(wh)) == 0
            % Solid surface color
            % do nothing - skip rescaling
            % -----------------------------------------------------------------------
            %c_colored(wh) = c_gray(wh);
            
        else
            % rescale to gray part of colormap
            c_gray(wh) = (c_gray(wh) - min(c_gray(wh))) ./ range(c_gray(wh)) .* nvals;
            
            % Now merge graycsale and object-mapped colors
            % -----------------------------------------------------------------------
            % Everything that was originally zero in isocolors c
            % gets replaced with its original grayscale values in c_gray
            
            %c_colored(wh) = c_gray(wh);
            
        end
    end
    
c_colored(wh) = c_gray(wh);
    
    % Set object handle properties 
    % -----------------------------------------------------------------------
    % Change from 'scaled' to 'direct' mode

    % Save FaceVertexCData f or later
    prevdata = get(surface_handles(i), 'FaceVertexCData');
    set(surface_handles(i), 'UserData', prevdata);
    
    set(surface_handles(i), 'FaceVertexCData', c_colored);  % dot indexing sometimes works, sometimes doesn't...depends on handle type
    set(surface_handles(i), 'FaceColor', 'interp')
    set(surface_handles(i), 'CDataMapping', 'direct')
    set(surface_handles(i), 'EdgeColor', 'none');
    
end

colorbar_han = colorbar;
%set(colorbar_han, 'YLim', [nvals+1 2*nvals]);
set(colorbar_han, 'YLim', [nvals+1 2*nvals], 'YTick', [nvals+1 2*nvals], 'YTickLabel', round([clim(1) clim(2)] *100)/100);
set(gca, 'FontSize', 18)

% if isa(obj, 'statistic_image')
%     hotcool_colormap
% else 
%     colormap hot
% 
% end

end

% -----------------------------------------------------------------------
% -----------------------------------------------------------------------
% Colormap subfunctions
% -----------------------------------------------------------------------
% -----------------------------------------------------------------------

% - This will include nvals (generally 256) gray-scale and nvals colored
% values. If nvals = 256, the first 256 colors will be grayscale, and the
% next 256 color values.
% - If the object has positive and negative values, assume we want a split
% colormap showing negative values in cool colors, positive values in hot
% colors. The split colormap will also have different ranges for negative and
% positive values
% - If object is positive-valued or negative-valued only, assume we want a unipolar colormap 


function cm = hotcool_split_colormap(nvals, clim, axis_handle, varargin)
%
% cm = hotcool_split_colormap(nvals, clim, [lowhot hihot lowcool hicool]), each is [r g b] triplet
%
% Get hotcool split colormap (around 0)
% note: colormaps with these colors match spm_orthviews_hotcool_colormap used in orthviews()
% [.4 .4 .3], [1 1 0] (hot/pos) and [0 0 1], [.4 .3 .4] (cool/neg)

% Split blue/yellow
% lowhot = [.4 .4 .3];
% hihot = [1 1 0];
% lowcool = [0 0 1];
% hicool = [.4 .3 .4];

% Default addblobs - orange/pink
hihot = [1 1 0]; % max pos, most extreme values
lowhot = [1 .4 .5]; % [.8 .3 0]; % min pos
hicool = [0 .8 .8]; % [.3 .6 .9]; % max neg
lowcool = [0 0 1]; % min neg, most extreme values

if ~isempty(varargin)
    if length(varargin) < 4
        error('Enter no optional arguments or 4 [r g b] color triplets');
    end
    lowhot = varargin{1};
    hihot = varargin{2};
    lowcool = varargin{3};
    hicool = varargin{4};
end

cmgray = gray(nvals);

thr = 0;    % Threshold to split colormap into two colors

vec = linspace(clim(1), clim(2), nvals);
pos = find(vec > thr);
np = length(pos);

[hotcm, coolcm] = deal([]);

if np > 0
    hotcm = colormap_tor(lowhot, hihot, 'n', np);
    hotcm(1, :) = [.5 .5 .5]; % first element is gray
end

neg = find(vec < -thr);
nn = length(neg);

if nn > 0
    coolcm = colormap_tor(lowcool, hicool, 'n', nn);
    coolcm(end, :) = [.5 .5 .5]; % last element is gray
end

cm = [coolcm; hotcm];

cm = [cmgray; cm];

% Change colormap(s)
if isempty(axis_handle)
    colormap(cm)
    
elseif iscell(axis_handle)
    
    for i = 1:length(axis_handle)
        colormap(axis_handle{i}, cm);
    end
    
else
    colormap(axis_handle, cm);
end

end


function cm = split_colormap(nvals, cmcolor, axis_handle)
% Get split colormap with gray then colored values
% e.g., cm = split_colormap(256, [2 8], 'hot')
%
% colormapname is either name or [nvals x 3] matrix

%validateattributes(cmcolor, {'numeric' 'char'})

cmgray = gray(nvals);

if ischar(cmcolor)
    % Named colormap function
cmcolor = eval(sprintf('%s(%d)', cmcolor, nvals));
end

validateattributes(cmcolor, {'numeric'}, {'>=', 0, '<=', 1, 'size', [NaN 3]})
    
cm = [cmgray; cmcolor];

% Change colormap(s)
if isempty(axis_handle)
    colormap(cm)
    
elseif iscell(axis_handle)
    
    for i = 1:length(axis_handle)
        colormap(axis_handle{i}, cm);
    end
    
else
    colormap(axis_handle, cm);
end

end
