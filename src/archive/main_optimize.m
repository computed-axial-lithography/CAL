%{
----------------------------------------------------------------------------
Copyright © 2017-2020. The Regents of the University of California, Berkeley. All rights reserved.

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

%% Main projection-generation code
% Created by: Joseph Toombs 09/2019
% Email: jtoombs@berkeley.edu

%% Clean workspace
clc
clearvars
clear exp_iradon
close all

%% Input parameters

% General parameters
params = struct;
params.verbose = 1;                     % 1 to activate informational display; 0 to deactivate
params.vol_viewer = 'volshow';           % defines the type of volume viewer to be used; change to 'pcshow' if point cloud is desired
params.stl_filename = 'thinker.stl';        % 
% params.target_3D ;                    % use this to directly define the 3D target matrix
t = Tiff('C:\Users\Joseph Toombs\Downloads\resChart_padded.tif','r');
params.target_2D = double(read(t)==255);
% params.target_2D = create_target(500,'L'); % use this to directly define a 2D target matrix; create_target(#pixels in W and H of target, preset type) 'L','phantom','star','dots'
params.resolution = 150;                 % number of voxels in the dimension of Z-axis (height)
params.angles = 0:0.5:359.5;                % vector of real angles of projection; should be [0-180 deg]
params.parallel = 0;                    % 1 to activate parallel computing; 0 to deactivate; require Parallel Computing toolbox
params.create_proj_for_2DCAL = 0;       % 1 to activate gen of projections for 2D planar CAL; 0 to deactivate



%%% EXPERIMENTAL %%%
% Physical setup parameters (NOTE: if resin_abs_coeff is set angles should
% go from [0-360 deg]
params.voxel_size = 0.04;               % side length of cubic voxel in mm
params.vial_radius = 12.5;                % radius of resin container in mm
params.resin_abs_coeff = 0.00;             % absorption coefficient of resin at projector's center wavelength in 1/mm
params.light_intensity = 10;             % intensity of light source at the location of the vial's center axis in mW/cm^2

% Optimization parameters
params.learningRate = 0.8;            % Relaxation parameter: how far along do we move in the Newton iteration
params.Rho = 0.0;                      % Robustness parameter
params.Theta = 0.0;                    % Hybrid input-output parameter; Theta = 0 corresponds to perfect constraint
params.Beta = 0.0;                     % Memory Effect - how much of the previous iteration error is used in computing the current iteration update; Beta = 0 corresponds no memory
params.sigmoid = 100;                    % Sharpness of target dose boundary; typical values range from [50-200]
params.max_iterations = 60;             % maximum number of iterations in the optimization; prompt will ask to continue every 30 iterations
% params.tol;                           % use this to set the error tolerance of optimization

%% Optimization procedure
[target,target_care_area,params.domain_size] = voxelize_target(params); % prepare target 

projections = initialize_projections(params,target); % create initial guess of projections

[optimized_projections,optimized_reconstruction,error,thresholds] = optimize_projections(params,projections,target,target_care_area); % optimize projections to minimize error between target and reconstruction  


%% Display
show_projections(projections,[],4,'Initial projections') % display initial projections
show_projections(optimized_projections,[0,255],6,'Optimized projections') % display optimized projections
show_dose_slices(optimized_reconstruction./max(optimized_reconstruction,[],'all'),[0,1],5,'Dose slices') % display sliced dose profile

autoArrangeFigures(2,3)  % automatically arrange figures on screen

%% Dose distribution histogram
figure(10)
gelInds = find(target==1);
voidInds = find(~target);
hold on
histogram(optimized_reconstruction(voidInds)./max(optimized_reconstruction(:)),linspace(0,1,100),'facecolor','r','facealpha',0.4)
histogram(optimized_reconstruction(gelInds)./max(optimized_reconstruction(:)),linspace(0,1,100),'facecolor','b','facealpha',0.4)
xlim([0,1])
title('Dose distribution')
xlabel('Normalized Dose')
ylabel('Voxel Counts')
legend('Out-of-part Dose','In-part Dose')


