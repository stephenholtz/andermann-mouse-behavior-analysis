function result = stackTurboReg(source,target)

Transformation = '-translation'; % translation is currently the only suppported transformation, speak to AK if you need others.
[h,w,l]=size(source);
Cropping = num2str([0 0 w-1 h-1]);
center=num2str(fix(size(source,1)/2)-1);
landmarks = [center,' ',center,' ',center,' ',center];
cmdstr=['-align -window s ',Cropping,' -window t ', Cropping,' ', Transformation, ' ', landmarks,' -hideOutput'];

%% %TurboReg_AK.java IJSubstack_AK.java IJAlign_shifts.java Hypervolume_ShufflerAK.java IJSubstack_AK.java IJAlign_AK.java
sourceImPlus = ijarray2plus(source,'single'); 
targetImPlus = ijarray2plus(target,'single');

al=IJAlign_AK;

disp(cmdstr);
resultImPlus = al.doAlign(cmdstr, sourceImPlus, targetImPlus);
% resultImStack = resultImPlus.getImageStack;
% proc = resultImStack.getProcessor(1);

dummy = ij.process.ImageConverter(resultImPlus);
dummy.setDoScaling(0); % this static property is used by StackConverter

converter = ij.process.StackConverter(resultImPlus); % don't use ImageConverter for stacks!
converter.convertToGray16;

result = ijplus2array(resultImPlus);

return;

