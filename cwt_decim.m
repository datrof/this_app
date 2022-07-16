
for i=1:174
    cwt_global_dec(i,:)=decimate(cwt_global(i,:),10);
end