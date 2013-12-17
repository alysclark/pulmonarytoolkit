classdef PTKContextHierarchy < handle
    % PTKContextHierarchy. Part of the internal framework of the Pulmonary Toolkit.
    %
    %     This class is used to switch beteen different contexts.
    %
    %     There are a number of contexts, which each represent particular
    %     regions of the lung. For example, the OriginalImage context is the
    %     entire image, whereas the LungROI is the parrallipiped region
    %     containing the lungs and airways. The LeftLung and RightLung comprise
    %     just the voumes of the left and right lung respectively.
    %
    %     Context sets describe a collection of related contexts. For example,
    %     the SingleLung context set contains LeftLung and RightLung.
    %
    %     Each plugin specifies its context set, which is the domain of the
    %     results produced by the plugin. Some plugins operate over the whole
    %     LungROI region, while some operate on individual lungs.
    %
    %     This class manages the situations where a result is requested for a
    %     particualar context (e.g. LungROI) but the plugin defines a different
    %     context set (e.g. SingleLung). The LungROI can be built from the two
    %     contexts in the SingleLung set. Therefore in this case, the plugin is run twice,
    %     once for the left and once for the right lung. Then the resutls are
    %     combined to produce the result for the LungROI context.
    %
    %     Thie class manages this heirarchy of contexts and context sets. In
    %     this way plugins can operate on whichever context is appropriate,
    %     while results can be requested for any context, and the conversions
    %     are handled automatically.
    %
    %
    %     Licence
    %     -------
    %     Part of the TD Pulmonary Toolkit. http://code.google.com/p/pulmonarytoolkit
    %     Author: Tom Doel, 2012.  www.tomdoel.com
    %     Distributed under the GNU GPL v3 licence. Please see website for details.
    %    
    
    
    properties
        ContextSets
        Contexts
        
        DependencyTracker
        ImageTemplates
        Reporting
    end
    
    methods
        function obj = PTKContextHierarchy(dependency_tracker, image_templates, reporting)
            obj.DependencyTracker = dependency_tracker;
            obj.ImageTemplates = image_templates;
            obj.Reporting = reporting;
            
            % Create the hierarchy of context types
            obj.ContextSets = containers.Map;
            full_set =  PTKContextSetMapping(PTKContextSet.OriginalImage, []);
            roi_set = PTKContextSetMapping(PTKContextSet.LungROI, full_set);
            lungs_set = PTKContextSetMapping(PTKContextSet.Lungs, roi_set);
            single_lung_set = PTKContextSetMapping(PTKContextSet.SingleLung, lungs_set);
            lobe_set = PTKContextSetMapping(PTKContextSet.Lobe, single_lung_set);
            any_set = PTKContextSetMapping(PTKContextSet.Any, []);
            obj.ContextSets(char(PTKContextSet.OriginalImage)) = full_set;
            obj.ContextSets(char(PTKContextSet.LungROI)) = roi_set;
            obj.ContextSets(char(PTKContextSet.Lungs)) = lungs_set;
            obj.ContextSets(char(PTKContextSet.SingleLung)) = single_lung_set;
            obj.ContextSets(char(PTKContextSet.Lobe)) = lobe_set;
            obj.ContextSets(char(PTKContextSet.Any)) = any_set;
            
            % Create the hierarchy of contexts
            obj.Contexts = containers.Map;
            full_context =  PTKContextMapping(PTKContext.OriginalImage, full_set, @PTKCreateTemplateForOriginalImage, []);
            roi_context = PTKContextMapping(PTKContext.LungROI, roi_set, @PTKCreateTemplateForLungROI, full_context);
            lungs_context = PTKContextMapping(PTKContext.Lungs, lungs_set, @PTKCreateTemplateForLungs, roi_context);
            left_lung_context = PTKContextMapping(PTKContext.LeftLung, single_lung_set, @PTKCreateTemplateForSingleLung, lungs_context);
            right_lung_context = PTKContextMapping(PTKContext.RightLung, single_lung_set, @PTKCreateTemplateForSingleLung, lungs_context);
            right_upper_lobe_context = PTKContextMapping(PTKContext.RightUpperLobe, lobe_set, @PTKCreateTemplateForLobe, right_lung_context);
            right_middle_lobe_context = PTKContextMapping(PTKContext.RightMiddleLobe, lobe_set, @PTKCreateTemplateForLobe, right_lung_context);
            right_lower_lobe_context = PTKContextMapping(PTKContext.RightLowerLobe, lobe_set, @PTKCreateTemplateForLobe, right_lung_context);
            left_upper_lobe_context = PTKContextMapping(PTKContext.LeftUpperLobe, lobe_set, @PTKCreateTemplateForLobe, left_lung_context);
            left_lower_lobe_context = PTKContextMapping(PTKContext.LeftLowerLobe, lobe_set, @PTKCreateTemplateForLobe, left_lung_context);
            obj.Contexts(char(PTKContext.OriginalImage)) = full_context;
            obj.Contexts(char(PTKContext.LungROI)) = roi_context;
            obj.Contexts(char(PTKContext.Lungs)) = lungs_context;
            obj.Contexts(char(PTKContext.LeftLung)) = left_lung_context;
            obj.Contexts(char(PTKContext.RightLung)) = right_lung_context;
            obj.Contexts(char(PTKContext.RightUpperLobe)) = right_upper_lobe_context;
            obj.Contexts(char(PTKContext.RightMiddleLobe)) = right_middle_lobe_context;
            obj.Contexts(char(PTKContext.RightLowerLobe)) = right_lower_lobe_context;
            obj.Contexts(char(PTKContext.LeftUpperLobe)) = left_upper_lobe_context;
            obj.Contexts(char(PTKContext.LeftLowerLobe)) = left_lower_lobe_context;
        end
        
        function [result, output_image, plugin_has_been_run, cache_info] = GetResult(obj, plugin_name, output_context, linked_dataset_chooser, plugin_info, plugin_class, dataset_uid, dataset_stack, force_generate_image, allow_results_to_be_cached, reporting)
            % Determines the context and context type requested by the calling function
            if isempty(output_context)
                output_context = PTKContext.LungROI;
            end
            
            context_list = [];
            for next_output_context_set = PTKContainerUtilities.ConvertToSet(output_context);
                next_output_context = next_output_context_set{1};
                if isa(next_output_context, 'PTKContext')
                    context_list{end + 1} = next_output_context;
                elseif isa(next_output_context, 'PTKContextSet')
                    context_set_mapping = obj.ContextSets(char(next_output_context));
                    context_mapping_list = context_set_mapping.ContextList;
                    context_list = [context_list, PTKContainerUtilities.GetFieldValuesFromSet(context_mapping_list, 'Context')];
                else
                    reporting.Error('PTKContextHierarchy:UnknownOutputContext', 'I do not understand the requested output context.');
                end
            end
            
            plugin_has_been_run = false;
            result = [];
            for next_output_context_set = context_list;
                next_output_context = next_output_context_set{1};
                [next_result, output_image, next_plugin_has_been_run, cache_info] = obj.GetResultRecursive(plugin_name, next_output_context, linked_dataset_chooser, plugin_info, plugin_class, dataset_uid, dataset_stack, force_generate_image, allow_results_to_be_cached, reporting);
                plugin_has_been_run = plugin_has_been_run | next_plugin_has_been_run;
                if numel(context_list) == 1
                    result = next_result;
                else
                    result.(char(next_output_context)) = next_result;
                end
            end
        end
    end
    
    methods (Access = private)
        function [result, output_image, plugin_has_been_run, cache_info] = GetResultRecursive(obj, plugin_name, output_context, linked_dataset_chooser, plugin_info, plugin_class, dataset_uid, dataset_stack, force_generate_image, allow_results_to_be_cached, reporting);
            obj.ImageTemplates.NoteAttemptToRunPlugin(plugin_name, output_context);
            
            [result, output_image, plugin_has_been_run, cache_info] = obj.GetResultForAllContexts(plugin_name, output_context, linked_dataset_chooser, plugin_info, plugin_class, dataset_uid, dataset_stack, force_generate_image, allow_results_to_be_cached, reporting);
            
            % Allow the context manager to construct a template image from this
            % result if required
            obj.ImageTemplates.UpdateTemplates(plugin_name, output_context, result, plugin_has_been_run);
        end
        
        function [result, output_image, plugin_has_been_run, cache_info] = GetResultForAllContexts(obj, plugin_name, output_context, linked_dataset_chooser, plugin_info, plugin_class, dataset_uid, dataset_stack, force_generate_image, allow_results_to_be_cached, reporting)
            % Determines the type of context supported by the plugin
            plugin_context_set = plugin_info.Context;
            if isempty(plugin_context_set)
                plugin_context_set = PTKContextSet.LungROI;
            end
            plugin_context_set_mapping = obj.ContextSets(char(plugin_context_set));
            
            % Determines the context and context type requested by the calling function
            if isempty(output_context)
                output_context = PTKContext.LungROI;
            end
            output_context_mapping = obj.Contexts(char(output_context));
            output_context_set_mapping = output_context_mapping.ContextSet;
            output_context_set = output_context_set_mapping.ContextSet;
            
            % If the input and output contexts are of the same type, or if the
            % plugin context is of type 'Any', then proceed to call the plugin
            % OR (special case): for a context plugin ('ReplaceImage'), we do
            % not resize the image at all but just return it as it is
