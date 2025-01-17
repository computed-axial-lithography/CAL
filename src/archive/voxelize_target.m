%{
Function that prepares the input target. If an STL file is given then it 
breaks the meshed STL file into discrete voxelized domain where the 
value at an index in the output target matrix is 1 where there is
solid and 0 where there is absence of solid. If the target is specified as
a 2D or 3D matrix, the target is prepared using the same post-processing of
applied to a voxelized STL target.

INPUTS:
    params.stl_filename     =   string, file name of the STL in the working directory
    params.target_2D        =   matrix, 2D matrix containing the input target slice
    params.target_3D        =   matrix, 3D matrix of the target 
    params.resolution       =   scalar, # of voxels for the output target matrix to have
                                in the minimum x,y,or z dimension of the design STL file
    params.verbose          =   1 or 0, activates or deactivates visualization of the
                                voxelized STL and additional information display

OUTPUTS:
    target                  =   matrix, 2D matrix of input target or 3D matrix of voxelized STL
    target_care_area        =   matrix, defines the dilated version of the target 

Created by: Indrasen Bhattacharya 2017-05-07
Modified by: Joseph Toombs 08/2019

----------------------------------------------------------------------------
Copyright � 2017-2020. The Regents of the University of California, Berkeley. All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in
   the documentation and/or other materials provided with the distribution.
3. Neither the name of the University of California, Berkeley nor the names of its contributors may be used to endorse or promote products
   derived from this software without specific prior written permission.
THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ''AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, 
THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS 
BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER 
IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED 
OF THE POSSIBILITY OF SUCH DAMAGE.
%}

function [target,target_care_area,domain_size] = voxelize_target(params)

if ~isfield(params,'verbose')
    params.verbose = 0;
end


% Run routine for 2D or 3D target or STL depending on which is specified
if isfield(params,'target_2D')
    if params.verbose
        fprintf('Preparing 2D target\n');
        tic;
    end
    target = params.target_2D;

    % Care area dilation with a disk structuring element
    se = strel('disk',1,4);
    target_care_area = imdilate(target,se);
    domain_size = size(target);
    
    if params.verbose
        figure(1)
        imagesc(target)
        colorbar
        colormap('hot')
        
        runtime = toc;
        fprintf('Finished preparation of target %.2f seconds\n\n',runtime);
    end
    
elseif isfield(params,'target_3D')
    if params.verbose
        fprintf('Preparing 3D target\n')
        tic;
    end
    target = params.target_3D;
    
    % Care area dilation with a shperical structuring element
    se = strel('sphere',2);
    target_care_area = imdilate(target,se);
    
    if params.verbose
        runtime = toc;
        fprintf('Finished preparation of target %.2f seconds\n\n',runtime);
    end
    
elseif isfield(params,'stl_filename')
    if params.verbose
        fprintf('Beginning preparation of target\n');
        tic;
    end

    addpath('STL_read_bin'); % add functions specific to the STL read to the path
    addpath('inferno_bin'); % add inferno colormap
    
    fv = stlread(params.stl_filename); % read STL
    fvV = fv.vertices;
    N = params.resolution; % # of voxels along the minimum dimension of the part
    Lx = max(fvV(:,1)) - min(fvV(:,1));
    Ly = max(fvV(:,2)) - min(fvV(:,2));
    Lz = max(fvV(:,3)) - min(fvV(:,3));
%     Lmin  = min([Lx Ly Lz]);
    
    
    nX = round(N*Lx/Lz);
    if(mod(nX,2) ~= 0)
        nX = nX+1;
    end

    nY = round(N*Ly/Lz);
    if(mod(nY,2) ~= 0)
        nY = nY+1;
    end

    nZ = N;
    if (mod(nZ,2) ~= 0)
       nZ = nZ+1;
    end
    

    % Define the coordinates of the planes at which the voxelization will occure
    gX = linspace(min(fvV(:,1)),max(fvV(:,1)),nX);
    gY = linspace(min(fvV(:,2)),max(fvV(:,2)),nY);   
    gZ = linspace(min(fvV(:,3)),max(fvV(:,3)),nZ); 

    target = double(VOXELISE(gX,gY,gZ,fv));


    % Largest dimension of projections is when the diagonal of the cubic target matrix is perpendicular to the projection angle 
    nR = round(sqrt(nX^2+nY^2));
    if (mod(nR,2)~=0)
        nR = nR+1;
    end
    target = padarray(target, [0.5*(nR-nX) 0.5*(nR-nY)], 0, 'both'); % Pad target with zeros
    
    domain_size = size(target);
    
    % Care area dilation with a spherical structuring element
    se = strel('sphere',10);
    target_care_area = imdilate(target,se);
    
    

    
    
    if params.verbose
        set(0,'Units','pixels')
        
        initial_target_plot = 1;
        figure(initial_target_plot)
        
        axis vis3d
        if strcmp(params.vol_viewer,'volshow')
                       
            p = uipanel;
            volshow(imgaussfilt3(target,0.01),'Parent',p,'Renderer','Isosurface','Isovalue',0.5,'BackgroundColor','w','Isosurfacecolor','w');
            axis vis3d
            
            annotation(p,'textbox',[0.01 0 0.05 0.1],'String','Voxelized target','FitBoxToText','on','Color','k','Edgecolor','none');
            
        elseif strcmp(params.vol_viewer,'pcshow')
            [~,coord_above_threshold] = get_voxel_count(target);
            
            pcshow(coord_above_threshold);
            axis vis3d
            colormap jet
            annotation('textbox',[0.01 0 0.05 0.1],'String','Voxelized target','FitBoxToText','on','Color','w','Edgecolor','none');

        end
        pause(0.1)
        runtime = toc;
        fprintf('Finished preparation of target %.2f seconds\n',runtime);
        fprintf('Target is [X,Y,Z]: %3.2f x %3.2f x %3.2f mm\n\n',nX*params.voxel_size,nY*params.voxel_size,nZ*params.voxel_size);
        
    end

else
    fprintf('No input geometry defined. Define input geometry by entering .stl filename in\n params.stl_filename or geometry in params.target_2D or params.target_3D.\n\n')
end