%{ 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
Copyright (C) 2020-2021  Hayden Taylor Lab, University of California, Berkeley
Website https://github.com/computed-axial-lithography/CAL-software-Matlab

This file is part of the CAL-software-Matlab toolbox.

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%} 
classdef PTB
    
    properties
        monitor_id
        SLM
        tex
    end
    
    methods
        function obj = PTB(varargin)
            
            try
                ver_str = PsychtoolboxVersion;
            catch
                error('Pyschtoolbox is not installed or is improperly installed');
            end
            
            if str2num(ver_str(1)) < 3
                error('Pyschtoolbox version 3 is required. The installed version is %s.',ver_str);
            end
            
            AssertOpenGL;
            KbName ('UnifyKeyNames'); % Use same key names on all operating systems.

            
            if nargin == 1
                obj.monitor_id = varargin{1};
            else
                screens = Screen('Screens');
                obj.monitor_id = max(screens);
            end
            
            
            sca % clear possible third screen window == screen('CloseAll')
            

            % Define the SLM struct
            Screen('Preference', 'Verbosity', 1);
            Screen('Preference', 'VisualDebugLevel', 1);
            try % first try to open window after performing sync tests
                Screen('Preference','SkipSyncTests',0);
                obj.SLM = Screen('OpenWindow',obj.monitor_id);
            catch % if this fails, display warning and skip the sync tests
                warning('Warning! Failed to open PyschToolbox window after Sync Tests. Continuing projection by skipping Sync Tests. Ensure that images are displaying correctly.');
                Screen('Preference','SkipSyncTests',2);
                obj.SLM = Screen('OpenWindow',obj.monitor_id);
            end
            
            obj.flipBlankImage();
        end
        
        function [obj] = prepareImages(obj,images)
            if isa(images,'ImageSetObj')
                num_images = size(images.image_set,2);
                obj.tex = zeros(1,num_images);
                for i = 1:num_images
                    obj.tex(i) = Screen('MakeTexture',obj.SLM,images.image_set{i});
                    fprintf('Creating OpenGL texture: %4.0f/%4.0f\n',i,num_images);
                end
            elseif isa(images,'numeric')
                % assumes only one image
                obj.tex = Screen('MakeTexture',obj.SLM,images);
            end
        end
        
        function refresh(obj,i)
            Screen('DrawTexture',obj.SLM,obj.tex(i));
            Screen('Flip',obj.SLM);
        end
        
        function [] = show(obj,varargin)
            
            if nargin == 1
                Screen('DrawTexture',obj.SLM,obj.tex);
                
            else
                i = varargin{1};
                Screen('DrawTexture',obj.SLM,obj.tex(i));
            end
            
            Screen('Flip',obj.SLM);
        end
        
        function [] = flipBlankImage(obj)
            Screen('FillRect', obj.SLM, 0);
            Screen(obj.SLM,'Flip');   
        end
        
        function [] = drawImage(obj,image)
            image_tex = Screen('MakeTexture',obj.SLM,image);
            Screen('DrawTexture',obj.SLM,image_tex);
            Screen('Flip',obj.SLM);
        end
    end
    
    methods (Static = true)     
        function key_number = checkKey()
            % 19 for pause/break, 32 for space, 27 for esc, 9 for tab
            [~,~,key_code,~] = KbCheck;
            key_number = find(key_code); 
        end
        
        function [is_name] = isKeyName(pressed_key,test_name)
            is_name = KbName(test_name) == pressed_key;
        end
        
        
        
    end
end

