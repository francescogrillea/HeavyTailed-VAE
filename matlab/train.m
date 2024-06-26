function [netE, netD, stats] = train(netE, netD, XTrain, config)

if nargin < 4
    error("Must provide a config")
end

batchDimension = length(config.inputSize) + 1;

if config.interactiveLoss
    % Calculate the total number of iterations for the training progress monitor
    numObservationsTrain = size(XTrain, batchDimension);
    numIterationsPerEpoch = ceil(numObservationsTrain / config.batchSize);
    numIterations = config.numEpochs * numIterationsPerEpoch;

    % Initialize the training progress monitor
    monitor = trainingProgressMonitor( ...
    Metrics="Loss", ...
    Info="Epoch", ...
    XLabel="Iteration");
else
    monitor.Stop = false;
end


% Create a minibatchqueue object that processes and manages mini-batches of images during training
dsTrain = arrayDatastore(XTrain, IterationDimension=batchDimension);
numOutputs = 1;

mbq = minibatchqueue(dsTrain, numOutputs, ...
    MiniBatchSize = config.batchSize, ...
    MiniBatchFcn=@(dataX) cat(batchDimension, dataX{:}), ...
    MiniBatchFormat=config.batchFormat);


% Initialize the parameters for the Adam solver.
trailingAvgE = [];
trailingAvgSqE = [];
trailingAvgD = [];
trailingAvgSqD = [];

stats = struct;
epoch = 0;
iteration = 0;
epochTimes = [];
lossHistory = [];

% Loop over epochs.
while epoch < config.numEpochs && ~monitor.Stop
    tic;
    epoch = epoch + 1;
    % fprintf("Epoch %d\n", epoch);

    % Shuffle data.
    shuffle(mbq);

    % Loop over mini-batches.
    while hasdata(mbq) && ~monitor.Stop
        iteration = iteration + 1;

        % Read mini-batch of data.
        X = next(mbq);
        X_true = X;
        if isfield(config, "noise")
            if strcmp(config.noise, "normal")
                X = X_true + randn(size(X));
            elseif strcmp(config.noise, "logNormal")
                X = X_true + lognrnd(0, 0.1, size(X));
            elseif strcmp(config.noise, "uniform")
                X = X_true + rand(size(X));
            end
        end

        if strcmp(config.dataset, "mnist3d")
            X_true = X(:,:,1,:);
        end

        % Evaluate loss and gradients.
        [loss,gradientsE,gradientsD] = dlfeval(@modelLoss,netE, netD, X, X_true, config.KL);

        if loss > 1e6
            disp("");
        end

        % Update learnable parameters.
        [netE,trailingAvgE,trailingAvgSqE] = adamupdate(netE, ...
            gradientsE, trailingAvgE, trailingAvgSqE, iteration, config.learningRate);

        [netD, trailingAvgD, trailingAvgSqD] = adamupdate(netD, ...
            gradientsD, trailingAvgD, trailingAvgSqD, iteration, config.learningRate);

        if config.interactiveLoss
            % Update the training progress monitor.
            recordMetrics(monitor, iteration, Loss=loss);
            updateInfo(monitor, Epoch=epoch + " of " + config.numEpochs);
            monitor.Progress = 100*iteration/numIterations;
        end
        lossHistory = [lossHistory, loss];
    end
    stats.finalLoss = loss;
    elapsedTime = toc;
    fprintf("Epoch %d\tcompleted in %.4fs\n", epoch, elapsedTime);
    epochTimes = [epochTimes, elapsedTime];

end
stats.avgEpochTime = mean(epochTimes);
stats.lossHistory = lossHistory;


function [loss, gradientsE, gradientsD] = modelLoss(netE, netD, X, X_true, beta)

    if nargin < 4
        X_true = X;
    end

    % Forward through encoder.
    [Z, KL] = forward(netE, X);
    
    % Forward through decoder.
    Y = forward(netD, Z);
    
    % Calculate loss and gradients.
    reconstructionLoss = mse(Y, X_true);
    
    KL = mean(KL, "all");
    loss = (reconstructionLoss + beta * KL) / (1+beta);
    
    [gradientsE,gradientsD] = dlgradient(loss, netE.Learnables, netD.Learnables);
end

end