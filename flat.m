%average flatfield file for one day
%DT, 2023.12.18

%path=/home/daniel/lab/PAIP/Lovozero/data/mat_20231215

function make_flat = flat(path)

    listing = dir([path '/all*.mat']);
    %filename_cntr = numel(listing);
    for filename_cntr = 1:numel(listing)
        lst = listing(filename_cntr,1);
        filename = [path '/' lst.name]; 
        disp 'load mat file'
        m = matfile(filename);
        pdm_2d_average = zeros(48, 16);
        pdm_2d_global = m.pdm_2d_rot_global;
        for i=1:48
            i
            for j=1:16
                pdm_2d_average(i, j) = mean(pdm_2d_global(i, j, :));
            end
        end
        all_pixels_average = mean(pdm_2d_average, 'all');
    end
    
    flat_matrix = pdm_2d_average/all_pixels_average;
    
    imagesc(flat_matrix);
    colorbar;
    flat_filename = strcat('ff_', path(strlength(path)-7:strlength(path)), '.txt')
    writematrix(flat_matrix, flat_filename);
    
    
    make_flat = flat_matrix;
    
    disp 'Done'
    
end