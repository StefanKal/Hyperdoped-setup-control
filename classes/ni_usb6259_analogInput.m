classdef ni_usb6259_analogInput < handle
    
    properties
        instr;
        daq_channel; %daq_channel is which analog input channel on the DAQ is being used
        SampleRate = 200000;
        SamplesPerTrigger;
        AcquisitionTime = 0.5; %AcquisitionTime is initialized to 5 seconds
        datastream;
        timestream;
        abstime;
        eventsthrown;
        voltage;
        datastream_smoothed;
    end
         
    methods
        
        function obj = ni_usb6259_analogInput(daq_channel)
            %ai_channel is an integer corresponding to which analog input
            %channel you are using
            disp('Initializing NI USB6259 analog input ...')
            obj.instr = analoginput('nidaq', 'Dev1');
            addchannel(obj.instr, daq_channel); %this adds the channel to obj.instr, and you can see its properties by looking at obj.instr.Channel
            obj.daq_channel = daq_channel;
            obj.instr.Channel.InputRange = [-10 10]; %the Ophir puts out 0 to 1 V, but we set the InputRange to [-1 1] to make sure no error gets thrown near 0
            obj.setSampleRate(obj.SampleRate);
            disp('Initialization complete.')
        end
        
        function setSampleRate(obj,SampleRate)
            %Sets the SampleRate while keeping the AcquisitionTime constant
            set(obj.instr,'SampleRate',SampleRate);
            obj.SampleRate=SampleRate;
            set(obj.instr,'SamplesPerTrigger',floor(obj.SampleRate*obj.AcquisitionTime));
            obj.SamplesPerTrigger = floor(obj.SampleRate*obj.AcquisitionTime);
            disp(['SampleRate set to ',num2str(obj.SampleRate),' Hz ', 'with AcquisitionTime ', num2str(obj.AcquisitionTime), 's.']);
        end
        
        function setSamplesPerTrigger(obj,SamplesPerTrigger)
            %Sets the SamplesPerTrigger while keeping SampleRate constant
            set(obj.instr,'SamplesPerTrigger',SamplesPerTrigger)
            obj.SamplesPerTrigger=SamplesPerTrigger;
            obj.AcquisitionTime = obj.SamplesPerTrigger/obj.SampleRate;
            disp(['SamplesPerTrigger set to ',num2str(obj.SamplesPerTrigger),' with SampleRate ',num2str(obj.SampleRate),' Hz.']);
        end
        
        function setAcquisitionTime(obj,AcquisitionTime)
            %Uses the current SampleRate and sets SamplesPerTrigger according to desired AcquisitionTime
            set(obj.instr,'SamplesPerTrigger',floor(AcquisitionTime*obj.SampleRate))
            obj.SamplesPerTrigger=floor(AcquisitionTime*obj.SampleRate);
            obj.AcquisitionTime=AcquisitionTime;
            disp(['AcquisitionTime set to ',num2str(obj.AcquisitionTime),'s with SampleRate ',num2str(obj.SampleRate),' Hz.']);
        end
        
        function stream(obj,varargin)
            %the method stream will collect the time and voltage data from
            %the DAQ card using the current SampleRate and AcquisitionTime.
            %You have the option to pass an Acquisition Time as an
            %argument. When stream is finished the obj.datastream, obj.timestream,obj.abstime, and obj.eventsthrown properties will be updated
            switch nargin
                case 2 %if the arguments are obj and another number, set this number to the AcquisitionTime
                    obj.setAcquisitionTime(varargin{1});
                otherwise %otherwise, do nothing and use the current settings
            end
            
            disp('Acquiring data from analog input...');
            start(obj.instr)
            wait(obj.instr,1.2*obj.AcquisitionTime); %waits 1.1 times the expected AcquisitionTime
            [obj.datastream,obj.timestream,obj.abstime,obj.eventsthrown] = getdata(obj.instr);
            disp('Acquisition completed.')
        end
        
        function voltage = getvoltage(obj)
            %getvoltage first calls stream and then analyzes the stream to
            %return one value for the power. REQUIRES A LOT OF
            %OPTIMIZATION to allow for different acquisition times and
            %setting the delay before starting to average. Right now the
            %delay is fixed to 3 seconds.
            obj.stream;
            obj.datastream_smoothed = moving_average(obj.datastream,100); %averages each element with the 100 elements to the left and 100 elements to the right
            voltage = mean(obj.datastream(obj.timestream>0.05)); %Only averages over data starting 3 seconds after beginning of datastream
        end
                    
        
        function delete(obj)
            delete(obj.instr);
            clear obj.instr
        end
        
    end
end


