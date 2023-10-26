 function n_frames = determine_n_frames(listing)
        lst = listing(1,1);
        filename = [lst.folder '/' lst.name]; 
        dir_fn = dir(filename);
        filesize = dir_fn.bytes;
        n_frames = (filesize-64)/11520;
end