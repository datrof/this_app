plot(reshape(pdm_2d_rot_global(1, 1, :), [], 1))

fix_color_map = 0;
colorbar_lim = 1;
accumulation = 400;
frame_step = 1;

for frame=1:frame_step:numel(pdm_2d_rot_global(1,1,:))
    if(fix_color_map == 0)
        imagesc(double(pdm_2d_rot_global(:,:,frame))/accumulation); 
    else
        imagesc(double(pdm_2d_rot_global(:,:,frame))/accumulation, [0 colorbar_lim]); 
    end
    colorbar;
    pause(0.01);
    frame
end

stop

plot(unixtime_dbl_global, '.-');

plot(lightcurvesum_global/accumulation, '.-');
