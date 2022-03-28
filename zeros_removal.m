function exit_code = zeros_removal(path)
    
    listing = dir([path '/*-d3.mat']);

    if(numel(listing) == 0) 
        display('No .dat files found in the specified folder');
        exit_code = -1;
        return;
    end    

    for filename_cntr = 1:numel(listing) % указание на номера файлов, из которых будет произведено чтение

        
        filename = [path '/' listing(filename_cntr,1).name]; 
        short_filename = [listing(filename_cntr,1).name]; 
        filesize = dir(filename).bytes;

        load(filename);

        display(filename);
        
        
        unixtime_global_numel=numel(unixtime_global);
        
        if(unixtime_global(unixtime_global_numel) ~= 0)
            display('The file is already patched');
            continue;
        end
        display('Removing zeros...');
        unixtime_global(unixtime_global_numel-30:unixtime_global_numel)=[];
        unixtime_global_numel=numel(unixtime_global);
        lightcurvesum_global_numel=numel(lightcurvesum_global);
        
        lightcurvesum_global(128*unixtime_global_numel+1 : lightcurvesum_global_numel) = [];
        cwt_global(:,128*unixtime_global_numel+1 : lightcurvesum_global_numel) = [];
        diag_global(:,128*unixtime_global_numel+1 : lightcurvesum_global_numel) = [];
        pdm_2d_rot_global(:,:,128*unixtime_global_numel+1 : lightcurvesum_global_numel) = [];
        
        display('Save to .mat file...');
        this_sub_ver = "1";
        save(filename, 'this_ver', 'this_sub_ver', 'lightcurvesum_global', 'pdm_2d_rot_global', 'diag_global', 'unixtime_global', 'd3_period_us', 'cwt_global', '-v7.3');
        display('Done\n');
       
    end
    exit_code=0;
end