%{
Function that optimizes a set of initial projections to minimize the
error between the backprojected reconstruction and the input target

INPUTS:
  params.angles = vector, angles at which the Radon and Inverse Radon transforms
                  are calculated; without accounting for absorption within the resin the
                  range of angles only needs to be 0 to 180 degrees
  params.max_iterations = scalar, maximum # of iterations in the optimization
  params.learningRate = scalar, size of step in gradient descent
  params.Rho = scalar, robustness parameter; size of erosion/dilation
  params.Theta = scalar, positivity constraint strictness
  params.Beta = scalar, memory effect
  params.parallel = 1 or 0, activates or deactivates parallel processing of
                    layers in 3D optimization
  initial_projections = matrix, matrix of initial guess projections; can be
                        2D (nR x nTheta) or 3D (nR x nTheta x nZ)
  target = matrix, voxelized design STL padded with zeros
  target_care_area = matrix, defines the dilated version of the target 
  params.verbose = 1 or 0, activates or deactivates visualization and display of
                   extra information about the optimization

OUTPUTS:
  opt_projections = matrix, 2D or 3D matrix of the 8-bit projections
                    needed for projection
  error = vector, error at each iteration of the optimization

Created by: Indrasen Bhattacharya 2017-05-07
Modified by: Joseph Toombs 09/2019

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

function [opt_projections,opt_reconstruction,error,thresholds] = optimize_projections(params,initial_projections,target,target_care_area)

if ~isfield(params,'verbose')
    params.verbose = 0;
end

% If params.parallel is undefined it defaults to 0
if ~isfield(params,'parallel')
    params.parallel = 0;
end

if params.verbose
    addpath('autoArrangeFigures_bin'); % add path to function for automatically arranging figures on monitor
    fprintf('Beginning optimization of projections\n');
    
    error_plot = 2;
    figure(error_plot)
    
    optimized_recon_plot = 3;
    figure(optimized_recon_plot)
    
    if strcmp(params.vol_viewer,'volshow') && numel(size(target)) ~= 2
        p = uipanel;
    end
    
    autoArrangeFigures(2,3)  % automatically arrange figures on screen

    tic;
    

end

if numel(size(target)) == 2
    [nX,nY] = size(target);
    nZ = 1;
    [nR,nTheta] = size(initial_projections);
else
    [nX,nY,~] = size(target);
    [nR,nTheta,nZ] = size(initial_projections);
end

% Preallocate vectors for storing information about results of optimization
error = zeros(params.max_iterations,1); % Error vector storing the total error as a function of the iteration number
thresholds = zeros(params.max_iterations,1); % Threshold for gelation

% Preallocate error matrices
opt_projections = initial_projections;
delta_projections = zeros(size(opt_projections)); % Projection space error
delta_projections_prev = zeros(size(opt_projections));
%delta_target = zeros(size(target)); % Error feedback

% Preallocate reconstruction
curr_reconstruction = zeros(size(target));
target_orig = target; % store a copy of the original padded_target


target_voxel_count = get_voxel_count(target);
curr_iter = 1;
while curr_iter <= params.max_iterations
    
%     [projections_power,~] = find_scale(opt_projections); % maps the current optimized projections to 8-bit numbers with the calibration curve of the projector
    
    % Backproject the intensity maps and reconstruct
    if params.resin_abs_coeff ~= 0
        if params.parallel
            parfor z = 1:nZ
                curr_reconstruction(:,:,z) = exp_iradon(params, opt_projections(:,:,z));
            end             
        else
            for z = 1:nZ
                curr_reconstruction(:,:,z) = exp_iradon(params, opt_projections(:,:,z));
            end     
        end % end if parallel
    else 
        if params.parallel
            parfor z = 1:nZ
                curr_reconstruction(:,:,z) = iradon(opt_projections(:,:,z), params.angles, 'none',nX);
            end        
        else
            for z = 1:nZ
                curr_reconstruction(:,:,z) = iradon(opt_projections(:,:,z), params.angles, 'none',nX);
            end
        end % end if parallel
     end % end params.resin_abs_coeff
    
    
%     curr_reconstruction = curr_reconstruction/sum(curr_reconstruction(:))*sum(target(:));
    curr_reconstruction = curr_reconstruction/max(curr_reconstruction(:));

%     curr_threshold = find_threshold(curr_reconstruction,target_orig,target_voxel_count)
    curr_threshold = 0.875;
%     curr_threshold = params.threshold; %DELETE
    thresholds(curr_iter) = curr_threshold; % store thresholds as a function of the iteration number

    
    [curr_voxel_count,coord_above_threshold] = get_voxel_count(curr_reconstruction,curr_threshold);
   
    
    % Apply Gauss filter to the padded_target to soften boundary
%     sigma_AA = params.sigma_init - (curr_iter-1)/(params.max_iterations-1)*(params.sigma_init - params.sigma_end); %Anti-aliasing parameter
%     target = imgaussfilt3(target_orig,sigma_AA); %anti-aliased version of the padded_target
    
    
    %Rho = Rho+0.006*k/nLoop1; %Forcing more robustness at every iteration
    
    %Define thresholding function
    mu = curr_threshold;
    mu_dilated = (1-params.Rho)*curr_threshold; %Recipe change
    mu_eroded = (1+params.Rho)*curr_threshold;
    

    % curr_reconstruction consists of normalized continuous values while
    % thresholded_reconstruction consists of sigmoid thresholded values of
    % curr_reconstruction
    thresholded_reconstruction = sigmoid((curr_reconstruction-mu), params.sigmoid);
    thresholded_reconstruction_eroded = sigmoid((curr_reconstruction-mu_eroded), params.sigmoid);
    thresholded_reconstruction_dilated = sigmoid((curr_reconstruction-mu_dilated), params.sigmoid);

%     thresholded_reconstruction = imgaussfilt3( sigmoid((curr_reconstruction-mu), params.sigmoid), sigma_AA);
%     thresholded_reconstruction_eroded = imgaussfilt3( sigmoid((curr_reconstruction-mu_eroded), params.sigmoid), sigma_AA);
%     thresholded_reconstruction_dilated = imgaussfilt3( sigmoid((curr_reconstruction-mu_dilated), params.sigmoid), sigma_AA);
%     


    
    
    % Calculate error between target [padded version of target] and thresholded negative truncated
    % reconstruction [thresholded_reconstruction] for exact, lower, and higher thresholds
    delta_target = (thresholded_reconstruction - target).*target_care_area; % Target space error   
    delta_target_eroded = (thresholded_reconstruction_eroded - target).*target_care_area; % Eroded version
    delta_target_dilated = (thresholded_reconstruction_dilated - target).*target_care_area; % Dilated version
 
    % Average the target space errors
    delta_target_feedback = (delta_target + delta_target_eroded + delta_target_dilated)/3;
    

    %%%%%%%%%%%% Charlie's pixel error rate %%%%%%%%%%
    [X,Y] = meshgrid(linspace(-size(target,1)/2,size(target,1)/2,size(target,1)),...
        linspace(-size(target,2)/2,size(target,2)/2,size(target,2)));
    R = sqrt(X.^2 + Y.^2);

    circleMask = logical(R.*(R<=size(target,1)/2));
    gelInds = find(circleMask & target_orig==1);
    voidInds = find(circleMask & ~target_orig);
    
    smallestGelDose = min(curr_reconstruction(gelInds),[],'all');
    maxVoidDose = max(curr_reconstruction(voidInds),[],'all');
    voidDoses = curr_reconstruction(voidInds);
    nPixOverlap = sum(voidDoses>=smallestGelDose);
    PER = nPixOverlap/(length(gelInds)+length(voidInds));
    error(curr_iter) = PER;
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%    
%     error(curr_iter) = norm(curr_reconstruction(:)-target(:))^2;
%     error(curr_iter) = sum(delta_target(:).^2)/curr_voxel_count;
%     error(curr_iter) = sum(delta_target(:).^2);

    



    if isfield(params,'tol')
        if (error(curr_iter) <= params.tol)
            break;
        end
    end

    %%%%%%%%%% EXPERIMENTAL %%%%%%%%%%%
%     mean_dose = mean(curr_reconstruction.*target,'all');
%     variance_dose = (curr_reconstruction - mean_dose).^2;
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    
    

    
    
    % update optimized projections over z-positions
    if params.parallel
        parfor z = 1:nZ
            delta_projections(:,:,z) = imresize(radon(delta_target_feedback(:,:,z), params.angles),[nR nTheta]); % transform error in target space to error in projection space
            gradientApprox = ((1-params.Beta)*delta_projections(:,:,z) + params.Beta*delta_projections_prev(:,:,z))/(1-params.Beta^curr_iter);
            opt_projections(:,:,z) = opt_projections(:,:,z) - params.learningRate*gradientApprox; %Update involving a controlled step size and memory effect
            opt_projections(:,:,z) = opt_projections(:,:,z).*(double(opt_projections(:,:,z) >= 0)+params.Theta*double(opt_projections(:,:,z) < 0)); %Impose positivity constraint using a relaxation parameter
        end
    else
        for z = 1:nZ 
            delta_projections(:,:,z) = imresize(radon(delta_target_feedback(:,:,z), params.angles),[nR nTheta]); % transform error in target space to error in projection space
            gradientApprox = ((1-params.Beta)*delta_projections(:,:,z) + params.Beta*delta_projections_prev(:,:,z))/(1-params.Beta^curr_iter);
            opt_projections(:,:,z) = opt_projections(:,:,z) - params.learningRate*gradientApprox; %Update involving a controlled step size and memory effect
            opt_projections(:,:,z) = opt_projections(:,:,z).*(double(opt_projections(:,:,z) >= 0)+params.Theta*double(opt_projections(:,:,z) < 0)); %Impose positivity constraint using a relaxation parameter
        end
    end
    delta_projections_prev = delta_projections;
        
%% Plotting    
    if params.verbose
        % Plot evolving error
        figure(error_plot)
        plot(1:params.max_iterations,error,'LineWidth',2); 
        xlim([1 params.max_iterations]); 
        xlabel('Iteration #')
        ylabel('Error')
        title_string = sprintf('Iteration = %2.0f',curr_iter);
        title(title_string)
        grid on
        
        if nZ == 1
            figure(optimized_recon_plot)
            imagesc(clip_to_circle(curr_reconstruction))
            colorbar
            colormap(CMRmap())
        elseif strcmp(params.vol_viewer,'volshow') && nZ ~= 1
            % Show evolving reconstruction using volshow
            figure(optimized_recon_plot)
            if curr_iter == 1
                vol = volshow(thresholded_reconstruction,'Parent',p,'Renderer','Isosurface','Isovalue',curr_threshold,'BackgroundColor','white','Isosurfacecolor','white');
                axis vis3d
                annotation(p,'textbox',[0.01 0 0.05 0.1],'String','Optimized reconstruction','FitBoxToText','on','Color','k','Edgecolor','none');
            else
                setVolume(vol,thresholded_reconstruction)
                vol.Isovalue = curr_threshold;
                axis vis3d                
            end
        elseif strcmp(params.vol_viewer,'pcshow') && nZ ~= 1
            % Alternative method of plotting reconstruction (requires Computer
            % Vision Toolbox)
            figure(optimized_recon_plot)
            pcshow(coord_above_threshold);
            axis vis3d
            colormap jet
            if curr_iter == 1
                annotation('textbox',[0.01 0 0.05 0.1],'String','Voxelized target','FitBoxToText','on','Color','w','Edgecolor','none');
            end
        end
        pause(0.05);
        
        
        
    end
%     if mod(curr_iter,30) == 0 && curr_iter ~= 30
%         cont_iters = input('Run more iterations? (0) stop;   (1) continue   :');
%         if cont_iters == 0
%             break
%         end
%     end
    curr_iter = curr_iter + 1;
end

% Output of the final optimized reconstruction dose profile
opt_reconstruction = curr_reconstruction;
if params.create_proj_for_2DCAL == 1 && isfield(params,'target_2D')
    tmp_proj = zeros(nX,length(params.angles),nX);
    for j = 1:length(params.angles)
        tmp_proj(:,j,:) = iradon([opt_projections(:,j,1),opt_projections(:,j,1)], [params.angles(j), params.angles(j)], 'none',nX);
    end
    opt_projections = tmp_proj;
elseif params.create_proj_for_2DCAL == 1
    fprintf('\nTarget should be 2D for creating projections for 2D planar CAL. Use params.target_2D to set the target\n');
end


[opt_projections,~] = find_scale(opt_projections);



if params.verbose
    runtime = toc;
    fprintf('Finished optimization of projections in %5.2f seconds\n\n',runtime);
end

end

function y = sigmoid(x,g)

    y = 1./(1+exp(-x*g));
    
end

