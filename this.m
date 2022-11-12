% Universal .dat to .mat converter
% Version history
% v1 initial
function exit_code = this(path, level)

    level = str2num(level);
    
    display('JEM-EUSO .dat to .mat preprocessor'); 

    this_ver = "3";
    this_sub_ver = "2";

    
    % Задание параметров программы
    %clear; 
    %level=3; %  Data type {raw=1, 1st integrated=2, 2nd integrated=3}
    frame_step=1; % 1 - show all frames, 2 - show ever 2nd frame, etc
    do_flat=0;  % do flat fielding. Applicable Only for MLT.
    mode_2d = 1; % show pictures
      mode_mlt = 1; % show only one EC unit used in MLT
        bad_pixel_removal = 1; %  replace a bad pixel in MLT by neighbour one
      do_rescale = 1; %  do division D2 by 128, D3 by 128*128
      fix_color_map = 0; % 1 - fixed color map, 0 - autoscale color map
        colorbar_lim = 12; %установить предел цветовой шкалы / set colorbar limit
      do_gif = 0; %generate .gif (one file per 128 frames)
    mode_lightcurve = 1; % show light curves
      mode_fft = 0; % show FFT of light curves
      one_pixel = 0; % 0 - show lightcurves for sum of pixels in frame, 1 - show lightcurve for the specified pix.
        pixel_x = 5; pixel_y = 35; % specify pixel

    only_triggered = 0; % show only triggered data (also periodic)

    n_active_pixels = 256; % needed for lightcurves.
    
    period_us(4) = 1000;
    period_us(3) = 2.5*128*128;
    period_us(2) = 2.5*128;
    period_us(1) = 2.5;

    if(level==4)
        frame_size=256; % задать число пикселей ФПУ / number of pixels on FS
        num_of_frames=5000; % задать число фреймов в пакете / number of frames per packet        
        dimx_ecasic = 8; %задать размер по х блока данных, выдаваемый платой ECASIC
        dimy_ecasic = 16;%задать размер по y блока данных, выдаваемый платой ECASIC
        n_ecasic=2;% задать количество плат ECASIC
        mode_mlt = 0;
    else
        frame_size=2304; % задать число пикселей ФПУ / number of pixels on FS
        num_of_frames=128; % задать число фреймов в пакете / number of frames per packet
        dimx_ecasic = 8; %задать размер по х блока данных, выдаваемый платой ECASIC
        dimy_ecasic = 48;%задать размер по y блока данных, выдаваемый платой ECASIC
        n_ecasic=6;% задать количество плат ECASIC
    end

    % d1 Mini-EUSO
    magic_word(1,:) = [hex2dec('01') hex2dec('0A') hex2dec('01') hex2dec('5A') hex2dec('18') hex2dec('80') hex2dec('04') hex2dec('00')];
    % d2 Mini-EUSO
    magic_word(2,:) = [hex2dec('01') hex2dec('0B') hex2dec('01') hex2dec('5A') hex2dec('18') hex2dec('00') hex2dec('09') hex2dec('00')];
    % d3 Mini-EUSO 
    magic_word(3,:) = [hex2dec('01') hex2dec('0C') hex2dec('01') hex2dec('5A') hex2dec('1C') hex2dec('00') hex2dec('12') hex2dec('00')];
    % d3 Tuloma 22-23
    magic_word(4,:) = [hex2dec('03') hex2dec('0C') hex2dec('1E') hex2dec('5A') hex2dec('1A') hex2dec('20') hex2dec('4E') hex2dec('00')];

    
    cw90 = 3; % поворот МАФЭУ на 90 градусов по часовой стрелки 
    ccw90 = 1;% поворот МАФЭУ на 90 градусов против часовой стрелки
    cw180 = 2;% поворот МАФЭУ на 180 градусов
    rotation_needed = 1;
    % Некоторые МАФЭУ (8х)по техническим причинам повернуты. 
    current_frame_global = 0;
    pdm_2d_rot_global_cnt = 0;
    norm_file_cnt = 1;
    gif_cnt = 0;
    
    listing = dir([path '/frm_*.dat']);

    if(numel(listing) == 0) 
        display('No .dat files found in the specified folder');
        exit_code = -1;
        return;
    end    
          
    if(level==3 || level==4) 
        pdm_2d_rot_global = uint32(zeros(16,16,numel(listing)*num_of_frames));
        diag_global = uint32(zeros(16,numel(listing)*num_of_frames));
        lightcurvesum_global = zeros(1,numel(listing)*num_of_frames);
        unixtime_global = uint32(zeros(1, numel(listing)));
        ngtu_global = uint32(zeros(1, numel(listing)));
        sizeof_point = 4;
    elseif(level==2)
        pdm_2d_rot_global = uint16(zeros(16,16,numel(listing)*num_of_frames*3));
        diag_global = uint16(zeros(16,numel(listing)*num_of_frames*3));
        lightcurvesum_global = zeros(1,numel(listing)*num_of_frames*3);
        unixtime_global = uint32(zeros(1, numel(listing)*3));
        ngtu_global = uint32(zeros(1, numel(listing)*3));
        sizeof_point = 2;
    else
        pdm_2d_rot_global = uint8(zeros(16,16,numel(listing)*num_of_frames*3));
        diag_global = uint8(zeros(16,numel(listing)*num_of_frames*3));
        lightcurvesum_global = zeros(1,numel(listing)*num_of_frames*3);
        unixtime_global = uint32(zeros(1, numel(listing)*3));
        ngtu_global = uint32(zeros(1, numel(listing)*3));
        sizeof_point = 1;
    end

    for filename_cntr = 1:numel(listing) % указание на номера файлов, из которых будет произведено чтение
        %цикл, выполняющийся для каждого файла. 

        lst = listing(filename_cntr,1);
        filename = [path '/' lst.name]; 
        short_filename = [lst.name];
        dir_fn = dir(filename);
        filesize = dir_fn.bytes;
        if(level==1 || level==2 || level==3)
            if(filesize ~= 4718884)
                continue;
            end
        end

        fid = fopen(filename);

        fprintf('%s\n',filename);

        cpu_file = uint8(fread(fid, inf)); %прочитать файл в память / read file to memory
        fclose(fid); %закрыть файл / close file
        size_frame_file = size(cpu_file); % опрелелить размер прочитанных данных / get data size

        addrs = strfind(cpu_file',magic_word(level,:));        
        sections(1:numel(addrs)) = addrs;
        
        strange_offset = 2;
        D_bytes=uint8(zeros(3, numel(sections), sizeof_point*frame_size*num_of_frames));
        D_tt = zeros(1, numel(sections(:)));
        D_ngtu = zeros(1, numel(sections));
        if(level==1) 
            numel_section = numel(sections) - 1;
        else
            numel_section = numel(sections);
        end
        for i=1:numel_section
            if (sections(i) ~= 0) || (only_triggered == 1)
                if(level == 1 || level == 2 || level == 3)
                    if(sections(i)+30+sizeof_point+strange_offset+sizeof_point*frame_size*num_of_frames-1) <= size(cpu_file, 1)
                        tmp=uint8(cpu_file(sections(i)+30+sizeof_point+strange_offset : sections(i)+30+sizeof_point+strange_offset+sizeof_point*frame_size*num_of_frames-1)); 
                        D_bytes(i,1:size(tmp)) = tmp(:);                                       
                        D_ngtu(i) = typecast(uint8(cpu_file(sections(i)+8:sections(i)+11)), 'uint32');
                        D_unixtime(i) = typecast(uint8(cpu_file(sections(i)+12:sections(i)+15)), 'uint32');
                        D_tt(i) = uint8(cpu_file(sections(i)+16));
                        %D_cath(j,i,:) = uint8(cpu_file(sections_D(j,i)+20:sections_D(j,i)+31));
                        %if D_tt(j,i)>2
                        %    D_tt(j,i) = 0;
                        %end
                    end
                elseif(level == 4)
                        tmp=uint8(cpu_file(sections(i)+28: sections(i)+28+sizeof_point*frame_size*num_of_frames-1)); 
                        D_bytes(i,1:size(tmp)) = tmp(:);                                       
                        D_ngtu(i) = typecast(uint8(cpu_file(sections(i)+8:sections(i)+11)), 'uint32');
                        D_unixtime(i) = typecast(uint8(cpu_file(sections(i)+12:sections(i)+15)), 'uint32');
                        D_tt(i) = uint8(cpu_file(sections(i)+16));
                        %D_cath(j,i,:) = uint8(cpu_file(sections_D(j,i)+20:sections_D(j,i)+31));
                        %if D_tt(j,i)>2
                        %    D_tt(j,i) = 0;
                        %end
                end
            end
        end 

        if(level==3 || level==4)
            unixtime_global(norm_file_cnt) = uint32(D_unixtime(1));
            ngtu_global(norm_file_cnt) = uint32(D_ngtu(1));
            norm_file_cnt = norm_file_cnt+1;
        elseif (level == 1)
            unixtime_global(norm_file_cnt) = uint32(D_unixtime(1));
            unixtime_global(norm_file_cnt+1) = uint32(D_unixtime(2));
            unixtime_global(norm_file_cnt+2) = uint32(D_unixtime(3));
            ngtu_global(norm_file_cnt) = uint32(D_ngtu(1));
            ngtu_global(norm_file_cnt+1) = uint32(D_ngtu(2));
            ngtu_global(norm_file_cnt+2) = uint32(D_ngtu(3));
            norm_file_cnt = norm_file_cnt+3;            
        elseif (level==2)
            unixtime_global(norm_file_cnt) = uint32(D_unixtime(1));
            unixtime_global(norm_file_cnt+1) = uint32(D_unixtime(2));
            unixtime_global(norm_file_cnt+2) = uint32(D_unixtime(3));
            unixtime_global(norm_file_cnt+3) = uint32(D_unixtime(4));
            ngtu_global(norm_file_cnt) = uint32(D_ngtu(1));
            ngtu_global(norm_file_cnt+1) = uint32(D_ngtu(2));
            ngtu_global(norm_file_cnt+2) = uint32(D_ngtu(3));
            ngtu_global(norm_file_cnt+3) = uint32(D_ngtu(4));
            norm_file_cnt = norm_file_cnt+4;
        end
        
        

        datasize = sizeof_point*frame_size*num_of_frames;
        %accumulation = 128^(level-1);
        %lightcurve_sum=zeros(128);
        %num_el=numel(sections); 
        for packet=1:1:numel_section
            if (D_tt(packet) == 0) && (only_triggered == 1)
                continue;
            end
            %fprintf('T:%d\n', packet);

            frame_data = reshape(D_bytes(packet,1:datasize), [1 datasize]); % выбрать из всех данных, полученных из файла, блок, содержащий изображение / take subarray with only image data
            if (level == 3 || level == 4)% случай триггера уровня 3
                frame_data_cast = typecast(frame_data(:), 'uint32'); %преобразовать представление данных к  uint32 // convert to uint32
            elseif level == 2% случай триггера уровня 2
                frame_data_cast = typecast(frame_data(:), 'uint16');%преобразовать представление данных к  uint16 // convert to uint16
            elseif level == 1% случай триггера уровня 1
                frame_data_cast = frame_data;% оставить представление данных без изменения  // leave unchanged
            end
            frames = reshape(frame_data_cast, [frame_size num_of_frames]); % перегруппировать массив из одномерного в двумерный

            % Формирование изображения на экране
            %for current_frame=1:1:num_of_frames % для каждого фрейма, прочитанного из файла / for each file in directory
            for current_frame=1:frame_step:num_of_frames % для каждого фрейма, прочитанного из файла / for each file in directory
                %disp(current_frame); % вывести значение переменной на экран / print to log screen
                if(do_rescale == 1)
                    pic = (frames(:, current_frame)');% выбрать один фрейм из блока данных, который содержит все фреймы / select just one frame
                else
                    pic = (frames(:, current_frame)');
                end
                %                                 
                ecasics_2d = fliplr(reshape(pic', [dimx_ecasic dimy_ecasic n_ecasic])); % сформировать двумерный массив 8х48, содержащий изображение одного фрейма / form an array 8x48 with just one frame

                % сформировать двумерный массив 48х48, содержащий изображение одного фрейма 
                if(n_ecasic == 6)
                    pdm_2d = [ecasics_2d(:,:,1)' ecasics_2d(:,:,2)' ecasics_2d(:,:,3)' ecasics_2d(:,:,4)' ecasics_2d(:,:,5)' ecasics_2d(:,:,6)']; % form an array 48x48 with just one frame
                else
                    pdm_2d = [ecasics_2d(:,:,1)' ecasics_2d(:,:,2)'];
                end
                    
                % выполнить поворот элементов изображения в зависимости от
                % расположения
                % here we rotate PMTs depending on their positions 

                pdm_2d_rot = pdm_2d; % подготовить выходной массив для повернутых данных. Проинициализировать массив начальными данными до поворота
                if(rotation_needed)
                    for i=0:n_ecasic-1 %для каждой строки элементов изображения 8х8 (МАФЭУ)
                        for j=0:dimy_ecasic/8-1 %для каждого столбца элементов изображения 8х8 (МАФЭУ)
                            if((rem(i,2)==0) && (rem(j,2)==0))%условия поворота
                               pdm_2d_rot(i*8+1:i*8+8, j*8+1:j*8+8) = fliplr(rot90(pdm_2d(i*8+1:i*8+8, j*8+1:j*8+8), cw180));%поворот по часовой стрелке %rot90 cw90
                            end
                            if((rem(i,2)==0) && (rem(j,2)==1))%условия поворота
                               pdm_2d_rot(i*8+1:i*8+8, j*8+1:j*8+8) = fliplr(rot90(pdm_2d(i*8+1:i*8+8, j*8+1:j*8+8), cw90));%поворот по часовой стрелке
                            end
                            if((rem(i,2)==1) && (rem(j,2)==0))%условия поворота
                               pdm_2d_rot(i*8+1:i*8+8, j*8+1:j*8+8) = fliplr(rot90(pdm_2d(i*8+1:i*8+8, j*8+1:j*8+8), ccw90));%поворот по часовой стрелке
                            end
                            if((rem(i,2)==1) && (rem(j,2)==1))%условия поворота
                               pdm_2d_rot(i*8+1:i*8+8, j*8+1:j*8+8) = fliplr(rot90(pdm_2d(i*8+1:i*8+8, j*8+1:j*8+8), 0));%зеркально отобразить fliplr
                            end
                       end
                    end            
                end

                if(mode_mlt == 1)
                    tmp_var=pdm_2d_rot; clear pdm_2d_rot; pdm_2d_rot = tmp_var(33:48,1:16);
                    if(bad_pixel_removal==1)
                       pdm_2d_rot(11,2)=pdm_2d_rot(11,3);    
                    end
                end
                pdm_2d_rot_global_cnt = pdm_2d_rot_global_cnt + 1;
                pdm_2d_rot_global(:,:,pdm_2d_rot_global_cnt) = pdm_2d_rot;
                                      

                current_frame_global = current_frame_global + 1;
                if one_pixel == 0
                    lightcurvesum(current_frame)=sum(pic)/n_active_pixels;
                    lightcurvesum_global(current_frame_global) = sum(pic)/n_active_pixels;
                else
                    lightcurvesum(current_frame)=(pdm_2d_rot(pixel_y,pixel_x));
                    lightcurvesum_global(current_frame_global) = (pdm_2d_rot(pixel_y,pixel_x));                       
                end
            end 
            %D_cath(level,i)'
        end
        %plot(D_ngtu(3,:),'.-');
    end
    
    diag_global(:,pdm_2d_rot_global_cnt) = diag(pdm_2d_rot); 
    
    unixtime_global_numel=numel(unixtime_global);
    lightcurvesum_global_numel=numel(lightcurvesum_global);  
    
    disp 'Generate double unix time'
    
    dngtu=diff(double(ngtu_global));
    ngtu_u64_global = uint64(zeros(1, numel(ngtu_global)));
    unixtime_dbl_global = zeros(1, numel(lightcurvesum_global)); 
    ovflw_cnt = 0;
    ngtu_u64_global(1) = double(ngtu_global(1));
    ngtu_u64_global(2) = double(ngtu_global(2));
    for i=1:numel(ngtu_global)-2
        if(dngtu(i+1) - dngtu(i) < -1e9) 
            ovflw_cnt = ovflw_cnt + 1;
        end
        ngtu_u64_global(i+2) = uint64(ngtu_global(i+2)) + ovflw_cnt*2^32;
    end
       
    k=0;
    for i=1:numel(ngtu_global)
        for j=1:num_of_frames
            if(level == 2) 
                unixtime_dbl_global((i-1)*num_of_frames+j)=double(unixtime_global(1)) + double(ngtu_u64_global(i) + j*128)*(2.5e-6);
            end
            if(level == 3) 
                unixtime_dbl_global((i-1)*num_of_frames+j)=double(unixtime_global(1)) + double(ngtu_u64_global(i) + j*128*128)*(2.5e-6);
            end
            if(level == 4) 
                unixtime_dbl_global((i-1)*num_of_frames+j)=double(unixtime_global(1)) + double(ngtu_u64_global(i) + k*400)*(2.5e-6);
                %unixtime_dbl_global((i-1)*num_of_frames+j)=double(unixtime_global(1) + 5400) + double(k*400)*(2.5e-6);
                k=k+1;
            end
            
        end
    end
    
    if(level ~= 4)
        
        disp 'Removing frames with wrong timestamps'

        valid_time=unixtime_dbl_global(lightcurvesum_global_numel);
        last_valid = 1;
        valid_pos=lightcurvesum_global_numel;


        for i=lightcurvesum_global_numel-1:-1:1
            if unixtime_dbl_global(i)>valid_time
                wrong_pos = i;
                last_valid = 0;
                fprintf('%s','-');
            else
                if last_valid == 0
                    unixtime_dbl_global(wrong_pos:valid_pos-1)=[];
                    lightcurvesum_global(wrong_pos:valid_pos-1)=[];
                    diag_global(:,wrong_pos:valid_pos-1)=[];
                    pdm_2d_rot_global(:,:,wrong_pos:valid_pos-1)=[];
                    fprintf('%s\n','x');
                end 
                valid_time = unixtime_dbl_global(i);
                valid_pos = i;
                last_valid = 1;
            end
        end
    end
    
   disp 'Saving martixes to .mat file'


   if(level==4)
        save([path '/tuloma2223.mat'], 'this_ver', 'this_sub_ver', 'lightcurvesum_global', 'pdm_2d_rot_global', 'diag_global', 'unixtime_dbl_global', 'period_us', '-v7.3');
   elseif(level==3)
        cwt_global = abs(cwt(lightcurvesum_global));
        lightcurvesum_global(128*unixtime_global_numel+1 : lightcurvesum_global_numel) = [];
        diag_global(:,128*unixtime_global_numel+1 : lightcurvesum_global_numel-1) = [];
        %save([path '/global_d3.mat'], 'this_ver', 'this_sub_ver', 'lightcurvesum_global', 'pdm_2d_rot_global', 'diag_global', 'unixtime_global', 'unixtime_dbl_global', 'ngtu_global' , 'd3_period_us', 'cwt_global', '-v7.3');
        save([path '/global_d3.mat'], 'this_ver', 'this_sub_ver', 'lightcurvesum_global', 'pdm_2d_rot_global', 'diag_global', 'unixtime_dbl_global', 'period_us', '-v7.3');
    elseif(level==2) 
        lightcurvesum_global(128*unixtime_global_numel+1 : lightcurvesum_global_numel) = [];
        diag_global(:,128*unixtime_global_numel+1 : lightcurvesum_global_numel-1) = [];
        save([path '/global_d2.mat'], 'this_ver', 'this_sub_ver', 'lightcurvesum_global', 'pdm_2d_rot_global', 'diag_global', 'unixtime_dbl_global', 'period_us', '-v7.3');    
    elseif(level==1)
        %save([path '/global_d1.mat'], 'this_ver', 'this_sub_ver', 'lightcurvesum_global', 'pdm_2d_rot_global', 'diag_global', 'unixtime_global', 'd1_period_us', '-v7.3');    
        save([path '/global_d1.mat'], 'this_ver', 'this_sub_ver', 'pdm_2d_rot_global', 'lightcurvesum_global', 'unixtime_global', 'period_us', '-v7.3');    
    end
    %save([path '/cwt_global.mat'], 'this_ver', 'this_sub_ver', );
    exit_code = 0;
    
    disp 'Done'
    
end



