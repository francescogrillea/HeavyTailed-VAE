classdef logNormalSamplingLayer < nnet.layer.Layer

    methods
        function layer = logNormalSamplingLayer(args)
            % layer = samplingLayer creates a sampling layer for VAEs.
            %
            % layer = samplingLayer(Name=name) also specifies the layer 
            % name.

            % Parse input arguments.
            arguments
                args.Name = "";
            end

            % Layer properties.
            layer.Name = args.Name;
            layer.Type = "LogNormalSampling";
            layer.Description = "Mean and log-variance log normal sampling";
            layer.OutputNames = ["out" "kl"];
            layer.NumOutputs = 2;
        end
    
        function [Z, KL] = predict(~,X)
            % [Z,mu,logSigmaSq] = predict(~,Z) Forwards input data through
            % the layer at prediction and training time and output the
            % result.
            %
            % Inputs:
            %         X - Concatenated input data where X(1:K,:) and 
            %             X(K+1:end,:) correspond to the mean and 
            %             log-variances, respectively, and K is the number 
            %             of latent channels.
            % Outputs:
            %         Z          - Sampled output
            %         KL         - KL divergence with LogNormal(0,1)

            % Data dimensions.
            numLatentChannels = size(X,1)/2;
            miniBatchSize = size(X,2);

            % Split statistics.
            mu = X(1:numLatentChannels,:);
            logSigmaSq = X(numLatentChannels+1:end,:);

            % Sample output.
            epsilon = randn(numLatentChannels,miniBatchSize,"like",X);
            sigma = exp(.5 * logSigmaSq);
            Z = exp(epsilon .* sigma + mu);
        
            KL = -0.5 * sum(1 + logSigmaSq - mu.^2 - exp(logSigmaSq), 1);
        end

    end
    
end