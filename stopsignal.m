function stopsignal (subject_code, opts)

arguments
    subject_code {mustBeNonnegative}
    opts.Practice {mustBeNumericOrLogical} = false
    opts.DrawFeedback {mustBeNumericOrLogical} = false
end

if opts.Practice
    task_name = 'StopSignalPrac';
else
    task_name = 'StopSignal';
end

Task_Duration=ones(1,2);
Task_Duration(1)=GetSecs;

%%% get ready by deleting all variables and all feedback figures
%%%%%% generate exponential distribution
type=1;
% if type==1, tasktype='sm'; elseif type==2, tasktype='sv'; elseif type==3, tasktype='sw'; end
% JitterType=input('Please enter jitter type(1:fixted; 2:jittered): ');
JitterType=1;

%Seed random number generator
%rand('state',sum(100*clock));
ClockRandSeed(6);

%% open lpt
% io0bj = io64;
% status = io64(io0bj);
% address = hex2dec('3FF8'); % standard LPTl output port address, PKU: CFF8, CAS: D020, blackrock: 3FE8, qiyuan MEG: 3F88
% io64(io0bj, address, 0);
% 1 session_start_trigger=2;
% 2 session_end_trigger=4;
% 3 left_trigger=8;
% 4 right_trigger=16;
% 5 redstop_trigger=32;
% 6 block_trigger=64;
% 7 response_trigger=128;
% total 4 block;
trialnum = [2,4,8,16,32,64,128];
trigger_lasting = 0.02;
timestamp = nan(4,155);
try
    PsychDefaultSetup(2);
    DisableKeysForKbCheck(KbName('f22')); % some keyboards will stuck f22, disable it
    % !! comment this out if high precision is required
    Screen('Preference', 'SkipSyncTests', 1);
    scrn=max(Screen('screens')); % find last screen
    HideCursor;
    w=Screen('OpenWindow',scrn,0);  % open a dark screen
    Screen('TextFont',w, 'SimHei');
    Screen('TextSize',w, 50);
    rect=Screen (w,'rect');
    Priority(MaxPriority(w));   % raise priority for better timing
    [xcenter, ycenter] = RectCenter(rect);
    %get positions ready
    CircleSize=50;
    circle_rect = [0, 0, CircleSize, CircleSize];
    circle = CenterRectOnPoint(circle_rect, xcenter, ycenter);
    circle_stroke = 2;

    %%%%************** DEFINE PARAMS HERE *************
    WAITTIME=1;
    Step=50;
    arrow_duration=1;
    NBLOCKS=4;

    meanrt=zeros(1,NBLOCKS);
    stoprate=zeros(1,NBLOCKS);
    dimerrors=zeros(1,NBLOCKS);
    LEFT=KbName('f'); % key 1
    RIGHT=KbName('j'); % key 2

    %%%%%%%%%%%%%% Stimuli and Response on same matrix, pre-determined
    % The first column is  trial number;
    % The second column is block
    % The third column is 0 = Go, 1 = NoGo; 2 is null, 3 is notrial (kluge, see opt_stop.m)
    % The fourth column is 0=left, 1=right arrow; 2 is null
    % The fifth column is ladder number (1-4);
    % The sixth column is the value currently in "LadderX", corresponding to this...
    % The seventh column is subject response (left is 1, right is 2, no response is 0, multiple press is -1);
    % The eighth column is their reaction time
    % The ninth column is time since beginning of trial
    % The tenth column is ladder movement (-1 for down, +1 for up, 0 for N/A)

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%% TRIAL PRESENTATION %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    if opts.Practice
        instr_pic = 'MateStop/instPrac.JPG';
    else
        instr_pic = 'MateStop/inst.JPG';
    end
    sq=imread(instr_pic,'jpg');  %%% instruction
    tex=Screen('MakeTexture',w,sq);
    Screen('DrawTexture',w,tex);
    Screen('Flip',w);
    WaitTill({'f' 'j'});
    % for istart = 1:5
    % io64(io0bj,address,trialnum(1));
    % timestamp(1,istart)= GetSecs;
    % WaitSecs(trigger_lasting);% the duration of the pulse, 20ms
    % io64(io0bj,address,0);
    % WaitSecs(0.2);
    % end

    totalcnt=1;  % this is the overall counter

    for block=1:NBLOCKS % change number of blocks

        % io64(io0bj,address,trialnum(6));
        % timestamp(block,6)= GetSecs;
        % WaitSecs(trigger_lasting);% the duration of the pulse, 20ms
        % io64(io0bj,address,0);
        % WaitSecs(0.2);
        Screen('TextFont',w, 'SimHei');
        Screen('TextSize',w, 50);

        %%%%%%%%%%%%%%%%%%%%%%%%% MAKES TRIAL SEQUENCE **********
        %%% this code correctly creates 64 (actually 128 with null) trials such that in every 16 trials there is one of each staircase
        %%%   type and the number of left and rightward button presses is equal every four trials.
        NUMCHUNKS=1;

        for  tc=1:NUMCHUNKS
            for qblock=1:4
                LadderOrder=randperm(4);
                arrows = [1 1 0 0];
                [~,  rand_idx]=sort(rand(1,4));
                arrows=arrows(rand_idx);
                for st=1:4
                    %there are 4 in each, one stop, three go
                    mini = [1 arrows(1) LadderOrder(st); 0 arrows(2) 0; 0 arrows(3) 0; 0 arrows(4) 0;];
                    [~,  rand_idx]=sort(rand(1,4));
                    mini=mini(rand_idx,:);
                    start=(tc-1)*64+(qblock-1)*16+(st-1)*4+1;
                    endof=(tc-1)*64+(qblock-1)*16+(st)*4;
                    trialcode(start:endof,:)=mini;
                end
            end
        end

        %%%%%%%%%%%%%%%%%%% GETS STAIRCASE STUFF SET UP %%%%%%%%%%%%%%
        if block==1  %only sets this stuff up once

            if JitterType==1
                Ladder1=140;
                Ladder2=180;
                Ladder3=220;
                Ladder4=260;
            end

            Ladder(1,1)=Ladder1;
            Ladder(2,1)=Ladder2;
            Ladder(3,1)=Ladder3;
            Ladder(4,1)=Ladder4;

        else
            Ladder(1,1)=Ladder1((block-1)*4+1);
            Ladder(2,1)=Ladder2((block-1)*4+1);
            Ladder(3,1)=Ladder3((block-1)*4+1);
            Ladder(4,1)=Ladder4((block-1)*4+1);
        end


        %%%%%%%%%%%%%%%%%%% PREPARES 'SEEKER' VARIABLE IN WHICH DATA ARE SAVED %%%%%%%%%%%%%%

        %%% Seeker will be number of blocks*64
        %%% this code take trialcode, which is 64 rows long and newly generated for each block, and appends it
        %%% the ladder variable is filled in with the current relevant value even though this will change later

        for  trlcnt=1:64                                                                     %go/nogo        arrow              staircase        staircase value
            if trialcode(trlcnt,3)>0, Seeker((block-1)*64+trlcnt,:) = [trlcnt block  trialcode(trlcnt,1) trialcode(trlcnt,2) trialcode(trlcnt,3) Ladder(trialcode(trlcnt,3)) 0 0 0 0];
            else Seeker((block-1)*64+trlcnt,:) =                      [trlcnt block  trialcode(trlcnt,1) trialcode(trlcnt,2) trialcode(trlcnt,3) 0 0 0 0 0];
            end
        end

        %%%% load prescan_wordlist 1 or 2, 3 4, 5, 6, 10;
        % if scannum==1, load wordlist1.mat, else load wordlist2.mat; end

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        anchor=GetSecs;

        for a=1:4 %4 miniblocks
            for b=1:16 % within each miniblock

                Screen('FrameOval', w, 255, circle, circle_stroke);
                Screen('Flip',w);
                WaitTill(GetSecs+ 0.5);
                if (Seeker(totalcnt,4)==0)
                    Screen('FrameOval', w, 255, circle, circle_stroke);
                    DrawFormattedText(w, '<', 'center', 'center', [255 255 255]);
                    % io64(io0bj,address,trialnum(3));
                    % timestamp(block,(a-1)*16+b)= GetSecs;
                    % WaitSecs(trigger_lasting);% the duration of the pulse, 20ms
                    % io64(io0bj,address,0);
                    % WaitSecs(0.2);
                else
                    Screen('FrameOval', w, 255, circle, circle_stroke);
                    DrawFormattedText(w, '>', 'center', 'center', [255 255 255]); %, [], 0, 0, 2
                    % io64(io0bj,address,trialnum(4));
                    % timestamp(block,(a-1)*16+b)= GetSecs;
                    % WaitSecs(trigger_lasting);% the duration of the pulse, 20ms
                    % io64(io0bj,address,0);
                    % WaitSecs(0.2);
                end
                start_time=Screen('Flip',w);

                noresp=1;
                notone=1;
                FlushEvents('keyDown');

                %%% the while loop only exits when arrow duration time is up OR a button is pressed
                WaitSecs(0.1);
                istop = 0;
                while(GetSecs-start_time < arrow_duration && noresp) || (Seeker(totalcnt,3)==1 && notone)
                    istop = istop+1;
                    % new stopsignal
                    if Seeker(totalcnt,3)==1 && GetSecs - start_time >=Seeker(totalcnt,6)/1000 && notone
                        Screen('FrameOval', w, [255 0 0], circle, circle_stroke);
                        if (Seeker(totalcnt,4)==0)
                            DrawFormattedText(w, '<', 'center', 'center', [255 255 255]);
                        else
                            DrawFormattedText(w, '>', 'center', 'center', [255 255 255]); %, [], 0, 0, 2
                        end
                        % io64(io0bj,address,trialnum(5));
                        % timestamp(block,istop+70)= GetSecs;
                        % WaitSecs(trigger_lasting);% the duration of the pulse, 20ms
                        % io64(io0bj,address,0);
                        % WaitSecs(0.2);
                        start_time=Screen('Flip',w);
                        notone=0;
                    end
                    [keyIsDown,~,keyCode] = KbCheck;

                    if keyIsDown
                        press_valid = ismember([LEFT, RIGHT], find(keyCode));
                        if any(press_valid)
                            if sum(press_valid) > 1
                                Seeker(totalcnt,7) = -1;
                            else
                                Seeker(totalcnt,7) = find(press_valid);
                            end
                            Seeker(totalcnt,8)=GetSecs-start_time;
                            noresp=0;
                        end
                    end
                end    %end while
                % io64(io0bj,address,trialnum(7));
                % timestamp(block,(a-1)*16+b+86)= GetSecs;
                % WaitSecs(trigger_lasting);% the duration of the pulse, 20ms
                % io64(io0bj,address,0);
                % WaitSecs(0.2);
                Screen('Flip',w); %
                if opts.Practice
                    %%% punish subject for making an error
                    if Seeker(totalcnt,3)==0 && noresp
                        xword = double('请在1秒内按键');
                        DrawFormattedText(w, xword, 'center', 'center', 255);
                        Screen('Flip',w);
                        pause(0.5);
                        Screen('Flip',w);
                    end

                    if Seeker(totalcnt,3)==0 && ( (Seeker(totalcnt,4)==0 && Seeker(totalcnt,7)==RIGHT) || ( Seeker(totalcnt,4)==1 && Seeker(totalcnt,7)==LEFT ) )
                        xword=double('错了！');
                        Screen('DrawText',w, xword, 'center', 'center',255);
                        Screen('Flip',w);
                        WaitTill(GetSecs+2);
                        Screen('Flip',w);
                    end
                end

                WaitTill(GetSecs+WAITTIME);

                Seeker(totalcnt,9)=GetSecs-anchor; %absolute time since beginning of block
                totalcnt = totalcnt +1; %%% this update the overall counter

            end % end of trial loop;

            % after each 16 trials this code does the updating of staircases
            %These three loops update each of the ladders
            for c=(totalcnt-16):totalcnt-1  %this looks at the last 16 trials
                %This runs from one to four, one for each of the ladders
                for d=1:4
                    if (Seeker(c,7)~=0 && Seeker(c,5)==d)	%col 7 is sub response
                        % reduce Ladder but not less than 0
                        if (Ladder(d,1) > Step)
                            Ladder(d,1)=Ladder(d,1)-Step;
                        end
                        Ladder(d,2)=-1;
                        if (d==1)
                            [x y]=size(Ladder1);
                            Ladder1(x+1,1)=Ladder(d,1);
                        elseif (d==2)
                            [x y]=size(Ladder2);
                            Ladder2(x+1,1)=Ladder(d,1);
                        elseif (d==3)
                            [x y]=size(Ladder3);
                            Ladder3(x+1,1)=Ladder(d,1);
                        elseif (d==4)
                            [x y]=size(Ladder4);
                            Ladder4(x+1,1)=Ladder(d,1);
                        end
                    elseif (Seeker(c,5)==d && Seeker(c,7)==0)
                        % increase Ladder but not larger than arrow duration
                        if Ladder(d,1)+Step < arrow_duration
                            Ladder(d,1)=Ladder(d,1)+Step;
                        end
                        Ladder(d,2)=1;
                        if (d==1)
                            [x y]=size(Ladder1);
                            Ladder1(x+1,1)=Ladder(d,1);
                        elseif (d==2)
                            [x y]=size(Ladder2);
                            Ladder2(x+1,1)=Ladder(d,1);
                        elseif (d==3)
                            [x y]=size(Ladder3);
                            Ladder3(x+1,1)=Ladder(d,1);
                        elseif (d==4)
                            [x y]=size(Ladder4);
                            Ladder4(x+1,1)=Ladder(d,1);
                        end
                    end % end elseif
                end % end for d=1:4
            end % end for c=...

            %Updates the time in each of the subsequent stop trials
            for c=totalcnt:(block-1)*64+64
                if (Seeker(c,5)~=0) %i.e. staircase trial
                    Seeker(c,6)=Ladder(Seeker(c,5),1);
                end
            end
            %Updates each of the old trials with a +1 or a -1 (in col 10)
            for c=(totalcnt-16):totalcnt-1
                if (Seeker(c,5)~=0)
                    Seeker(c,10)=Ladder(Seeker(c,5),2);
                end
            end
        end %end of miniblock

        %%%% FEEDBACK %%%%%
        if opts.DrawFeedback
            %  block      		  go           response
            if type==1
                meanrt(block) = 1000*median(Seeker( Seeker(:,2)==block & Seeker(:,3)==0 & Seeker(:,7)~=0  & ( (Seeker(:,4)==1 & Seeker(:,7)==RIGHT) | ( Seeker(:,4)==0 & Seeker(:,7)==LEFT ) ),8));
                dimerrors(block)=sum((Seeker(:,2)==block & Seeker(:,3)==0 & ( (Seeker(:,4)==0 & Seeker(:,7)==RIGHT) | ( Seeker(:,4)==1 & Seeker(:,7)==LEFT ) )));
                stoprate(block)=length(find(Seeker(:,2)==block & Seeker(:,10)==1))/16;
            else
                meanrt(block) = 1000*median(Seeker( Seeker(:,2)==block & Seeker(:,3)==0 & Seeker(:,8)>0,8));
            end

            %make new feedback figure for each block
            xvals=1:1:NBLOCKS;
            fh=figure;
            subplot(2,1,1);
            plot(xvals,meanrt,'.','markersize',30);
            axis([1 NBLOCKS 100 900]);
            title('按键平均反应时(ms)')
            if type==1
                subplot(2,1,2);
                %    plot(xvals,dimerrors,'.','markersize',30);
                plot(xvals,stoprate,'.','markersize',30);
                axis([1 NBLOCKS 0 1]);
                title('Stop Rate')
            end

            fname = sprintf('Results/feedbackpic%dsub%d.jpg',block,subject_code);
            print(fh,'-djpeg', '-r100', fname);
            close(fh);
            fbimage = imread(fname, 'jpg');
            tex=Screen('MakeTexture',w,fbimage);
            Screen('DrawTexture',w,tex);
        end
        DrawFormattedText(w, double('本轮结束\n按键继续...'), 'center', 'center', [255 0 0]);
        Screen('Flip',w);
        KbReleaseWait;
        WaitTill('');
        Screen('Flip',w);
    end %end block loop

    Task_Duration(2)=GetSecs-Task_Duration(1);
    c=clock;
    outfile=sprintf('Results/%s_Sub%03d_%s_%02.0f_%02.0f.mat',task_name,subject_code,date,c(4),c(5));
    save(outfile, 'Seeker','Task_Duration');

    % ladder for feedback
    str=double('本任务结束,按键退出');
    DrawFormattedText(w, str, 'center', 'center', 255);
    % for iend = 1:5
    % io64(io0bj,address,trialnum(2));
    % timestamp(1,end-iend)= GetSecs;
    % WaitSecs(trigger_lasting);% the duration of the pulse, 20ms
    % io64(io0bj,address,0);
    % WaitSecs(0.2);
    % end
    Screen('Flip',w);
    KbReleaseWait;
    WaitTill({'f' 'j'});
    Screen('Flip',w);

catch
    c=clock;
    outfile=sprintf('Results/Temp_%s_Sub%03d_%s_%02.0f_%02.0f.mat',task_name,subject_code,date,c(4),c(5));
    save(outfile, 'Seeker','Task_Duration');
    Screen('CloseAll'); Priority(0);
    rethrow(lasterror);
end
Screen('CloseAll');
Priority(0);                % restore normal priority