%             if (plugin_context_set == output_context_set) || (strcmp(plugin_info.PluginType, 'ReplaceImage')) || (plugin_context_set == PTKContextSet.Any)
            if (plugin_context_set == output_context_set) || (plugin_context_set == PTKContextSet.Any)
                [result, plugin_has_been_run, cache_info] = obj.DependencyTracker.GetResult(plugin_name, output_context, linked_dataset_chooser, plugin_info, plugin_class, dataset_uid, dataset_stack, allow_results_to_be_cached, reporting);

                % If the plugin has been re-run, then we will generate an output
                % image, in order to create a new preview image
                if (plugin_info.GeneratePreview && plugin_has_been_run)
                   force_generate_image = true;
                end
                
                % We generate an output image if requested, or if the plugin has been re-run (indictaing that we will need to generate a new preview image)
                if force_generate_image
                    template_callback = PTKTemplateCallback(linked_dataset_chooser, dataset_stack);
                    
                    if isa(result, 'PTKImage')
                        output_image = plugin_class.GenerateImageFromResults(result.Copy, template_callback, reporting);
                    else
                        output_image = plugin_class.GenerateImageFromResults(result, template_callback, reporting);
                    end
                else
                    output_image = [];
                end
                
            
            % Otherwise, if the plugin's context set is higher in the hierarchy
            % than the requested output, then get the result for the higher
            % context and then extract out the desired context
            elseif output_context_set_mapping.IsOtherContextSetHigher(plugin_context_set_mapping)
                higher_context_mapping = output_context_mapping.Parent;
                if isempty(higher_context_mapping)
                    reporting.Error('PTKContextHierarchy:UnexpectedSituation', 'The requested plugin call cannot be made as I am unable to determine the relationship between the plugin context and the requested result context.');
                end
                [result, output_image, plugin_has_been_run, cache_info] = obj.GetResultRecursive(plugin_name, higher_context_mapping.Context, linked_dataset_chooser, plugin_info, plugin_class, dataset_uid, dataset_stack, force_generate_image, allow_results_to_be_cached, reporting);
                
                result = obj.ReduceResultToContext(result, output_context_mapping, dataset_stack);
                if ~isempty(output_image)
                    output_image = obj.ReduceResultToContext(output_image, output_context_mapping, dataset_stack);
                end
                
            % If the plugin's context set is lower in the hierarchy, then get
            % run the plugin for all lower contexts and concatenate the results
            elseif plugin_context_set_mapping.IsOtherContextSetHigher(output_context_set_mapping)
                child_context_mappings = output_context_mapping.Children;
                result = [];
                output_image_template = obj.ImageTemplates.GetTemplateImage(output_context, dataset_stack);
                cache_info = [];
                plugin_has_been_run = false;
                first_run = true;
                for child_mapping = child_context_mappings
                    child_context = child_mapping{1}.Context;
                    [this_result, this_output_image, this_plugin_has_been_run, this_cache_info] = obj.GetResultRecursive(plugin_name, child_context, linked_dataset_chooser, plugin_info, plugin_class, dataset_uid, dataset_stack, force_generate_image, allow_results_to_be_cached, reporting);
                    if first_run
                        if isempty(this_output_image)
                            output_image = [];
                        else
                            output_image = this_output_image.Copy;
                            output_image.ResizeToMatch(output_image_template);
                            output_image.Clear;
                        end
                        first_run = false;
                    end
                    
                    template_image_for_this_result = obj.ImageTemplates.GetTemplateImage(child_context, dataset_stack);
                    
                    result.(char(child_context)) = this_result;
                    if ~isempty(output_image) && ~isempty(this_output_image)
                        output_image.ChangeSubImageWithMask(this_output_image, template_image_for_this_result);
                    end
                    cache_info.(char(child_context)) = this_cache_info;
                    plugin_has_been_run = plugin_has_been_run || this_plugin_has_been_run;
                    
                end
            else
                reporting.Error('PTKContextHierarchy:UnexpectedSituation', 'The requested plugin call cannot be made as I am unable to determine the relationship between the plugin context and the requested result context.');
            end
        end
        
        function result = ReduceResultToContext(obj, full_result, context_mapping, dataset_stack)
            if ~isa(full_result, 'PTKImage')
                result = full_result;
                return
            end
            
            template_image = obj.ImageTemplates.GetTemplateImage(context_mapping.Context, dataset_stack);
            
            % Make a copy before we resize
            result = full_result.Copy;
            result.ResizeToMatch(template_image);
            
            if template_image.ImageExists
                result.Clear;
                result.ChangeSubImageWithMask(full_result, template_image, true);
            end
        end
    end
    
end 

