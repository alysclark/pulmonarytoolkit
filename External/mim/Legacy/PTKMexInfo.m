classdef PTKMexInfo < CoreCompiledFileInfo
    % PTKMexInfo. Structure for caching information about compiled mex files.
    %
    %     PTKMexInfo is an internal part of the Pulmonary Toolkit
    %     Framework and should not be called by your own code.
    %
    %     Licence
    %     -------
    %     Part of the TD Pulmonary Toolkit. https://github.com/tomdoel/pulmonarytoolkit
    %     Author: Tom Doel, 2012.  www.tomdoel.com
    %     Distributed under the GNU GPL v3 licence. Please see website for details.
    %
    
    methods
        function obj = PTKMexInfo(current_version, filename, extension, file_path, compiler_options, other_files)
            obj = obj@CoreCompiledFileInfo(current_version, filename, extension, file_path, compiler_options, other_files);
        end
        
        function converted = CoreCompiledFileInfo(obj)
            converted = CoreCompiledFileInfo();
            mco = ?PTKMexInfo;
            for property = mco.PropertyList'
                converted.(property.Name) = obj.(property.Name);
            end            
        end        
    end
    
end

