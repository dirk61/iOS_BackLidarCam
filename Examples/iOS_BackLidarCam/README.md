# iOS_BackLidarCam

An example using ARVideoKit for simultaneous Lidar Depth Map Capture & Video Recording.



##### Files will be saved at the local directory, including:

* a **MP4** format back camera video (30fps, 1940 * 1440)
* A **zip** file containing the stored depth maps (30fps 256 * 192). Use *ReadDepth.ipynb* in the notebook
* a **txt** file recording the timestamp of each depth frame for future synchronization



<img src="/Users/gix/Downloads/IMG_3964.PNG" alt="IMG_3964" style="zoom:30%;" />



##### Process the zip file of Depth maps

Follow the instructions in the Jupiter notebook. You can retrieve all the frames in arrays and do whatever you want, e.g. generate a depth video.

<img src="/var/folders/8y/3qt1k3y17c539bqt36gmp_9c0000gn/T/ro.nextwave.Snappy/ro.nextwave.Snappy/F2496135-46F6-4486-8140-8FD0C74B2FC2.png" alt="F2496135-46F6-4486-8140-8FD0C74B2FC2" style="zoom:50%;" />
